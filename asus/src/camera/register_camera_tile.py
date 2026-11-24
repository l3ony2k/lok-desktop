#!/usr/bin/env python3
"""Register the Camera quick toggle (ASUS 2026-11-09). Idempotent.

- copies CameraCtl.qml / CameraToggle.qml / AndroidCameraToggle.qml into the
  installed Quickshell config and the private dots repo copy
- AndroidToggleDelegateChooser.qml: DelegateChoice roleValue "camera"
- AndroidQuickPanel.qml: "camera" in availableToggleTypes
- ~/.config/illogical-impulse/config.json: append {"type": "camera", "size": 1}
  to sidebar.quickToggles.android.toggles (installed copy only; not in the repo)
"""
import json
import pathlib
import shutil
import sys

src = pathlib.Path(sys.argv[1])  # folder with the three QML files
home = pathlib.Path.home()
roots = [home / ".config/quickshell/ii", home / ".dotfiles/dots/.config/quickshell/ii"]

for r in roots:
    if not r.exists():
        print("missing", r)
        continue
    shutil.copy(src / "CameraCtl.qml", r / "services/CameraCtl.qml")
    shutil.copy(src / "CameraToggle.qml", r / "modules/common/models/quickToggles/CameraToggle.qml")
    shutil.copy(src / "AndroidCameraToggle.qml",
                r / "modules/ii/sidebarRight/quickToggles/androidStyle/AndroidCameraToggle.qml")

    dc = r / "modules/ii/sidebarRight/quickToggles/androidStyle/AndroidToggleDelegateChooser.qml"
    s = dc.read_text()
    if 'roleValue: "camera"' not in s:
        anchor = '    DelegateChoice { roleValue: "easyEffects"; AndroidEasyEffectsToggle {'
        if s.count(anchor) != 1:
            raise SystemExit(f"{dc}: easyEffects anchor not found")
        block = (
            '    // ASUS 2026-11-09: IPU6 camera (privacy + post-hibernate recovery)\n'
            '    DelegateChoice { roleValue: "camera"; AndroidCameraToggle {\n'
            '        required property int index\n'
            '        required property var modelData\n'
            '        buttonIndex: root.startingIndex + index\n'
            '        buttonData: modelData\n'
            '        editMode: root.editMode\n'
            '        expandedSize: modelData.size > 1\n'
            '        baseCellWidth: root.baseCellWidth\n'
            '        baseCellHeight: root.baseCellHeight\n'
            '        cellSpacing: root.spacing\n'
            '        cellSize: modelData.size\n'
            '    } }\n'
            '\n'
        )
        s = s.replace(anchor, block + anchor)
        dc.write_text(s)
        print("registered delegate", dc)

    qp = r / "modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml"
    s = qp.read_text()
    if '"camera"' not in s:
        anchor = 'availableToggleTypes: ["network", "bluetooth",'
        if s.count(anchor) != 1:
            raise SystemExit(f"{qp}: availableToggleTypes anchor not found")
        s = s.replace(anchor, 'availableToggleTypes: ["network", "bluetooth", "camera",')
        qp.write_text(s)
        print("registered type", qp)

cfg = home / ".config/illogical-impulse/config.json"
d = json.loads(cfg.read_text())
toggles = d["sidebar"]["quickToggles"]["android"]["toggles"]
if not any(t.get("type") == "camera" for t in toggles):
    shutil.copy(cfg, cfg.with_name("config.json.bak-20261109-camera"))
    toggles.append({"size": 1, "type": "camera"})
    cfg.write_text(json.dumps(d, indent=4) + "\n")
    print("added camera tile to", cfg)
