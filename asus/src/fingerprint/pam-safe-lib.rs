//! pam_rust_fp_safe: a defensive PAM auth module for rust-fp (ChromeOS FPMCU).
//!
//! Differences from upstream's rust-fp PAM module, so it is safe in `sudo`:
//! - Bounded wait: `timeout=<seconds>` (default 10). On timeout, no match, or
//!   any error it returns PAM_AUTH_ERR, so a `sufficient` line falls through to
//!   the password module. It never blocks forever.
//! - No signal handlers (upstream installed a Ctrl+C handler inside sudo).
//! - Every failure path returns an error code; panics are caught.
//! - Templates are read from the PAM user's home (passwd), not from $HOME.
//! - Matched templates are not written back (sudo runs as root).
//! - Messages go through the PAM conversation with null checks.
//!
//! Arguments: `timeout=N` seconds, `quiet` (no prompt message), `debug`,
//! `retry` (return PAM_AUTHINFO_UNAVAIL instead of PAM_AUTH_ERR on timeout or
//! no match, so Quickshell's lock screen re-arms the fingerprint context).

extern crate pam;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{channel, RecvTimeoutError};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use pam::constants::PamResultCode::{PAM_AUTHINFO_UNAVAIL, PAM_AUTH_ERR, PAM_SUCCESS};
use pam::constants::{PamFlag, PamResultCode};
use pam::module::{PamHandle, PamHooks};
use postcard::from_bytes;
use zbus::blocking::Connection;

use rust_fp::fingerprint_driver::{MatchOutput, MatchedOutput};
use rust_fp_common::rust_fp_dbus::RustFpProxyBlocking;
use rust_fp_common::template::Templates;

const PAM_CONV_ITEM: c_int = 5;
const PAM_TEXT_INFO: c_int = 4;
const PAM_ERROR_MSG: c_int = 3;
const DEFAULT_TIMEOUT_SECS: u64 = 10;
const MAX_ATTEMPTS: u32 = 3;

#[repr(C)]
struct RawPamMessage {
    msg_style: c_int,
    msg: *const c_char,
}

#[repr(C)]
struct RawPamResponse {
    resp: *mut c_char,
    resp_retcode: c_int,
}

#[repr(C)]
struct RawPamConv {
    conv: Option<
        extern "C" fn(
            c_int,
            *const *const RawPamMessage,
            *mut *mut RawPamResponse,
            *mut c_void,
        ) -> c_int,
    >,
    appdata_ptr: *mut c_void,
}

extern "C" {
    fn pam_get_item(pamh: *const PamHandle, item_type: c_int, item: *mut *const c_void) -> c_int;
    fn pam_get_user(pamh: *const PamHandle, user: *mut *const c_char, prompt: *const c_char) -> c_int;
    fn free(ptr: *mut c_void);
}

/// pam-bindings 0.1.1 get_user() is unsound (passes `&ptr` to a C out-param
/// declared immutable), so with optimisations it always reports failure.
fn pam_user(pamh: &PamHandle) -> Result<String, String> {
    let mut ptr: *const c_char = std::ptr::null();
    let rc = unsafe { pam_get_user(pamh as *const PamHandle, &mut ptr, std::ptr::null()) };
    if rc != 0 {
        return Err(format!("pam_get_user rc={rc}"));
    }
    if ptr.is_null() {
        return Err("pam_get_user returned null".into());
    }
    Ok(unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned())
}

