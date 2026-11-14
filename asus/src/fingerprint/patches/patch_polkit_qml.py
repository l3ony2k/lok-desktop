#!/usr/bin/env python3
"""Make the Quickshell (dots-hyprland ii) polkit dialog wait for PAM's password
request, so the 10 s fingerprint wait in /etc/pam.d/polkit-1 cannot swallow a
typed password or leave the dialog disabled. Idempotent."""
import pathlib

home = pathlib.Path.home()
targets = [
    home / ".config/quickshell/ii/services/PolkitService.qml",
    home / "dots-hyprland/dots/.config/quickshell/ii/services/PolkitService.qml",
]

REPL = [
    (
        '        return cleanedInputPrompt || (usePasswordChars ? Translation.tr("Password") : Translation.tr("Input"))',
        '        // ASUS fingerprint: PAM waits for the sensor before it asks for a password\n'
        '        if (!(PolkitService.flow?.isResponseRequired ?? false)) return "Touch the fingerprint sensor, or wait to use your password"\n'
        '        return cleanedInputPrompt || (usePasswordChars ? Translation.tr("Password") : Translation.tr("Input"))',
    ),
    (
        '        function onAuthenticationFailed() {\n'
        '            root.interactionAvailable = true;\n'
        '        }',
        '        function onAuthenticationFailed() {\n'
        '            root.interactionAvailable = root.flow?.isResponseRequired ?? true;\n'
        '        }\n'
        '        // ASUS fingerprint: only accept input once PAM actually asks for it\n'
        '        function onIsResponseRequiredChanged() {\n'
        '            root.interactionAvailable = root.flow?.isResponseRequired ?? false;\n'
        '        }',
    ),
    (
        '        onAuthenticationRequestStarted: {\n'
        '            root.interactionAvailable = true;\n'
        '        }',
        '        onAuthenticationRequestStarted: {\n'
        '            root.interactionAvailable = polkitAgent.flow?.isResponseRequired ?? false;\n'
        '        }',
    ),
]

for p in targets:
    if not p.exists():
        print("missing", p)
        continue
    s = p.read_text()
    if "ASUS fingerprint" in s:
        print("already patched", p)
        continue
    for old, new in REPL:
        if old not in s:
            raise SystemExit(f"pattern not found in {p}:\n{old}")
        s = s.replace(old, new)
    p.write_text(s)
    print("patched", p)
