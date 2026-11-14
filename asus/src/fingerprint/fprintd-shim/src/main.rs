//! Minimal fprintd-compatible D-Bus service on top of rust-fp.
//!
//! fprintd/libfprint cannot drive the ChromeOS FPMCU on this machine; rust-fp
//! can (org.rust_fp.RustFp on the system bus). hyprlock's native fingerprint
//! support speaks the fprintd API, so this exposes just enough of it:
//!
//!   net.reactivated.Fprint.Manager  GetDevices, GetDefaultDevice
//!   net.reactivated.Fprint.Device   Claim, Release, VerifyStart, VerifyStop,
//!                                   ListEnrolledFingers,
//!                                   signals VerifyStatus, VerifyFingerSelected
//!
//! Verification only ever matches the claiming user's own templates
//! (~/.var/cros-fp-templates of the caller's passwd entry). Enrolment is not
//! offered; use `rust-fp add`.
#![warn(unused_crate_dependencies)]

use std::ffi::{CStr, CString};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_std::task::{self, JoinHandle};
use log::{info, warn};
use postcard::from_bytes;
use rust_fp::fingerprint_driver::{MatchOutput, NoMatchError};
use rust_fp_common::rust_fp_dbus::RustFpProxy;
use rust_fp_common::template::Templates;
use simple_logger::SimpleLogger;
use zbus::message::Header;
use zbus::names::BusName;
use zbus::object_server::SignalContext;
use zbus::zvariant::OwnedObjectPath;
use zbus::{fdo, interface, Connection, DBusError};

const SERVICE: &str = "net.reactivated.Fprint";
const MANAGER_PATH: &str = "/net/reactivated/Fprint/Manager";
const DEVICE_PATH: &str = "/net/reactivated/Fprint/Device/0";

#[derive(Debug, DBusError)]
#[zbus(prefix = "net.reactivated.Fprint.Error")]
enum FpError {
    #[zbus(error)]
    ZBus(zbus::Error),
    PermissionDenied(String),
    AlreadyInUse(String),
    ClaimDevice(String),
    NoEnrolledPrints(String),
    Internal(String),
}

fn device_path() -> OwnedObjectPath {
    OwnedObjectPath::try_from(DEVICE_PATH).unwrap()
}

struct Manager;

#[interface(name = "net.reactivated.Fprint.Manager")]
impl Manager {
    fn get_devices(&self) -> Vec<OwnedObjectPath> {
        vec![device_path()]
    }
    fn get_default_device(&self) -> OwnedObjectPath {
        device_path()
    }
}

// ---- passwd helpers --------------------------------------------------------

fn user_of_uid(uid: u32) -> Option<String> {
    unsafe {
        let pw = libc::getpwuid(uid);
        if pw.is_null() || (*pw).pw_name.is_null() {
            return None;
        }
        Some(CStr::from_ptr((*pw).pw_name).to_string_lossy().into_owned())
    }
}

fn home_of(user: &str) -> Option<String> {
    let cuser = CString::new(user).ok()?;
    unsafe {
        let pw = libc::getpwnam(cuser.as_ptr());
        if pw.is_null() || (*pw).pw_dir.is_null() {
            return None;
        }
        Some(CStr::from_ptr((*pw).pw_dir).to_string_lossy().into_owned())
    }
}

/// Template names sorted, plus the blobs in the same order.
fn load_templates(user: &str) -> Result<Vec<(String, Vec<u8>)>, String> {
    let home = home_of(user).ok_or_else(|| format!("no passwd home for {user}"))?;
    let path = format!("{home}/.var/cros-fp-templates");
    let buf = match std::fs::read(&path) {
        Ok(b) => b,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(vec![]),
        Err(e) => return Err(format!("read {path}: {e}")),
    };
    let templates: Templates =
        rmp_serde::from_slice(&buf).map_err(|e| format!("decode {path}: {e}"))?;
    let mut v: Vec<(String, Vec<u8>)> = templates.into_iter().collect();
    v.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(v)
}

// ---- device ----------------------------------------------------------------

struct ClaimState {
    /// Unique bus name of the claimant; only it may verify/release.
    sender: String,
    user: String,
}

struct Verify {
    cancel: Arc<AtomicBool>,
    handle: JoinHandle<()>,
}

#[derive(Default)]
struct State {
    claim: Option<ClaimState>,
    verify: Option<Verify>,
}

struct Device {
    state: Arc<Mutex<State>>,
}

async fn caller_uid(conn: &Connection, sender: &str) -> Result<u32, FpError> {
    let dbus = fdo::DBusProxy::new(conn).await?;
    let name = BusName::try_from(sender.to_owned()).map_err(|e| FpError::Internal(e.to_string()))?;
    dbus.get_connection_unix_user(name)
        .await
        .map_err(|e| FpError::Internal(format!("GetConnectionUnixUser: {e}")))
}

