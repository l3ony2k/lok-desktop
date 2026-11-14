#!/usr/bin/env python3
"""Lock screen kept no fingerprint after a resume (2026-11-08).

Quickshell's lock re-arms its fingerprint PAM only on PamResult.Error
(PAM_AUTHINFO_UNAVAIL). pam_rust_fp_safe returned PAM_AUTH_ERR on any error
(D-Bus call failing, bad reply), which Quickshell treats as a final failure:
the fingerprint stayed off until the next lock.

- `retry` mode: an error now also returns PAM_AUTHINFO_UNAVAIL, after a 2 s
  pause so a dead daemon cannot make the lock screen spin.
- Every failure is logged to syslog (authpriv) as "pam_rust_fp_safe: ...".
sudo / polkit (no `retry`) unchanged. Idempotent; run in rust-fp-sandbox/src.
"""
import pathlib
import sys

p = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".") / "pam-safe/src/lib.rs"
s = p.read_text()
MARK = "retry-on-error"
if MARK in s:
    print("already patched")
    raise SystemExit

pairs = [
    (
        "fn home_of(user: &str) -> Option<String> {\n",
        "/// retry-on-error: log a failure to syslog (authpriv).\n"
        "fn log_err(msg: &str) {\n"
        "    let Ok(c) = CString::new(format!(\"pam_rust_fp_safe: {msg}\")) else { return };\n"
        "    unsafe {\n"
        "        libc::syslog(libc::LOG_AUTHPRIV | libc::LOG_WARNING, b\"%s\\0\".as_ptr() as *const c_char, c.as_ptr());\n"
        "    }\n"
        "}\n"
        "\n"
        "fn home_of(user: &str) -> Option<String> {\n",
    ),
    (
        "    let Ok(connection) = Connection::system() else { return Outcome::Failed };\n"
        "    let Ok(proxy) = RustFpProxyBlocking::new(&connection) else { return Outcome::Failed };\n",
        "    let connection = match Connection::system() {\n"
        "        Ok(c) => c,\n"
        "        Err(e) => {\n"
        "            log_err(&format!(\"system bus: {e}\"));\n"
        "            return Outcome::Failed;\n"
        "        }\n"
        "    };\n"
        "    let proxy = match RustFpProxyBlocking::new(&connection) {\n"
        "        Ok(p) => p,\n"
        "        Err(e) => {\n"
        "            log_err(&format!(\"proxy: {e}\"));\n"
        "            return Outcome::Failed;\n"
        "        }\n"
        "    };\n",
    ),
    (
        "        let Ok(bytes) = proxy.match_templates(blobs.clone()) else { return Outcome::Failed };\n"
        "        let Ok(output) = from_bytes::<MatchOutput>(&bytes) else { return Outcome::Failed };\n",
        "        let bytes = match proxy.match_templates(blobs.clone()) {\n"
        "            Ok(b) => b,\n"
        "            Err(e) => {\n"
        "                log_err(&format!(\"MatchTemplates: {e}\"));\n"
        "                return Outcome::Failed;\n"
        "            }\n"
        "        };\n"
        "        let Ok(output) = from_bytes::<MatchOutput>(&bytes) else {\n"
        "            log_err(\"MatchTemplates: undecodable reply\");\n"
        "            return Outcome::Failed;\n"
        "        };\n",
    ),
    (
        "        Ok(Outcome::Failed) | Err(RecvTimeoutError::Disconnected) => PAM_AUTH_ERR,\n",
        "        Ok(Outcome::Failed) | Err(RecvTimeoutError::Disconnected) => {\n"
        "            // retry-on-error: let the lock screen re-arm instead of giving\n"
        "            // up until the next lock; pause so a dead daemon cannot spin.\n"
        "            if retry {\n"
        "                log_err(\"wait failed, asking the caller to retry\");\n"
        "                thread::sleep(Duration::from_secs(2));\n"
        "                PAM_AUTHINFO_UNAVAIL\n"
        "            } else {\n"
        "                PAM_AUTH_ERR\n"
        "            }\n"
        "        }\n",
    ),
]
for old, new in pairs:
    if s.count(old) != 1:
        raise SystemExit(f"pattern not found exactly once:\n{old}")
    s = s.replace(old, new)
p.write_text(s)
print("patched", p)
