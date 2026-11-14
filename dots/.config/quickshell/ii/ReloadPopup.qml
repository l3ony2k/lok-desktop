import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
	id: root
	property bool failed;
	property string errorString;

	// lok style. Deliberately not using Appearance/Config: this popup must still render
	// when the shell config itself fails to load, so it reads the two JSON files directly
	// and falls back to the upstream look if anything is missing.
	property bool lok: false
	property var pal: ({})
	function readLok() {
		try { root.lok = JSON.parse(cfgFile.text()).appearance.style === "lok"; } catch (e) { root.lok = false; }
		try { root.pal = JSON.parse(colFile.text()); } catch (e) { root.pal = ({}); }
	}
	function c(key, fallback) { return (root.lok && root.pal[key]) ? root.pal[key] : fallback; }
	FileView { id: cfgFile; path: Quickshell.env("HOME") + "/.config/illogical-impulse/config.json"; blockLoading: true; onLoaded: root.readLok() }
	FileView { id: colFile; path: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"; blockLoading: true; onLoaded: root.readLok() }
	Component.onCompleted: readLok()

	// Connect to the Quickshell global to listen for the reload signals.
	Connections {
		target: Quickshell

		function onReloadCompleted() {
			root.failed = false;
			popupLoader.loading = true;
		}

		function onReloadFailed(error: string) {
			// Close any existing popup before making a new one.
			popupLoader.active = false;

			root.failed = true;
			root.errorString = error;
			popupLoader.loading = true;
		}
	}

	// Keep the popup in a loader because it isn't needed most of the time
	LazyLoader {
		id: popupLoader

		PanelWindow {
			id: popup

			exclusiveZone: 0
			anchors.top: true
			margins.top: 0

			implicitWidth: rect.width + shadow.radius * 2
			implicitHeight: rect.height + shadow.radius * 2

			WlrLayershell.namespace: "quickshell:reloadPopup"

			// color blending is a bit odd as detailed in the type reference.
			color: "transparent"

			Rectangle {
				id: rect
				anchors.centerIn: parent
				color: root.lok ? root.c("surface_container_high", "#313131") : (failed ?  "#ffe99195" : "#ffD1E8D5")
				// lok: four inside lines, 1 device px; Qt's border dropped sides at 1.333 scale
				readonly property real hair: 1 / (rect.QsWindow.window?.devicePixelRatio || 1)
				readonly property color lineColor: failed ? root.c("error", "#ff6e64") : root.c("outline", "#808080")
				Rectangle { visible: root.lok; z: 10; color: rect.lineColor; x: 0; y: 0; width: rect.width; height: rect.hair }
				Rectangle { visible: root.lok; z: 10; color: rect.lineColor; x: 0; y: rect.height - rect.hair; width: rect.width; height: rect.hair }
				Rectangle { visible: root.lok; z: 10; color: rect.lineColor; x: 0; y: 0; width: rect.hair; height: rect.height }
				Rectangle { visible: root.lok; z: 10; color: rect.lineColor; x: rect.width - rect.hair; y: 0; width: rect.hair; height: rect.height }

				implicitHeight: layout.implicitHeight + 30
				implicitWidth: layout.implicitWidth + 30
				radius: root.lok ? 0 : 12

				// Fills the whole area of the rectangle, making any clicks go to it,
				// which dismiss the popup.
				MouseArea {
					id: mouseArea
					anchors.fill: parent
					onPressed: {
						popupLoader.active = false
					}

					// makes the mouse area track mouse hovering, so the hide animation
					// can be paused when hovering.
					hoverEnabled: true
				}

				ColumnLayout {
					id: layout
					spacing: 10
					anchors {
						top: parent.top
						topMargin: 10
						horizontalCenter: parent.horizontalCenter
					}

					Text {
						renderType: Text.NativeRendering
						font.family: root.lok ? "IoskeleyMonoTerm Nerd Font" : "Google Sans Flex"
						font.weight: root.lok ? Font.Medium : Font.Normal
						font.pointSize: root.lok ? 12 : 14
						text: root.failed ? "Quickshell: Reload failed" : "Quickshell reloaded"
						color: root.lok ? (failed ? root.c("error", "#ff6e64") : root.c("on_surface", "#ededed")) : (failed ? "#ff93000A" : "#ff0C1F13")
					}

					Text {
						renderType: Text.NativeRendering
						font.family: "JetBrains Mono NF"
						font.pointSize: 11
						text: root.errorString
						color: root.lok ? (failed ? root.c("error", "#ff6e64") : root.c("on_surface", "#ededed")) : (failed ? "#ff93000A" : "#ff0C1F13")
						// When visible is false, it also takes up no space.
						visible: root.errorString != ""
					}
				}

				// A progress bar on the bottom of the screen, showing how long until the
				// popup is removed.
				Rectangle {
					z: 2
					id: bar
					color: root.lok ? (failed ? root.c("error", "#ff6e64") : root.c("on_surface", "#ededed")) : (failed ? "#ff93000A" : "#ff0C1F13")
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.margins: 10
					height: root.lok ? 2 : 5
					radius: root.lok ? 0 : 9999

					PropertyAnimation {
						id: anim
						target: bar
						property: "width"
						from: rect.width - bar.anchors.margins * 2
						to: 0
						duration: failed ? 10000 : 1000
						onFinished: popupLoader.active = false

						// Pause the animation when the mouse is hovering over the popup,
						// so it stays onscreen while reading. This updates reactively
						// when the mouse moves on and off the popup.
						paused: mouseArea.containsMouse
					}
				}
				// Its bg
				Rectangle {
					z: 1
					id: bar_bg
					color: root.lok ? root.c("outline_variant", "#474747") : (failed ? "#30af1b25" : "#4027643e")
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.margins: 10
					height: root.lok ? 2 : 5
					radius: root.lok ? 0 : 9999
					width: rect.width - bar.anchors.margins * 2
				}

				// We could set `running: true` inside the animation, but the width of the
				// rectangle might not be calculated yet, due to the layout.
				// In the `Component.onCompleted` event handler, all of the component's
				// properties and children have been initialized.
				Component.onCompleted: anim.start()
			}

			DropShadow {
				id: shadow
                anchors.fill: rect
                horizontalOffset: 0
                verticalOffset: 2
                radius: 6
                samples: radius * 2 + 1 // Ideally should be 2 * radius + 1, see qt docs
                color: root.lok ? "transparent" : "#44000000"
                source: rect
            }
		}
	}
}
