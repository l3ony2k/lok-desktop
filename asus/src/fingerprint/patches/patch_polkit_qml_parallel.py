#!/usr/bin/env python3
"""Quickshell polkit agent side of parallel fingerprint + password.

While a polkit request is active, watch rust-fp's MatchSucceeded signal with
`gdbus monitor`; when it fires and PAM is waiting for an answer, submit an empty
response so pam_rust_fp_safe (`parallel`) can return. The module decides from
its own match result; the empty answer proves nothing. Idempotent; patches the
installed copy and the private dots repo copy.
"""
import pathlib

home = pathlib.Path.home()
targets = [
    home / ".config/quickshell/ii/services/PolkitService.qml",
    home / ".dotfiles/dots/.config/quickshell/ii/services/PolkitService.qml",
]
MARK = "parallel-polkit"

REPL = [
    (
        "import Quickshell\n",
        "import Quickshell\n"
        "import Quickshell.Io\n",
    ),
    (
        "    PolkitAgent {\n",
        "    // ASUS fingerprint (parallel-polkit): PAM shows the password prompt and\n"
        "    // waits for a finger at the same time. When rust-fp reports a match,\n"
        "    // answer the open prompt with an empty response so the module can\n"
        "    // return; the module's own match result decides, not this answer.\n"
        "    Process {\n"
        "        id: fpMatchWatcher\n"
        "        running: root.active\n"
        "        command: [\"gdbus\", \"monitor\", \"--system\", \"--dest\", \"org.rust_fp.RustFp\",\n"
        "            \"--object-path\", \"/org/rust_fp/RustFp\"]\n"
        "        stdout: SplitParser {\n"
        "            onRead: line => {\n"
        "                if (line.indexOf(\"org.rust_fp.RustFp.MatchSucceeded\") === -1) return;\n"
        "                if (root.flow && root.flow.isResponseRequired) root.submit(\"\");\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "\n"
        "    PolkitAgent {\n",
    ),
]

for p in targets:
    if not p.exists():
        print("missing", p)
        continue
    s = p.read_text()
    if MARK in s:
        print("already patched", p)
        continue
    for old, new in REPL:
        if s.count(old) != 1:
            raise SystemExit(f"pattern not unique/found in {p}:\n{old}")
        s = s.replace(old, new)
    p.write_text(s)
    print("patched", p)
