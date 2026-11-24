import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * lok only: magnifier loupe + colour picker for the region selector (replaces CursorGuide in lok).
 * Every size is a whole number of device px (dev(n) = n / monitorScale), so 1 px lines stay crisp
 * at fractional scales. The pixel grid sits over arbitrary screen content, so its backdrop and the
 * centre-pixel marks use fixed neutral colours; the panel around it uses the lok tokens.
 */
Item {
    id: root
    property var action
    property string screenshotPath: ""
    property bool screenshotReady: false
    property real mouseX: 0
    property real mouseY: 0
    property real monitorScale: 1.0
    property bool shiftHeld: false
    property real zoomScale: 10.0 // device px per screenshot pixel (even, so the centre pixel stays centred)

    signal colorPicked(string colorText)

    function dev(n) { return n / root.monitorScale; }

    property bool sampleValid: false
    property int sampledR: 0
    property int sampledG: 0
    property int sampledB: 0

    property real screenWidth: 1  // logical size of the screen the screenshot covers
    property real screenHeight: 1
    readonly property int physWidth: Math.max(1, Math.round(root.screenWidth * root.monitorScale))
    readonly property int physHeight: Math.max(1, Math.round(root.screenHeight * root.monitorScale))
    readonly property int physX: Math.max(0, Math.min(physWidth - 1, Math.floor(root.mouseX * root.monitorScale)))
    readonly property int physY: Math.max(0, Math.min(physHeight - 1, Math.floor(root.mouseY * root.monitorScale)))

    function toHex(n) {
        const s = Math.max(0, Math.min(255, n)).toString(16).toUpperCase();
        return s.length < 2 ? "0" + s : s;
    }
    readonly property string hexText: `#${toHex(sampledR)}${toHex(sampledG)}${toHex(sampledB)}`
    readonly property string rgbText: `rgb(${sampledR}, ${sampledG}, ${sampledB})`
    readonly property string displayColorText: root.shiftHeld ? root.rgbText : root.hexText

    function pickColor() {
        if (!root.sampleValid) return; // screenshot not loaded yet: nothing real to copy
        root.colorPicked(root.displayColorText);
    }

    readonly property string screenshotUrl: root.screenshotReady && root.screenshotPath !== "" ? `file://${root.screenshotPath}` : ""
    onScreenshotUrlChanged: {
        root.sampleValid = false;
        if (screenshotUrl === "") return;
        pixelSampler.unloadImage(screenshotUrl);
        pixelSampler.loadImage(screenshotUrl);
    }
    onPhysXChanged: pixelSampler.requestPaint()
    onPhysYChanged: pixelSampler.requestPaint()
    Component.onDestruction: {
        if (screenshotUrl !== "") pixelSampler.unloadImage(screenshotUrl);
    }

    // 1x1 sampler: reads the exact physical pixel under the crosshair, independent of the loupe.
    Canvas {
        id: pixelSampler
        width: 1
        height: 1
        visible: false
        renderTarget: Canvas.Image
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 1, 1);
            if (root.screenshotUrl === "" || !isImageLoaded(root.screenshotUrl)) {
                root.sampleValid = false;
                return;
            }
            ctx.imageSmoothingEnabled = false;
            ctx.drawImage(root.screenshotUrl, root.physX, root.physY, 1, 1, 0, 0, 1, 1);
            const d = ctx.getImageData(0, 0, 1, 1).data;
            root.sampledR = d[0];
            root.sampledG = d[1];
            root.sampledB = d[2];
            root.sampleValid = true;
        }
    }

    // Layout in device px
    readonly property int gridPx: 200   // even: (gridPx - zoomScale) / 2 is a whole number
    readonly property int padPx: 8
    readonly property int rowPx: 28
    readonly property int swatchPx: 16

    implicitWidth: dev(gridPx + padPx * 2)
    implicitHeight: dev(padPx + gridPx + rowPx * 2 + padPx / 2)

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLokDialog
        LokFrame { z: 1 }

        // Pixel grid
        Rectangle {
            id: grid
            x: root.dev(root.padPx)
            y: root.dev(root.padPx)
            width: root.dev(root.gridPx)
            height: root.dev(root.gridPx)
            color: "#000000"
            clip: true

            // The whole screenshot, scaled on the GPU with nearest filtering and shifted so the
            // sampled pixel sits in the centre square. zoomScale device px per screenshot pixel
            // and an even grid keep every pixel edge on a device-pixel boundary.
            Image {
                readonly property real p: root.zoomScale / root.monitorScale
                source: root.screenshotUrl
                cache: false
                smooth: false
                mipmap: false
                width: root.physWidth * p
                height: root.physHeight * p
                x: root.dev((root.gridPx - root.zoomScale) / 2) - root.physX * p
                y: root.dev((root.gridPx - root.zoomScale) / 2) - root.physY * p
            }

            // Centre pixel: white hairline right around it, black hairline outside (reads on any content)
            Item {
                readonly property int o: (root.gridPx - root.zoomScale) / 2
                x: root.dev(o - 1); y: x
                width: root.dev(root.zoomScale + 2); height: width
                LokFrame { color: "#ffffff" }
            }
            Item {
                readonly property int o: (root.gridPx - root.zoomScale) / 2
                x: root.dev(o - 2); y: x
                width: root.dev(root.zoomScale + 4); height: width
                LokFrame { color: "#000000" }
            }
            LokFrame { z: 1 }
        }

        // Value row: swatch, colour value, mode icon
        Item {
            id: valueRow
            x: root.dev(root.padPx)
            y: grid.y + grid.height + root.dev(root.padPx / 2)
            width: grid.width
            height: root.dev(root.rowPx)

            Rectangle {
                id: swatch
                anchors.verticalCenter: parent.verticalCenter
                width: root.dev(root.swatchPx)
                height: width
                color: root.sampleValid ? Qt.rgba(root.sampledR / 255, root.sampledG / 255, root.sampledB / 255, 1) : "transparent"
                LokFrame {}
            }
            StyledText {
                anchors {
                    left: swatch.right
                    leftMargin: root.dev(root.padPx)
                    right: modeIcon.left
                    rightMargin: root.dev(root.padPx)
                    verticalCenter: parent.verticalCenter
                }
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: root.sampleValid ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                text: root.sampleValid ? root.displayColorText : "…"
            }
            MaterialSymbol {
                id: modeIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
                text: switch (root.action) {
                case RegionSelection.SnipAction.Search: return "image_search";
                case RegionSelection.SnipAction.CharRecognition: return "document_scanner";
                case RegionSelection.SnipAction.Record:
                case RegionSelection.SnipAction.RecordWithSound: return "videocam";
                default: return "content_cut";
                }
            }
        }

        // Hint row (the discoverable part): key → action
        Rectangle { // divider
            x: root.dev(root.padPx); width: grid.width
            y: valueRow.y + valueRow.height
            height: root.dev(1)
            color: Appearance.colors.colLokDivider
        }
        StyledText {
            x: root.dev(root.padPx)
            width: grid.width
            y: valueRow.y + valueRow.height + root.dev(1)
            height: root.dev(root.rowPx - 1)
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("C copy color  ⇧ rgb")
        }
    }
}
