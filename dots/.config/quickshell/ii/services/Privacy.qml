pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

/**
 * Privacy indicators (2026-11-20): mic, camera, remote access (SSH), screen capture.
 * (Location was dropped: no GPS on this machine, GeoIP via the proxy said "Los Angeles".)
 * Each has a state: "off" (the feature is switched off), "idle" (on, nobody using it) or "active".
 *   mic       off = default source muted;     active = an app records from a mic (PipeWire link
 *                                              AudioSource -> AudioInStream; sink monitors such as
 *                                              cava are AudioSink, so they don't count)
 *   camera    off = CameraCtl privacy block;  active = an app reads a camera: a PipeWire link from a
 *                                              VideoSource that is not the screencast portal, or a
 *                                              process holding /dev/video* directly (libcamera apps)
 *   remote    off = sshd not running;        active = an established inbound SSH connection
 *   screen    never off;                       active = Hyprland "screencast" event / portal stream
 * IPC for testing the look: qs -c ii ipc call privacy simulate camera active|idle|off|real
 */
Singleton {
    id: root

    // ---------- mic / camera / screen-portal from PipeWire ----------
    readonly property var links: Pipewire.linkGroups.values
    function isScreencastNode(node) {
        const p = node?.properties ?? {};
        const n = `${node?.name ?? ""} ${p["node.name"] ?? ""} ${p["application.name"] ?? ""}`.toLowerCase();
        return n.includes("xdpw") || n.includes("xdg-desktop-portal") || n.includes("screencast");
    }
    function appName(node) {
        const p = node?.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || node?.description || node?.name || "?";
    }
    function uniq(list) { return list.filter((v, i) => list.indexOf(v) === i); }

    // Any capture stream not fed from a speaker output (cava etc. read sink monitors = AudioSink).
    // Covers virtual mics too (EasyEffects: app <- easyeffects_source); EasyEffects' own
    // processing streams (ee_*, easyeffects*) are not apps and are left out.
    function isEasyEffects(node) {
        const n = (node?.name ?? "").toLowerCase();
        return n.startsWith("ee_") || n.startsWith("easyeffects");
    }
    readonly property var micLinks: links.filter(g => g.target?.type === PwNodeType.AudioInStream
        && g.source?.type !== PwNodeType.AudioSink && !isEasyEffects(g.target))
    readonly property var cameraLinks: links.filter(g => g.source?.type === PwNodeType.VideoSource && !isScreencastNode(g.source))
    readonly property var portalLinks: links.filter(g => g.source?.type === PwNodeType.VideoSource && isScreencastNode(g.source))

    PwObjectTracker { // node properties (app names) are only filled for tracked nodes
        objects: root.links.map(g => g.target).concat(root.links.map(g => g.source))
    }

    readonly property var micApps: uniq(micLinks.map(g => appName(g.target)))
    readonly property var cameraApps: uniq(cameraLinks.map(g => appName(g.target)).concat(cameraDirectApps))

    // ---------- camera opened directly (libcamera/V4L2 apps such as qcam, some browsers) ----------
    // Not visible in PipeWire: list processes holding a /dev/video* node, minus PipeWire/WirePlumber
    // (WirePlumber keeps the devices open for enumeration). ~40 ms per scan; skipped while blocked.
    property var cameraDirectApps: []
    Process {
        id: camProc
        command: ["sh", "-c", "for fd in $(find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null); do "
            + "pid=${fd#/proc/}; pid=${pid%%/*}; c=$(cat /proc/$pid/comm 2>/dev/null); "
            + "case \"$c\" in pipewire*|wireplumber|'') ;; *) echo \"$c\";; esac; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const apps = text.split("\n").filter(l => l.length > 0);
                if (JSON.stringify(apps) !== JSON.stringify(root.cameraDirectApps)) root.cameraDirectApps = apps;
            }
        }
    }
    Timer {
        interval: 2500
        running: !CameraCtl.privacy
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!camProc.running) camProc.running = true
        onRunningChanged: if (!running) root.cameraDirectApps = []
    }
    readonly property var screenApps: uniq(portalLinks.map(g => appName(g.target)).concat(hyprScreencastOwner ? [hyprScreencastOwner] : []))

    // ---------- screen: Hyprland screencast event (screencopy and portal) ----------
    // Screencopy tools (wf-recorder, grim) send "screencast>>1,<kind>" then ">>0" for EVERY frame;
    // the portal sends one 1 at the start and one 0 at the end. So 1 = on now, 0 = off after 1.5 s
    // without another 1.
    property bool hyprScreencast: false
    property string hyprScreencastOwner: ""
    Timer {
        id: screencastOff
        interval: 1500
        onTriggered: { root.hyprScreencast = false; root.hyprScreencastOwner = ""; }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "screencast") return;
            const [state, kind] = event.data.split(",");
            if (state === "1") {
                screencastOff.stop();
                root.hyprScreencast = true;
                root.hyprScreencastOwner = kind === "window" ? Translation.tr("a window")
                    : kind === "region" ? Translation.tr("a screen region") : Translation.tr("the screen");
            } else {
                screencastOff.restart();
            }
        }
    }

    // ---------- remote: inbound SSH (polled) ----------
    // off = sshd not running; active = an established connection to port 22. Peers on the tailnet
    // are named from `tailscale status` ("macbook (Tailscale)"), others shown by address.
    property bool sshdUp: false
    property var remotePeers: []
    Process {
        id: remoteProc
        command: ["sh", "-c", "systemctl is-active -q sshd && echo sshd=1 || echo sshd=0; "
            + "ts=$(tailscale status 2>/dev/null); "
            + "ss -Htn state established '( sport = :22 )' | awk '{print $NF}' | sed 's/:[0-9]*$//; s/^\\[//; s/\\]$//; s/^::ffff://' | sort -u | "
            + "while read ip; do n=$(printf '%s\\n' \"$ts\" | awk -v ip=\"$ip\" '$1==ip{print $2}'); "
            + "if [ -n \"$n\" ]; then echo \"peer=$n (Tailscale)\"; else echo \"peer=$ip\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.sshdUp = lines.includes("sshd=1");
                const peers = lines.filter(l => l.startsWith("peer=")).map(l => l.slice(5));
                if (JSON.stringify(peers) !== JSON.stringify(root.remotePeers)) root.remotePeers = peers;
            }
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!remoteProc.running) remoteProc.running = true
    }

    // ---------- states ----------
    property var simulated: ({}) // kind -> "off" | "idle" | "active"
    function pick(kind, real) { return root.simulated[kind] ?? real; }

    // "active" wins over "off": a muted mic that an app still holds open is still being listened to
    readonly property string mic: pick("mic", micLinks.length > 0 ? "active" : (Audio.source?.audio?.muted ?? false) ? "off" : "idle")
    readonly property string camera: pick("camera", (cameraLinks.length > 0 || cameraDirectApps.length > 0) ? "active" : CameraCtl.privacy ? "off" : "idle")
    readonly property string remote: pick("remote", remotePeers.length > 0 ? "active" : !sshdUp ? "off" : "idle")
    readonly property string screen: pick("screen", (hyprScreencast || portalLinks.length > 0) ? "active" : "idle")
    readonly property bool anyActive: mic === "active" || camera === "active" || remote === "active" || screen === "active"

    function describe(kind) {
        const st = root[kind];
        if (st === "off") return Translation.tr("off");
        if (st === "idle") return Translation.tr("not in use");
        const apps = kind === "mic" ? micApps : kind === "camera" ? cameraApps : kind === "screen" ? screenApps : kind === "remote" ? remotePeers : [];
        return apps.length > 0 ? apps.join(", ") : Translation.tr("in use");
    }

    IpcHandler {
        target: "privacy"
        function simulate(kind: string, state: string): void {
            const s = Object.assign({}, root.simulated);
            if (state === "real") delete s[kind]; else s[kind] = state;
            root.simulated = s;
        }
        function status(): string {
            return `mic=${root.mic} camera=${root.camera} remote=${root.remote} screen=${root.screen}`;
        }
    }
}