async fn name_alive(conn: &Connection, name: &str) -> bool {
    let Ok(dbus) = fdo::DBusProxy::new(conn).await else {
        return true;
    };
    let Ok(bus_name) = BusName::try_from(name.to_owned()) else {
        return false;
    };
    dbus.name_has_owner(bus_name).await.unwrap_or(true)
}

fn sender_of(hdr: &Header<'_>) -> Result<String, FpError> {
    hdr.sender()
        .map(|s| s.to_string())
        .ok_or_else(|| FpError::Internal("message without sender".into()))
}

impl Device {
    /// Stop a running verification and wait for its loop to finish (<= ~2 s,
    /// one MatchTemplates step).
    async fn stop_verify(&self) {
        let verify = self.state.lock().unwrap().verify.take();
        if let Some(v) = verify {
            v.cancel.store(true, Ordering::SeqCst);
            v.handle.await;
        }
    }

    fn check_claimant(&self, sender: &str) -> Result<String, FpError> {
        let st = self.state.lock().unwrap();
        match &st.claim {
            Some(c) if c.sender == sender => Ok(c.user.clone()),
            Some(_) => Err(FpError::AlreadyInUse("Device was claimed by another client".into())),
            None => Err(FpError::ClaimDevice("Device was not claimed before use".into())),
        }
    }
}

/// Runs until a decisive result, cancellation, or the claimant leaving the bus.
async fn verify_loop(
    conn: Connection,
    state: Arc<Mutex<State>>,
    sender: String,
    blobs: Vec<Vec<u8>>,
    cancel: Arc<AtomicBool>,
) {
    let ctxt = match SignalContext::new(&conn, DEVICE_PATH) {
        Ok(c) => c.to_owned(),
        Err(e) => {
            warn!("signal context: {e}");
            return;
        }
    };
    let proxy = match RustFpProxy::new(&conn).await {
        Ok(p) => p,
        Err(e) => {
            warn!("rust-fp proxy: {e}");
            let _ = Device::verify_status(&ctxt, "verify-unknown-error", true).await;
            return;
        }
    };
    let _ = Device::verify_finger_selected(&ctxt, "any").await;

    let emit = |result: &'static str, done: bool| {
        let ctxt = ctxt.clone();
        let cancel = cancel.clone();
        async move {
            if cancel.load(Ordering::SeqCst) {
                return; // stopped meanwhile: the client no longer wants results
            }
            info!("VerifyStatus {result} done={done}");
            if let Err(e) = Device::verify_status(&ctxt, result, done).await {
                warn!("emit VerifyStatus: {e}");
            }
        }
    };

    let mut errors = 0u32;
    let decided = loop {
        if cancel.load(Ordering::SeqCst) {
            break false;
        }
        if !name_alive(&conn, &sender).await {
            info!("claimant {sender} left the bus; releasing");
            let mut st = state.lock().unwrap();
            if st.claim.as_ref().is_some_and(|c| c.sender == sender) {
                st.claim = None;
            }
            break false;
        }
        match proxy.match_templates(blobs.clone()).await {
            Err(e) => {
                // e.g. an enrolment holds the sensor: back off and retry.
                errors += 1;
                warn!("MatchTemplates error ({errors}): {e}");
                if errors >= 15 {
                    emit("verify-unknown-error", true).await;
                    break true;
                }
                task::sleep(Duration::from_secs(1)).await;
            }
            Ok(bytes) => {
                errors = 0;
                match from_bytes::<MatchOutput>(&bytes) {
                    Ok(MatchOutput::TimedOut) => {}
                    Ok(MatchOutput::Match(_)) => {
                        emit("verify-match", true).await;
                        break true;
                    }
                    Ok(MatchOutput::NoMatch(Some(NoMatchError::LowQuality))) => {
                        emit("verify-retry-scan", false).await;
                    }
                    Ok(MatchOutput::NoMatch(_)) => {
                        emit("verify-no-match", true).await;
                        break true;
                    }
                    Err(e) => {
                        warn!("decode MatchOutput: {e}");
                        emit("verify-unknown-error", true).await;
                        break true;
                    }
                }
            }
        }
    };
    // Cancelled mid-wait: drop whatever the sensor may have queued so it is
    // not mistaken for a fresh touch later (stale-match fix).
    if !decided {
        if let Err(e) = proxy.cancel_match().await {
            warn!("CancelMatch: {e}");
        }
    }
}

