pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

Singleton {
    id: root
    property alias agent: polkitAgent
    property alias active: polkitAgent.isActive
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    property string cleanMessage: {
        if (!root.flow) return "";
        return root.flow.message.endsWith(".")
            ? root.flow.message.slice(0, -1)
            : root.flow.message
    }
    property string cleanPrompt: {
        const inputPrompt = PolkitService.flow?.inputPrompt.trim() ?? "";
        const cleanedInputPrompt = inputPrompt.endsWith(":") ? inputPrompt.slice(0, -1) : inputPrompt;
        const usePasswordChars = !PolkitService.flow?.responseVisible ?? true
        // ASUS fingerprint: PAM waits for the sensor before it asks for a password
        if (!(PolkitService.flow?.isResponseRequired ?? false)) return "Touch the fingerprint sensor, or wait to use your password"
        return cleanedInputPrompt || (usePasswordChars ? Translation.tr("Password") : Translation.tr("Input"))
    }

    function cancel() {
        root.flow.cancelAuthenticationRequest()
    }

    function submit(string) {
        root.flow.submit(string)
        root.interactionAvailable = false
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.interactionAvailable = root.flow?.isResponseRequired ?? true;
        }
        // ASUS fingerprint: only accept input once PAM actually asks for it
        function onIsResponseRequiredChanged() {
            root.interactionAvailable = root.flow?.isResponseRequired ?? false;
        }
    }

    // ASUS fingerprint (parallel-polkit): PAM shows the password prompt and
    // waits for a finger at the same time. When rust-fp reports a match,
    // answer the open prompt with an empty response so the module can
    // return; the module's own match result decides, not this answer.
    Process {
        id: fpMatchWatcher
        running: root.active
        command: ["gdbus", "monitor", "--system", "--dest", "org.rust_fp.RustFp",
            "--object-path", "/org/rust_fp/RustFp"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("org.rust_fp.RustFp.MatchSucceeded") === -1) return;
                if (root.flow && root.flow.isResponseRequired) root.submit("");
            }
        }
    }

    PolkitAgent {
        id: polkitAgent
        onAuthenticationRequestStarted: {
            root.interactionAvailable = polkitAgent.flow?.isResponseRequired ?? false;
        }
    }
}