/// Send one informational/error line through the application's conversation
/// function. Ignores every failure; never dereferences null pointers.
fn say(pamh: &PamHandle, style: c_int, text: &str) {
    let Ok(ctext) = CString::new(text) else { return };
    unsafe {
        let mut item: *const c_void = std::ptr::null();
        if pam_get_item(pamh as *const PamHandle, PAM_CONV_ITEM, &mut item) != 0 || item.is_null() {
            return;
        }
        let conv = &*(item as *const RawPamConv);
        let Some(f) = conv.conv else { return };
        let msg = RawPamMessage { msg_style: style, msg: ctext.as_ptr() };
        let msg_ptr: *const RawPamMessage = &msg;
        let mut resp: *mut RawPamResponse = std::ptr::null_mut();
        let _ = f(1, &msg_ptr, &mut resp, conv.appdata_ptr);
        if !resp.is_null() {
            if !(*resp).resp.is_null() {
                free((*resp).resp as *mut c_void);
            }
            free(resp as *mut c_void);
        }
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

fn load_templates(user: &str) -> Result<Templates, String> {
    let home = home_of(user).ok_or_else(|| format!("no passwd home for {user}"))?;
    let path = format!("{home}/.var/cros-fp-templates");
    let buf = std::fs::read(&path).map_err(|e| format!("read {path}: {e}"))?;
    rmp_serde::from_slice::<Templates>(&buf).map_err(|e| format!("decode {path}: {e}"))
}

enum Outcome {
    Matched(String),
    NoMatch,
    Failed,
}

/// Runs in a worker thread. Stops when `cancel` is set (checked between the
/// daemon's periodic TimedOut hand-backs, about every 2 s).
fn match_loop(templates: Vec<(String, Vec<u8>)>, cancel: Arc<AtomicBool>) -> Outcome {
    let Ok(connection) = Connection::system() else { return Outcome::Failed };
    let Ok(proxy) = RustFpProxyBlocking::new(&connection) else { return Outcome::Failed };
    let blobs: Vec<Vec<u8>> = templates.iter().map(|(_, v)| v.clone()).collect();
    let mut misses = 0;
    while !cancel.load(Ordering::SeqCst) {
        let Ok(bytes) = proxy.match_templates(blobs.clone()) else { return Outcome::Failed };
        let Ok(output) = from_bytes::<MatchOutput>(&bytes) else { return Outcome::Failed };
        match output {
            MatchOutput::Match(MatchedOutput { index, .. }) => {
                return match templates.get(index) {
                    Some((name, _)) => Outcome::Matched(name.clone()),
                    None => Outcome::Failed,
                };
            }
            MatchOutput::TimedOut => continue,
            MatchOutput::NoMatch(_) => {
                misses += 1;
                if misses >= MAX_ATTEMPTS {
                    return Outcome::NoMatch;
                }
            }
        }
    }
    Outcome::Failed
}

fn authenticate(pamh: &mut PamHandle, args: &[&CStr]) -> PamResultCode {
    let mut timeout = Duration::from_secs(DEFAULT_TIMEOUT_SECS);
    let mut quiet = false;
    let mut debug = false;
    let mut retry = false;
    for a in args {
        let a = a.to_string_lossy();
        if let Some(v) = a.strip_prefix("timeout=") {
            if let Ok(n) = v.parse::<u64>() {
                timeout = Duration::from_secs(n.clamp(1, 3600));
            }
        } else if a == "quiet" {
            quiet = true;
        } else if a == "debug" {
            debug = true;
        } else if a == "retry" {
            retry = true;
        }
    }
    let dbg = |pamh: &PamHandle, m: String| {
        if debug {
            say(pamh, PAM_ERROR_MSG, &format!("[pam_rust_fp_safe] {m}"));
        }
    };

    let user = match pam_user(pamh) {
        Ok(u) => u,
        Err(e) => {
            dbg(pamh, format!("get_user failed: {e:?}"));
            return PAM_AUTH_ERR;
        }
    };
    let templates = match load_templates(&user) {
        Ok(t) => t,
        Err(e) => {
            dbg(pamh, format!("load_templates({user}) failed: {e}"));
            return PAM_AUTH_ERR;
        }
    };
    if templates.is_empty() {
        dbg(pamh, format!("no templates for {user}"));
        return PAM_AUTH_ERR;
    }
    dbg(pamh, format!("{} template(s) for {user}", templates.len()));
    let mut templates: Vec<(String, Vec<u8>)> = templates.into_iter().collect();
    templates.sort_by(|a, b| a.0.cmp(&b.0));

    if !quiet {
        say(
            pamh,
            PAM_TEXT_INFO,
            &format!("Touch the fingerprint sensor ({} s), or wait to use your password", timeout.as_secs()),
        );
    }

    let cancel = Arc::new(AtomicBool::new(false));
    let (tx, rx) = channel();
    {
        let cancel = cancel.clone();
        thread::spawn(move || {
            let r = catch_unwind(AssertUnwindSafe(|| match_loop(templates, cancel)))
                .unwrap_or(Outcome::Failed);
            let _ = tx.send(r);
        });
    }

    let deadline = Instant::now() + timeout;
    let result = match rx.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
        Ok(Outcome::Matched(name)) => {
            if !quiet {
                say(pamh, PAM_TEXT_INFO, &format!("Fingerprint recognized ({name})"));
            }
            PAM_SUCCESS
        }
        Ok(Outcome::NoMatch) => {
            if !quiet {
                say(pamh, PAM_ERROR_MSG, "Fingerprint not recognized, use your password");
            }
            if retry { PAM_AUTHINFO_UNAVAIL } else { PAM_AUTH_ERR }
        }
        Ok(Outcome::Failed) | Err(RecvTimeoutError::Disconnected) => PAM_AUTH_ERR,
        Err(RecvTimeoutError::Timeout) => {
            if !quiet {
                say(pamh, PAM_ERROR_MSG, "Fingerprint timed out, use your password");
            }
            if retry { PAM_AUTHINFO_UNAVAIL } else { PAM_AUTH_ERR }
        }
    };
    cancel.store(true, Ordering::SeqCst);
    result
}

struct RustFpSafe;
pam::pam_hooks!(RustFpSafe);

impl PamHooks for RustFpSafe {
    fn sm_authenticate(pamh: &mut PamHandle, args: Vec<&CStr>, _flags: PamFlag) -> PamResultCode {
        catch_unwind(AssertUnwindSafe(|| authenticate(pamh, &args))).unwrap_or(PAM_AUTH_ERR)
    }

    fn sm_setcred(_pamh: &mut PamHandle, _args: Vec<&CStr>, _flags: PamFlag) -> PamResultCode {
        PAM_SUCCESS
    }
}
