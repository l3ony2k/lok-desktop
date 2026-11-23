import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    property var action
    property var selectionMode

    property string screenshotPath: ""
    property bool screenshotReady: false
    property real mouseX: 0
    property real mouseY: 0
    property real monitorScale: 1.0
    property bool shiftHeld: false
    property real zoomScale: 10.0

    signal colorPicked(string colorText)

    property int sampledR: 0
    property int sampledG: 0
    property int sampledB: 0

    readonly property int physWidth: Math.max(1, Math.round(root.parent ? root.parent.width * root.monitorScale : 2560))
    readonly property int physHeight: Math.max(1, Math.round(root.parent ? root.parent.height * root.monitorScale : 1600))
    readonly property int physX: Math.max(0, Math.min(physWidth - 1, Math.floor(root.mouseX * root.monitorScale)))
    readonly property int physY: Math.max(0, Math.min(physHeight - 1, Math.floor(root.mouseY * root.monitorScale)))

    function toHex(n) {
        const s = Math.max(0, Math.min(255, n)).toString(16).toUpperCase();
        return s.length < 2 ? "0" + s : s;
    }

    readonly property string hexText: `#${toHex(sampledR)}${toHex(sampledG)}${toHex(sampledB)}`
    readonly property string rgbText: `rgb(${sampledR}, ${sampledG}, ${sampledB})`
    readonly property string displayColorText: root.shiftHeld ? root.rgbText : root.hexText
    readonly property color sampledColor: Qt.rgba(sampledR / 255, sampledG / 255, sampledB / 255, 1)

    function pickColor() {
        root.colorPicked(root.displayColorText);
    }

    readonly property string screenshotUrl: root.screenshotReady && root.screenshotPath !== "" ? `file://${root.screenshotPath}` : ""

    onScreenshotUrlChanged: {
        if (screenshotUrl !== "") {
            loupeCanvas.unloadImage(screenshotUrl);
            loupeCanvas.loadImage(screenshotUrl);
        }
    }
    onPhysXChanged: loupeCanvas.requestPaint()
    onPhysYChanged: loupeCanvas.requestPaint()
    onZoomScaleChanged: loupeCanvas.requestPaint()

    Component.onDestruction: {
        if (screenshotUrl !== "") {
            loupeCanvas.unloadImage(screenshotUrl);
        }
    }

    readonly property real loupeInnerSize: 132
    readonly property real colorBorderWidth: 4
    readonly property real pixelBoxSize: Math.max(2, root.zoomScale / root.monitorScale)

    implicitWidth: Math.max(loupeFrame.width, labelBox.width)
    implicitHeight: loupeFrame.height + 4 + labelBox.height

    // Outer hairline + sampled color square border (lok sharp style)
    Rectangle {
        id: loupeFrame
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.loupeInnerSize + root.colorBorderWidth * 2 + 2
        height: root.loupeInnerSize + root.colorBorderWidth * 2 + 2
        radius: 0
        color: Qt.rgba(0, 0, 0, 0.45)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 0
            color: root.sampledColor

            Rectangle {
                id: loupeInner
                anchors.fill: parent
                anchors.margins: root.colorBorderWidth
                radius: 0
                color: "#141414"
                clip: true

                Canvas {
                    id: loupeCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    onImageLoaded: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (root.screenshotUrl === "" || !isImageLoaded(root.screenshotUrl)) return;

                        const pxRatio = root.zoomScale / root.monitorScale;
                        const srcSpan = width / pxRatio;
                        let sx = (root.physX + 0.5) - srcSpan * 0.5;
                        let sy = (root.physY + 0.5) - srcSpan * 0.5;
                        let sw = srcSpan;
                        let sh = srcSpan;

                        let dx = 0;
                        let dy = 0;
                        let dw = width;
                        let dh = height;

                        if (sx < 0) {
                            const cut = -sx;
                            dx += cut * pxRatio;
                            dw -= cut * pxRatio;
                            sw -= cut;
                            sx = 0;
                        }
                        if (sy < 0) {
                            const cut = -sy;
                            dy += cut * pxRatio;
                            dh -= cut * pxRatio;
                            sh -= cut;
                            sy = 0;
                        }
                        if (sx + sw > root.physWidth) {
                            const cut = (sx + sw) - root.physWidth;
                            dw -= cut * pxRatio;
                            sw -= cut;
                        }
                        if (sy + sh > root.physHeight) {
                            const cut = (sy + sh) - root.physHeight;
                            dh -= cut * pxRatio;
                            sh -= cut;
                        }

                        ctx.imageSmoothingEnabled = false;
                        if (sw > 0 && sh > 0 && dw > 0 && dh > 0) {
                            ctx.drawImage(root.screenshotUrl, sx, sy, sw, sh, dx, dy, dw, dh);
                        }

                        const data = ctx.getImageData(Math.floor(width / 2), Math.floor(height / 2), 1, 1).data;
                        root.sampledR = data[0];
                        root.sampledG = data[1];
                        root.sampledB = data[2];
                    }
                }

                // Center 1-pixel sampling box (black outer + white inner 1px strokes)
                Rectangle {
                    anchors.centerIn: parent
                    width: root.pixelBoxSize + 4
                    height: root.pixelBoxSize + 4
                    radius: 0
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.9)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 0
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.95)
                    }
                }
            }
        }
    }

    // Bottom color value box (lok sharp style)
    Rectangle {
        id: labelBox
        anchors.top: loupeFrame.bottom
        anchors.topMargin: 4
        anchors.left: loupeFrame.left
        width: Math.max(loupeFrame.width, labelText.implicitWidth + 14)
        height: 26
        radius: 0
        color: Qt.rgba(0, 0, 0, 0.85)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)

        StyledText {
            id: labelText
            anchors.centerIn: parent
            font.family: Appearance.font.family.monospace
            font.pixelSize: 13
            color: "#ffffff"
            text: root.displayColorText
        }
    }
}