#[interface(name = "net.reactivated.Fprint.Device")]
impl Device {
    async fn claim(
        &self,
        username: &str,
        #[zbus(header)] hdr: Header<'_>,
        #[zbus(connection)] conn: &Connection,
    ) -> Result<(), FpError> {
        let sender = sender_of(&hdr)?;
        let uid = caller_uid(conn, &sender).await?;
        let caller = user_of_uid(uid).ok_or_else(|| FpError::Internal(format!("no user for uid {uid}")))?;
        let user = if username.is_empty() { caller.clone() } else { username.to_owned() };
        if user != caller && uid != 0 {
            return Err(FpError::PermissionDenied(format!("{caller} may not claim for {user}")));
        }
        // A claim whose owner vanished (crashed lock screen) is void.
        let stale = {
            let st = self.state.lock().unwrap();
            st.claim.as_ref().map(|c| c.sender.clone())
        };
        if let Some(old) = stale {
            if old != sender && name_alive(conn, &old).await {
                return Err(FpError::AlreadyInUse("Device already in use by another user".into()));
            }
            self.stop_verify().await;
        }
        self.state.lock().unwrap().claim = Some(ClaimState { sender: sender.clone(), user: user.clone() });
        info!("claimed by {sender} for {user}");
        Ok(())
    }

    async fn release(&self, #[zbus(header)] hdr: Header<'_>) -> Result<(), FpError> {
        let sender = sender_of(&hdr)?;
        self.check_claimant(&sender)?;
        self.stop_verify().await;
        self.state.lock().unwrap().claim = None;
        info!("released by {sender}");
        Ok(())
    }

    async fn verify_start(
        &self,
        finger_name: &str,
        #[zbus(header)] hdr: Header<'_>,
        #[zbus(connection)] conn: &Connection,
    ) -> Result<(), FpError> {
        let sender = sender_of(&hdr)?;
        let user = self.check_claimant(&sender)?;
        // A previous loop may still be finishing its last MatchTemplates step.
        self.stop_verify().await;
        let templates = load_templates(&user).map_err(FpError::Internal)?;
        let templates: Vec<_> = if finger_name.is_empty() || finger_name == "any" {
            templates
        } else {
            templates.into_iter().filter(|(n, _)| n == finger_name).collect()
        };
        if templates.is_empty() {
            return Err(FpError::NoEnrolledPrints(format!("no fingerprints enrolled for {user}")));
        }
        let blobs = templates.into_iter().map(|(_, b)| b).collect();
        let cancel = Arc::new(AtomicBool::new(false));
        let handle = task::spawn(verify_loop(
            conn.clone(),
            self.state.clone(),
            sender.clone(),
            blobs,
            cancel.clone(),
        ));
        self.state.lock().unwrap().verify = Some(Verify { cancel, handle });
        info!("verify started for {user} ({finger_name})");
        Ok(())
    }

    /// Returns immediately; the loop notices within one match step.
    async fn verify_stop(&self, #[zbus(header)] hdr: Header<'_>) -> Result<(), FpError> {
        let sender = sender_of(&hdr)?;
        self.check_claimant(&sender)?;
        if let Some(v) = self.state.lock().unwrap().verify.as_ref() {
            v.cancel.store(true, Ordering::SeqCst);
        }
        info!("verify stop requested by {sender}");
        Ok(())
    }

    async fn list_enrolled_fingers(
        &self,
        username: &str,
        #[zbus(header)] hdr: Header<'_>,
        #[zbus(connection)] conn: &Connection,
    ) -> Result<Vec<String>, FpError> {
        let sender = sender_of(&hdr)?;
        let uid = caller_uid(conn, &sender).await?;
        let caller = user_of_uid(uid).unwrap_or_default();
        let user = if username.is_empty() { caller.clone() } else { username.to_owned() };
        if user != caller && uid != 0 {
            return Err(FpError::PermissionDenied(format!("{caller} may not list {user}")));
        }
        let names: Vec<String> = load_templates(&user)
            .map_err(FpError::Internal)?
            .into_iter()
            .map(|(n, _)| n)
            .collect();
        if names.is_empty() {
            return Err(FpError::NoEnrolledPrints(format!("no fingerprints enrolled for {user}")));
        }
        Ok(names)
    }

    #[zbus(signal)]
    async fn verify_status(ctxt: &SignalContext<'_>, result: &str, done: bool) -> zbus::Result<()>;
    #[zbus(signal)]
    async fn verify_finger_selected(ctxt: &SignalContext<'_>, finger_name: &str) -> zbus::Result<()>;
}

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    SimpleLogger::new().with_level(log::LevelFilter::Info).init().unwrap();
    let _conn = zbus::connection::Builder::system()?
        .name(SERVICE)?
        .serve_at(MANAGER_PATH, Manager)?
        .serve_at(DEVICE_PATH, Device { state: Default::default() })?
        .build()
        .await?;
    info!("{SERVICE} (rust-fp shim) ready");
    std::future::pending::<()>().await;
    Ok(())
}
