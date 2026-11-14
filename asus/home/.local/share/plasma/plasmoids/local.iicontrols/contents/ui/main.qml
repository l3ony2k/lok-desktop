/*
 * Leon's Toggles — the ii (end-4 Quickshell) quick toggles that Plasma lacks.
 * 2026-11-12, ASUS. Same backends as ii, so both sessions see one state:
 *   Mihomo      mihomo.service (pkexec systemctl) + REST API on 127.0.0.1:9090
 *   Tailscale   tailscaled.service (pkexec) + `tailscale up/down` (operator set)
 *   SSH (LAN)   sudo -n /usr/local/bin/ssh-lan-toggle
 *   Camera      sudo -n /usr/local/bin/camera-ctl (+ wireplumber restart)
 *   Coffee      ~/.local/bin/plasma-coffee (Plasma version: kde-inhibit + lid → lock)
 *   EasyEffects easyeffects --service-mode / pkill
 *   Charge      /usr/local/bin/battery-limit (status unprivileged, set via sudo -n);
 *               the choice is saved and re-applied at boot, unlike Plasma's own setting
 * Nothing here reads or writes ii's own files.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string api: "http://127.0.0.1:9090"

    // ---- state ---------------------------------------------------------
    property string mihomoState: "unknown"     // ActiveState of mihomo.service
    property bool mihomoBusy: false
    property bool mihomoInfo: false
    property string mihomoMode: ""
    property bool mihomoTun: false
    property int mihomoPort: 0
    property string mihomoVersion: ""
    property string mihomoNode: ""
    property var mihomoNodes: []
    property int mihomoConns: 0
    property real mihomoUp: 0
    property real mihomoDown: 0

    property string tsDaemon: "unknown"
    property string tsBackend: ""
    property string tsIp: ""
    property bool tsBusy: false

    property string sshState: "unknown"         // on | off
    property string sshRange: ""
    property bool sshBusy: false

    property string camPrivacy: "unknown"       // on = blocked
    property string camHealth: "unknown"
    property bool camBusy: false
    property bool camSynced: false

    property bool coffee: false
    property bool coffeeBusy: false

    property bool eeRunning: false
    property bool eeInstalled: true

    property int chargeLimit: 0
    property int batteryPct: 0
    property string batteryState: ""
    property bool chargeBusy: false
    property bool chargeAvailable: true

    property string lastError: ""

    readonly property bool mihomoActive: mihomoState === "active"

    Plasmoid.icon: "network-vpn-symbolic"
    compactRepresentation: Kirigami.Icon {
        source: "network-vpn-symbolic"
        active: compactMouse.containsMouse
        opacity: root.mihomoActive ? 1 : 0.45
        MouseArea {
            id: compactMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: "Leon's Toggles"
    toolTipSubText: {
        let s = [];
        s.push("Mihomo: " + (mihomoActive ? (mihomoMode || "on") + (mihomoNode ? " · " + mihomoNode : "") : "off"));
        s.push("Tailscale: " + (tsBackend === "Running" ? (tsIp || "on") : "off"));
        if (coffee) s.push("Coffee: on");
        if (camPrivacy === "on") s.push("Camera: blocked");
        return s.join("\n");
    }

    // ---- command runner (executable engine, one callback per call) ------
    property int seq: 0
    property var callbacks: ({})

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = root.callbacks[source];
            delete root.callbacks[source];
            exec.disconnectSource(source);
            if (cb)
                cb(data["exit code"], data.stdout || "", data.stderr || "");
        }
    }

    function run(cmd, cb) {
        const src = cmd + " # " + (++seq);
        callbacks[src] = cb || null;
        exec.connectSource(src);
    }

    function kv(text) {
        const o = {};
        text.split("\n").forEach(l => {
            const i = l.indexOf("=");
            if (i > 0) o[l.slice(0, i).trim()] = l.slice(i + 1).trim();
        });
        return o;
    }

    function fail(what, code, err) {
        // 126/127: pkexec dialog dismissed / not authorised
        lastError = what + " failed (exit " + code + ")" + (err ? ": " + err.trim().split("\n").pop() : "");
    }

    // ---- Mihomo ----------------------------------------------------------
    function http(method, path, body, cb) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let j = null;
            try { j = x.responseText ? JSON.parse(x.responseText) : {}; } catch (e) {}
            if (cb) cb(x.status, j);
        };
        x.open(method, api + path);
        if (body !== null) x.setRequestHeader("Content-Type", "application/json");
        x.send(body === null ? null : JSON.stringify(body));
    }

    function refreshMihomo() {
        run("systemctl show -p ActiveState --value mihomo.service", (c, out) => {
            mihomoState = out.trim() || "unknown";
            if (!mihomoActive) { mihomoInfo = false; return; }
            http("GET", "/configs", null, (s, j) => {
                if (s !== 200 || !j) { mihomoInfo = false; return; }
                mihomoMode = j.mode || "";
                mihomoTun = !!(j.tun && j.tun.enable);
                mihomoPort = j["mixed-port"] || j.port || 0;
                mihomoInfo = true;
            });
            http("GET", "/proxies/PROXY", null, (s, j) => {
                if (s === 200 && j) { mihomoNode = j.now || ""; mihomoNodes = j.all || []; }
            });
            http("GET", "/connections", null, (s, j) => {
                if (s === 200 && j) {
                    mihomoConns = (j.connections || []).length;
                    mihomoUp = j.uploadTotal || 0;
                    mihomoDown = j.downloadTotal || 0;
                }
            });
            if (!mihomoVersion)
                http("GET", "/version", null, (s, j) => { if (s === 200 && j) mihomoVersion = j.version || ""; });
        });
    }

    function toggleMihomo() {
        if (mihomoBusy) return;
        mihomoBusy = true;
        const action = mihomoActive ? "stop" : "start";
        run("pkexec /usr/bin/systemctl " + action + " mihomo.service", (c, out, err) => {
            mihomoBusy = false;
            if (c !== 0) fail("mihomo " + action, c, err);
            refreshMihomo();
        });
    }

    function setMode(m) {
        http("PATCH", "/configs", { mode: m }, (s) => {
            if (s >= 300) lastError = "Could not change mode (HTTP " + s + ")";
            refreshMihomo();
        });
    }

    function setNode(n) {
        http("PUT", "/proxies/PROXY", { name: n }, (s) => {
            if (s >= 300) lastError = "Could not select " + n + " (HTTP " + s + ")";
            refreshMihomo();
        });
    }

    function bytes(n) {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return (i ? n.toFixed(1) : n) + " " + u[i];
    }

    // ---- Tailscale -------------------------------------------------------
    function refreshTailscale() {
        run("systemctl show -p ActiveState --value tailscaled.service", (c, out) => {
            tsDaemon = out.trim() || "unknown";
            if (tsDaemon !== "active") { tsBackend = ""; tsIp = ""; return; }
            run("tailscale status --json --peers=false", (c2, out2) => {
                try {
                    const j = JSON.parse(out2);
                    tsBackend = j.BackendState || "";
                    tsIp = (j.Self && j.Self.TailscaleIPs && j.Self.TailscaleIPs[0]) || "";
                } catch (e) { tsBackend = ""; tsIp = ""; }
            });
        });
    }

    function toggleTailscale() {
        if (tsBusy) return;
        tsBusy = true;
        let cmd;
        if (tsDaemon !== "active") cmd = "pkexec /usr/bin/systemctl start tailscaled.service";
        else if (tsBackend === "Running") cmd = "/usr/bin/tailscale down";
        else cmd = "/usr/bin/tailscale up --accept-dns=false";   // mihomo keeps DNS, as in ii
        run(cmd, (c, out, err) => {
            tsBusy = false;
            if (c !== 0) fail("tailscale", c, err);
            refreshTailscale();
        });
    }

    // ---- SSH (LAN) -------------------------------------------------------
    function refreshSsh() {
        run("sudo -n /usr/local/bin/ssh-lan-toggle status", (c, out) => {
            if (c !== 0) { sshState = "unknown"; return; }
            const o = kv(out);
            sshState = o.state || "unknown";
            sshRange = o.range || "";
        });
    }

    function toggleSsh() {
        if (sshBusy) return;
        sshBusy = true;
        run("sudo -n /usr/local/bin/ssh-lan-toggle " + (sshState === "on" ? "off" : "on"), (c, out, err) => {
            sshBusy = false;
            if (c !== 0) fail("ssh-lan-toggle", c, err);
            refreshSsh();
        });
    }

    // ---- Camera ----------------------------------------------------------
    function refreshCamera() {
        run("sudo -n /usr/local/bin/camera-ctl status", (c, out) => {
            if (c !== 0) { camPrivacy = "unknown"; return; }
            const o = kv(out);
            camPrivacy = o.privacy || "unknown";
            camHealth = o.health || "unknown";
            // After boot udev resets the nodes; re-apply the saved block once per session (as ii does).
            if (!camSynced && o.applied === "no" && camPrivacy === "on") {
                camSynced = true;
                run("sudo -n /usr/local/bin/camera-ctl sync && systemctl --user restart wireplumber.service", () => refreshCamera());
            }
            camSynced = true;
        });
    }

    function toggleCamera() {
        if (camBusy) return;
        camBusy = true;
        // camera-ctl: "off" = privacy on (camera blocked), "on" = camera allowed
        const arg = camPrivacy === "on" ? "on" : "off";
        run("sudo -n /usr/local/bin/camera-ctl " + arg + " && systemctl --user restart wireplumber.service", (c, out, err) => {
            camBusy = false;
            if (c !== 0) fail("camera-ctl " + arg, c, err);
            refreshCamera();
        });
    }

    function recoverCamera() {
        if (camBusy) return;
        camBusy = true;
        run("sudo -n /usr/local/bin/camera-ctl recover", (c, out, err) => {
            camBusy = false;
            if (c !== 0) fail("camera-ctl recover", c, err);
            refreshCamera();
        });
    }

    // ---- Coffee ----------------------------------------------------------
    function refreshCoffee() {
        run("$HOME/.local/bin/plasma-coffee status", (c, out) => coffee = out.trim() === "on");
    }

    function toggleCoffee() {
        if (coffeeBusy) return;
        coffeeBusy = true;
        run("$HOME/.local/bin/plasma-coffee " + (coffee ? "off" : "on"), (c, out, err) => {
            coffeeBusy = false;
            if (c !== 0) fail("plasma-coffee", c, err);
            refreshCoffee();
        });
    }

    // ---- Charge limit ------------------------------------------------------
    function refreshCharge() {
        run("/usr/local/bin/battery-limit status", (c, out) => {
            const o = kv(out);
            chargeAvailable = c === 0 && !!o.limit;
            chargeLimit = parseInt(o.limit) || 0;
            batteryPct = parseInt(o.capacity) || 0;
            batteryState = o.status || "";
        });
    }

    function setCharge(v) {
        if (chargeBusy || v === chargeLimit) return;
        chargeBusy = true;
        run("sudo -n /usr/local/bin/battery-limit set " + v, (c, out, err) => {
            chargeBusy = false;
            if (c !== 0) fail("battery-limit", c, err);
            refreshCharge();
        });
    }

    // ---- EasyEffects -----------------------------------------------------
    function refreshEe() {
        run("command -v easyeffects >/dev/null && echo yes; pidof easyeffects >/dev/null && echo running", (c, out) => {
            eeInstalled = out.indexOf("yes") >= 0;
            eeRunning = out.indexOf("running") >= 0;
        });
    }

    function toggleEe() {
        if (eeRunning)
            run("pkill -x easyeffects", () => eeTimer.restart());
        else
            run("setsid -f easyeffects --hide-window --service-mode >/dev/null 2>&1", () => eeTimer.restart());
    }

    Timer { id: eeTimer; interval: 1200; onTriggered: root.refreshEe() }

    function refreshAll() {
        refreshMihomo();
        refreshTailscale();
        refreshSsh();
        refreshCamera();
        refreshCoffee();
        refreshCharge();
        refreshEe();
    }

    Timer {
        interval: root.expanded ? 2000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.expanded ? root.refreshAll() : (root.refreshMihomo(), root.refreshTailscale(), root.refreshCoffee())
    }
    onExpandedChanged: if (expanded) { lastError = ""; refreshAll(); }

    // ---- UI ----------------------------------------------------------------
    component ToggleRow: RowLayout {
        id: row
        property string icon
        property string title
        property string subtitle
        property bool checked
        property bool busy: false
        property bool available: true
        signal toggled()
        spacing: Kirigami.Units.largeSpacing
        Layout.fillWidth: true
        Kirigami.Icon {
            source: row.icon
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            opacity: row.checked ? 1 : 0.55
        }
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            PC3.Label { text: row.title; Layout.fillWidth: true; elide: Text.ElideRight }
            PC3.Label {
                text: row.subtitle
                visible: text.length > 0
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
        PC3.BusyIndicator { visible: row.busy; running: row.busy; Layout.preferredHeight: Kirigami.Units.iconSizes.small; Layout.preferredWidth: Layout.preferredHeight }
        PC3.Switch {
            checked: row.checked
            enabled: !row.busy && row.available
            onToggled: { checked = Qt.binding(() => row.checked); row.toggled(); }
        }
    }

    component InfoLine: RowLayout {
        property string k
        property string v
        Layout.fillWidth: true
        PC3.Label { text: parent.k; opacity: 0.7; Layout.preferredWidth: Kirigami.Units.gridUnit * 5 }
        PC3.Label { text: parent.v; Layout.fillWidth: true; elide: Text.ElideRight }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        collapseMarginsHint: true

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Mihomo
            ToggleRow {
                icon: "network-vpn-symbolic"
                title: root.mihomoVersion ? "Mihomo " + root.mihomoVersion : "Mihomo"
                subtitle: root.mihomoActive ? (root.mihomoMode + (root.mihomoNode ? " · " + root.mihomoNode : "")) : (root.mihomoState === "unknown" ? "" : "Stopped")
                checked: root.mihomoActive
                busy: root.mihomoBusy
                onToggled: root.toggleMihomo()
            }
            ColumnLayout {
                visible: root.mihomoActive && root.mihomoInfo
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: [["rule", "Rule"], ["global", "Global"], ["direct", "Direct"]]
                        PC3.Button {
                            required property var modelData
                            text: modelData[1]
                            checkable: true
                            checked: root.mihomoMode === modelData[0]
                            Layout.fillWidth: true
                            onClicked: root.setMode(modelData[0])
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: "Node"; opacity: 0.7; Layout.preferredWidth: Kirigami.Units.gridUnit * 5 }
                    PC3.ComboBox {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        model: root.mihomoNodes
                        currentIndex: root.mihomoNodes.indexOf(root.mihomoNode)
                        onActivated: (i) => root.setNode(root.mihomoNodes[i])
                    }
                }
                InfoLine { k: "TUN"; v: (root.mihomoTun ? "On" : "Off") + (root.mihomoPort ? "  ·  port " + root.mihomoPort : "") }
                InfoLine { k: "Traffic"; v: "↑ " + root.bytes(root.mihomoUp) + "   ↓ " + root.bytes(root.mihomoDown) + "   (" + root.mihomoConns + " conn)" }
                PC3.Button {
                    text: "Open dashboard"
                    icon.name: "internet-web-browser"
                    onClicked: Qt.openUrlExternally(root.api + "/ui/")
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing; Layout.bottomMargin: Kirigami.Units.smallSpacing }

            ToggleRow {
                icon: "network-connect-symbolic"
                title: "Tailscale"
                subtitle: root.tsDaemon !== "active" ? "Daemon stopped" : (root.tsBackend === "Running" ? root.tsIp : (root.tsBackend || "…"))
                checked: root.tsBackend === "Running"
                busy: root.tsBusy
                onToggled: root.toggleTailscale()
            }
            PC3.Button {
                visible: root.tsIp.length > 0 && root.tsBackend === "Running"
                text: "Copy " + root.tsIp
                icon.name: "edit-copy"
                flat: true
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                onClicked: root.run("wl-copy " + root.tsIp, null)
            }
            ToggleRow {
                icon: "network-server-symbolic"
                title: "SSH from LAN"
                subtitle: root.sshState === "unknown" ? "Helper unavailable" : root.sshRange
                checked: root.sshState === "on"
                available: root.sshState !== "unknown"
                busy: root.sshBusy
                onToggled: root.toggleSsh()
            }
            ToggleRow {
                icon: root.camPrivacy === "on" ? "camera-off-symbolic" : "camera-web-symbolic"
                title: "Camera"
                subtitle: root.camPrivacy === "on" ? "Blocked" : (root.camHealth === "broken" ? "Broken after hibernate" : (root.camPrivacy === "unknown" ? "Helper unavailable" : "Allowed"))
                checked: root.camPrivacy === "off"
                available: root.camPrivacy !== "unknown"
                busy: root.camBusy
                onToggled: root.toggleCamera()
            }
            PC3.Button {
                visible: root.camHealth === "broken"
                text: "Recover camera"
                icon.name: "view-refresh"
                Layout.leftMargin: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
                onClicked: root.recoverCamera()
            }
            ToggleRow {
                icon: "system-suspend-inhibited"
                title: "Coffee"
                subtitle: root.coffee ? "No idle sleep · lid close only locks" : "Normal power management"
                checked: root.coffee
                busy: root.coffeeBusy
                onToggled: root.toggleCoffee()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: root.chargeLimit >= 100 ? "battery-full-charging" : (root.chargeLimit >= 80 ? "battery-080-charging" : "battery-060-charging")
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    PC3.Label { text: "Charge limit"; Layout.fillWidth: true }
                    PC3.Label {
                        text: root.chargeAvailable ? ("Battery " + root.batteryPct + "% · " + (root.batteryState || "—")) : "Helper unavailable"
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                Repeater {
                    model: [60, 80, 100]
                    PC3.Button {
                        required property int modelData
                        text: modelData + "%"
                        checkable: true
                        checked: root.chargeLimit === modelData
                        enabled: root.chargeAvailable && !root.chargeBusy
                        implicitWidth: Kirigami.Units.gridUnit * 3
                        onClicked: { checked = Qt.binding(() => root.chargeLimit === modelData); root.setCharge(modelData); }
                    }
                }
            }
            ToggleRow {
                icon: "audio-volume-high-symbolic"
                title: "EasyEffects"
                subtitle: root.eeInstalled ? (root.eeRunning ? "Running" : "Off") : "Not installed"
                checked: root.eeRunning
                available: root.eeInstalled
                onToggled: root.toggleEe()
            }

            PC3.Label {
                visible: root.lastError.length > 0
                text: root.lastError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
        }
    }
}
