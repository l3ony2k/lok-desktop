#!/usr/bin/env python3
"""Parallel fingerprint + password for polkit (pam arg `parallel`).

PAM module (pam-safe/src/lib.rs), with `parallel`:
  - shows a password prompt at once and waits for a finger in a thread;
  - password typed first: stop the finger wait, put the password in
    PAM_AUTHTOK and return a failure, so the following pam_unix
    (try_first_pass) checks it;
  - finger first: the conversation is still blocked on the prompt, so the
    agent must answer it. The daemon emits MatchSucceeded; the Quickshell
    polkit agent then submits an empty response. The module returns success
    only if its own match thread reported a match: the empty response proves
    nothing by itself.
  - empty response without a match: prompt again.
Daemon (common/src/rust_fp_dbus.rs): emit org.rust_fp.RustFp.MatchSucceeded on
every successful match.
sudo is unchanged (no `parallel` arg). Idempotent; run in rust-fp-sandbox/src.
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
MARK = "parallel-polkit"


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


# ---- daemon: MatchSucceeded signal ----
patch("common/src/rust_fp_dbus.rs", [
    (
        "    async fn match_templates(&mut self, templates: Vec<Vec<u8>>) -> fdo::Result<Vec<u8>> {\n",
        "    /// Emitted after every successful match (parallel-polkit). Carries no\n"
        "    /// data; it only tells a polkit agent to answer the open password prompt.\n"
        "    #[zbus(signal)]\n"
        "    async fn match_succeeded(ctxt: &zbus::SignalContext<'_>) -> zbus::Result<()>;\n"
        "\n"
        "    async fn match_templates(\n"
        "        &mut self,\n"
        "        templates: Vec<Vec<u8>>,\n"
        "        #[zbus(signal_context)] ctxt: zbus::SignalContext<'_>,\n"
        "    ) -> fdo::Result<Vec<u8>> {\n",
    ),
    (
        "        if !matches!(output, MatchOutput::TimedOut) {\n"
        "            warn!(\"Match result: {output:?}\");\n"
        "        }\n",
        "        if !matches!(output, MatchOutput::TimedOut) {\n"
        "            warn!(\"Match result: {output:?}\");\n"
        "        }\n"
        "        if matches!(output, MatchOutput::Match(_)) {\n"
        "            if let Err(e) = Self::match_succeeded(&ctxt).await {\n"
        "                warn!(\"Could not emit MatchSucceeded: {e:?}\");\n"
        "            }\n"
        "        }\n",
    ),
])

# ---- PAM module ----
patch("pam-safe/src/lib.rs", [
    (
        "const PAM_CONV_ITEM: c_int = 5;\n",
        "const PAM_CONV_ITEM: c_int = 5;\n"
        "const PAM_AUTHTOK_ITEM: c_int = 6;\n"
        "const PAM_PROMPT_ECHO_OFF: c_int = 1;\n"
        "/// parallel-polkit: how long an empty answer waits for the match thread\n"
        "/// (the daemon signals the agent before the thread hears back).\n"
        "const SIGNAL_GRACE: Duration = Duration::from_millis(1500);\n"
        "const MAX_PROMPTS: u32 = 20;\n",
    ),
    (
        "    fn free(ptr: *mut c_void);\n"
        "}\n",
        "    fn free(ptr: *mut c_void);\n"
        "    fn pam_set_item(pamh: *mut PamHandle, item_type: c_int, item: *const c_void) -> c_int;\n"
        "}\n"
        "\n"
        "/// Ask one question through the conversation and return the answer\n"
        "/// (parallel-polkit). None when the conversation fails or is cancelled.\n"
        "/// The C copy of the answer is wiped before it is freed.\n"
        "fn ask(pamh: &PamHandle, style: c_int, text: &str) -> Option<String> {\n"
        "    let ctext = CString::new(text).ok()?;\n"
        "    unsafe {\n"
        "        let mut item: *const c_void = std::ptr::null();\n"
        "        if pam_get_item(pamh as *const PamHandle, PAM_CONV_ITEM, &mut item) != 0 || item.is_null() {\n"
        "            return None;\n"
        "        }\n"
        "        let conv = &*(item as *const RawPamConv);\n"
        "        let f = conv.conv?;\n"
        "        let msg = RawPamMessage { msg_style: style, msg: ctext.as_ptr() };\n"
        "        let msg_ptr: *const RawPamMessage = &msg;\n"
        "        let mut resp: *mut RawPamResponse = std::ptr::null_mut();\n"
        "        let rc = f(1, &msg_ptr, &mut resp, conv.appdata_ptr);\n"
        "        if resp.is_null() {\n"
        "            return None;\n"
        "        }\n"
        "        let mut answer = None;\n"
        "        let r = (*resp).resp;\n"
        "        if !r.is_null() {\n"
        "            if rc == 0 {\n"
        "                answer = Some(CStr::from_ptr(r).to_string_lossy().into_owned());\n"
        "            }\n"
        "            let len = libc::strlen(r);\n"
        "            std::ptr::write_bytes(r, 0, len);\n"
        "            free(r as *mut c_void);\n"
        "        }\n"
        "        free(resp as *mut c_void);\n"
        "        answer\n"
        "    }\n"
        "}\n"
        "\n"
        "/// Hand a typed password to the next module (pam_unix try_first_pass).\n"
        "fn set_authtok(pamh: &mut PamHandle, password: &str) -> bool {\n"
        "    let Ok(c) = CString::new(password) else { return false };\n"
        "    let rc = unsafe { pam_set_item(pamh as *mut PamHandle, PAM_AUTHTOK_ITEM, c.as_ptr() as *const c_void) };\n"
        "    // pam_set_item copies the string; wipe ours.\n"
        "    let mut bytes = c.into_bytes();\n"
        "    for b in bytes.iter_mut() {\n"
        "        *b = 0;\n"
        "    }\n"
        "    rc == 0\n"
        "}\n",
    ),
    (
        "    let mut retry = false;\n"
        "    for a in args {\n",
        "    let mut retry = false;\n"
        "    let mut parallel = false;\n"
        "    for a in args {\n",
    ),
    (
        "        } else if a == \"retry\" {\n"
        "            retry = true;\n"
        "        }\n",
        "        } else if a == \"retry\" {\n"
        "            retry = true;\n"
        "        } else if a == \"parallel\" {\n"
        "            parallel = true;\n"
        "        }\n",
    ),
    (
        "    if !quiet {\n"
        "        say(\n"
        "            pamh,\n"
        "            PAM_TEXT_INFO,\n",
        "    if parallel {\n"
        "        return authenticate_parallel(pamh, templates);\n"
        "    }\n"
        "    if !quiet {\n"
        "        say(\n"
        "            pamh,\n"
        "            PAM_TEXT_INFO,\n",
    ),
    (
        "struct RustFpSafe;\n",
        "/// parallel-polkit: password prompt and finger wait at the same time.\n"
        "fn authenticate_parallel(pamh: &mut PamHandle, templates: Vec<(String, Vec<u8>)>) -> PamResultCode {\n"
        "    let cancel = Arc::new(AtomicBool::new(false));\n"
        "    let (tx, rx) = channel();\n"
        "    {\n"
        "        let cancel = cancel.clone();\n"
        "        thread::spawn(move || {\n"
        "            let r = catch_unwind(AssertUnwindSafe(|| match_loop(templates, cancel)))\n"
        "                .unwrap_or(Outcome::Failed);\n"
        "            let _ = tx.send(r);\n"
        "        });\n"
        "    }\n"
        "    // finger_done: the thread has finished without a match (no match 3x or\n"
        "    // error); from then on this is a plain password prompt.\n"
        "    let mut finger_done = false;\n"
        "    let mut matched = |wait: Duration, finger_done: &mut bool| -> bool {\n"
        "        if *finger_done {\n"
        "            return false;\n"
        "        }\n"
        "        match rx.recv_timeout(wait) {\n"
        "            Ok(Outcome::Matched(_)) => true,\n"
        "            Ok(_) | Err(RecvTimeoutError::Disconnected) => {\n"
        "                *finger_done = true;\n"
        "                false\n"
        "            }\n"
        "            Err(RecvTimeoutError::Timeout) => false,\n"
        "        }\n"
        "    };\n"
        "    let mut result = PAM_AUTH_ERR;\n"
        "    for _ in 0..MAX_PROMPTS {\n"
        "        let prompt = if finger_done { \"Password: \" } else { \"Password or fingerprint: \" };\n"
        "        let answer = ask(pamh, PAM_PROMPT_ECHO_OFF, prompt);\n"
        "        let fp = matched(Duration::ZERO, &mut finger_done);\n"
        "        match answer {\n"
        "            _ if fp => {\n"
        "                result = PAM_SUCCESS;\n"
        "                break;\n"
        "            }\n"
        "            None => break,\n"
        "            Some(a) if a.is_empty() => {\n"
        "                // Probably the agent answering MatchSucceeded before the\n"
        "                // thread heard back from the daemon.\n"
        "                if matched(SIGNAL_GRACE, &mut finger_done) {\n"
        "                    result = PAM_SUCCESS;\n"
        "                    break;\n"
        "                }\n"
        "            }\n"
        "            Some(a) => {\n"
        "                // A password: let pam_unix (try_first_pass) check it.\n"
        "                let _ = set_authtok(pamh, &a);\n"
        "                break;\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "    cancel.store(true, Ordering::SeqCst);\n"
        "    result\n"
        "}\n"
        "\n"
        "struct RustFpSafe;\n",
    ),
])
