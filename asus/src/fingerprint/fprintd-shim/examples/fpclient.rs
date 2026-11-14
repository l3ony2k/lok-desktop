//! Test client: behaves like hyprlock (Claim "", VerifyStart "any", listen for
//! VerifyStatus). Usage: fpclient [seconds-to-wait] [stop|hold]
//!   stop: VerifyStop + Release when the wait ends (default)
//!   hold: exit without releasing (simulates a crashed lock screen)
use std::time::Duration;
use async_std::{future::timeout, stream::StreamExt};
use zbus::{proxy, Connection};

#[proxy(interface = "net.reactivated.Fprint.Device", default_service = "net.reactivated.Fprint",
        default_path = "/net/reactivated/Fprint/Device/0")]
trait Device {
    fn claim(&self, username: &str) -> zbus::Result<()>;
    fn release(&self) -> zbus::Result<()>;
    fn verify_start(&self, finger_name: &str) -> zbus::Result<()>;
    fn verify_stop(&self) -> zbus::Result<()>;
    fn list_enrolled_fingers(&self, username: &str) -> zbus::Result<Vec<String>>;
    #[zbus(signal)]
    fn verify_status(&self, result: String, done: bool) -> zbus::Result<()>;
}

#[async_std::main]
async fn main() -> zbus::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let secs: u64 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(15);
    let mode = args.get(2).map(String::as_str).unwrap_or("stop");
    let conn = Connection::system().await?;
    let dev = DeviceProxy::new(&conn).await?;
    println!("enrolled: {:?}", dev.list_enrolled_fingers("").await);
    let mut status = dev.receive_verify_status().await?;
    match dev.claim("").await {
        Ok(()) => println!("claimed"),
        Err(e) => { println!("claim failed: {e}"); return Ok(()); }
    }
    dev.verify_start("any").await?;
    println!("verifying for {secs}s — touch the sensor");
    let deadline = std::time::Instant::now() + Duration::from_secs(secs);
    loop {
        let left = deadline.saturating_duration_since(std::time::Instant::now());
        if left.is_zero() { println!("wait ended"); break; }
        match timeout(left, status.next()).await {
            Ok(Some(sig)) => {
                let a = sig.args()?;
                println!("VerifyStatus {} done={}", a.result, a.done);
                if a.done { break; }
            }
            _ => { println!("wait ended"); break; }
        }
    }
    if mode == "hold" { println!("exiting without release"); std::process::exit(0); }
    let t = std::time::Instant::now();
    println!("VerifyStop: {:?} ({:?})", dev.verify_stop().await, t.elapsed());
    println!("Release: {:?} ({:?})", dev.release().await, t.elapsed());
    Ok(())
}
