#!/usr/bin/env python3
"""Fix: a touch made while nobody is waiting must never authenticate a later
caller.

Found 2026-11-08: after any match wait ends (success, timeout, error) the
FPMCU stays in FP_MODE_MATCH. A later touch (e.g. pressing the power button,
which is the sensor) completes a match whose MKBP event sits queued on the
daemon's /dev/cros_fp descriptor; the next sudo / polkit / lock-screen wait
reads it at once and succeeds without a touch.

Two layers:
1. daemon driver: a match call that is not the immediate re-poll of an ongoing
   wait (gap > STALE_GAP since the previous call started) first disarms the
   sensor and drains queued events. Protects every client.
2. daemon D-Bus + PAM module: new CancelMatch method; pam_rust_fp_safe calls it
   when its wait ends, so the sensor is not left armed.
Idempotent; run from the rust-fp-sandbox/src directory.
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
MARK = "stale-match fix"


def patch(rel, pairs):
    p = root / rel
    s = p.read_text()
    if MARK in s:
        print("already patched", rel)
        return
    for old, new in pairs:
        if s.count(old) != 1:
            raise SystemExit(f"{rel}: expected exactly one match for:\n{old}")
        s = s.replace(old, new)
    p.write_text(s)
    print("patched", rel)


# 1. trait
patch("rust-fp/src/fingerprint_driver.rs", [(
    "    /// Wait at most `timeout` for a finger to match one of `templates`.\n",
    "    /// Stop waiting for a finger and drop any match result already queued, so a\n"
    "    /// touch made while nobody was waiting can never count for a later caller\n"
    "    /// (stale-match fix). Safe to call when the sensor is not matching.\n"
    "    fn cancel_match(&mut self) -> BoxFuture<'_, anyhow::Result<()>>;\n"
    "    /// Wait at most `timeout` for a finger to match one of `templates`.\n",
)])

# 2. cros_fp driver
patch("rust-fp/src/drivers/cros_fp.rs", [
    (
        "    /// Whether an enrolment session is open on the sensor.\n"
        "    enroll_open: bool,\n"
        "}\n",
        "    /// Whether an enrolment session is open on the sensor.\n"
        "    enroll_open: bool,\n"
        "    /// When the previous match call started (stale-match fix).\n"
        "    last_match_call: Option<Instant>,\n"
        "}\n"
        "\n"
        "/// A match call starting later than this after the previous one is a new\n"
        "/// wait, not the re-poll of an ongoing one (re-polls come every\n"
        "/// MATCH_STEP_TIMEOUT = 2 s). Stale-match fix.\n"
        "const STALE_GAP: Duration = Duration::from_millis(2500);\n",
    ),
    (
        "            enroll_open: false,\n"
        "        })\n",
        "            enroll_open: false,\n"
        "            last_match_call: None,\n"
        "        })\n",
    ),
    (
        "    fn cancel_enroll(&mut self) -> BoxFuture<'_, anyhow::Result<()>> {\n"
        "        Box::pin(async move { self.reset_enroll() })\n"
        "    }\n",
        "    fn cancel_enroll(&mut self) -> BoxFuture<'_, anyhow::Result<()>> {\n"
        "        Box::pin(async move { self.reset_enroll() })\n"
        "    }\n"
        "\n"
        "    fn cancel_match(&mut self) -> BoxFuture<'_, anyhow::Result<()>> {\n"
        "        Box::pin(async move {\n"
        "            self.last_match_call = None;\n"
        "            self.disarm_and_drain().await\n"
        "        })\n"
        "    }\n",
    ),
    (
        "            self.check_if_templates_got_cleared();\n"
        "            let deadline = Instant::now() + timeout;\n",
        "            // stale-match fix: a new wait must not see what the sensor\n"
        "            // matched while nobody was waiting.\n"
        "            let fresh = self\n"
        "                .last_match_call\n"
        "                .map_or(true, |t| t.elapsed() > STALE_GAP);\n"
        "            self.last_match_call = Some(Instant::now());\n"
        "            if fresh {\n"
        "                self.disarm_and_drain()\n"
        "                    .await\n"
        "                    .map_err(|e| format!(\"Error clearing stale match: {e:?}\"))?;\n"
        "            }\n"
        "            self.check_if_templates_got_cleared();\n"
        "            let deadline = Instant::now() + timeout;\n",
    ),
    (
        "impl OpenedCrosFp {\n"
        "    async fn open_and_init() -> io::Result<Self> {\n",
        "impl OpenedCrosFp {\n"
        "    /// Take the sensor out of match mode and throw away queued fingerprint\n"
        "    /// events (stale-match fix).\n"
        "    async fn disarm_and_drain(&mut self) -> anyhow::Result<()> {\n"
        "        let mode = fp_mode(&mut self.file, FpMode::DontChange as u32)\n"
        "            .map_err(|e| anyhow::anyhow!(\"Error reading fp mode: {e:?}\"))?;\n"
        "        if mode & FpMode::Match as u32 != 0 {\n"
        "            fp_mode(&mut self.file, FpMode::Reset as u32)\n"
        "                .map_err(|e| anyhow::anyhow!(\"Error doing Reset: {e:?}\"))?;\n"
        "        }\n"
        "        for _ in 0..32 {\n"
        "            let queued = wait_event_timeout(\n"
        "                &mut self.file,\n"
        "                [EcMkbpEventType::Fingerprint, EcMkbpEventType::HostEvent],\n"
        "                Duration::ZERO,\n"
        "            )\n"
        "            .await?;\n"
        "            if queued.is_none() {\n"
        "                break;\n"
        "            }\n"
        "        }\n"
        "        Ok(())\n"
        "    }\n"
        "\n"
        "    async fn open_and_init() -> io::Result<Self> {\n",
    ),
])

# 3. D-Bus interface
patch("common/src/rust_fp_dbus.rs", [(
    "    async fn match_templates(&mut self, templates: Vec<Vec<u8>>) -> fdo::Result<Vec<u8>> {\n",
    "    /// Stop matching and drop any result the sensor has queued (stale-match fix).\n"
    "    async fn cancel_match(&mut self) -> fdo::Result<()> {\n"
    "        if self.enrolling.is_some() {\n"
    "            return Ok(());\n"
    "        }\n"
    "        self.driver\n"
    "            .cancel_match()\n"
    "            .await\n"
    "            .map_err(|e| fdo::Error::Failed(format!(\"{e:?}\")))\n"
    "    }\n"
    "\n"
    "    async fn match_templates(&mut self, templates: Vec<Vec<u8>>) -> fdo::Result<Vec<u8>> {\n",
)])

# 4. PAM module: disarm when the wait ends
patch("pam-safe/src/lib.rs", [(
    "fn match_loop(templates: Vec<(String, Vec<u8>)>, cancel: Arc<AtomicBool>) -> Outcome {\n"
    "    let Ok(connection) = Connection::system() else { return Outcome::Failed };\n"
    "    let Ok(proxy) = RustFpProxyBlocking::new(&connection) else { return Outcome::Failed };\n",
    "fn match_loop(templates: Vec<(String, Vec<u8>)>, cancel: Arc<AtomicBool>) -> Outcome {\n"
    "    let Ok(connection) = Connection::system() else { return Outcome::Failed };\n"
    "    let Ok(proxy) = RustFpProxyBlocking::new(&connection) else { return Outcome::Failed };\n"
    "    let outcome = match_until_done(&proxy, templates, cancel);\n"
    "    // stale-match fix: leave the sensor disarmed so a later touch cannot\n"
    "    // count for a later caller. Best effort; the daemon also drains on the\n"
    "    // next fresh wait.\n"
    "    let _ = proxy.cancel_match();\n"
    "    outcome\n"
    "}\n"
    "\n"
    "fn match_until_done(\n"
    "    proxy: &RustFpProxyBlocking<'_>,\n"
    "    templates: Vec<(String, Vec<u8>)>,\n"
    "    cancel: Arc<AtomicBool>,\n"
    ") -> Outcome {\n",
)])
