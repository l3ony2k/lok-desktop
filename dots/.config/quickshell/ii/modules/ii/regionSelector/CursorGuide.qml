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

    readonly property int physWidth: Math.max(1, imgPreview.implicitWidth)
    readonly property int physHeight: Math.max(1, imgPreview.implicitHeight)
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
            pixelSampler.loadImage(screenshotUrl);
        }
    }
    onPhysXChanged: pixelSampler.requestPaint()
    onPhysYChanged: pixelSampler.requestPaint()

    Canvas {
        id: pixelSampler
        width: 1
        height: 1
        renderTarget: Canvas.Image
        onImageLoaded: requestPaint()
        onPaint: {
            if (root.screenshotUrl === "" || !isImageLoaded(root.screenshotUrl)) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 1, 1);
            ctx.drawImage(root.screenshotUrl, root.physX, root.physY, 1, 1, 0, 0, 1, 1);
            const data = ctx.getImageData(0, 0, 1, 1).data;
            root.sampledR = data[0];
            root.sampledG = data[1];
            root.sampledB = data[2];
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

                Image {
                    id: imgPreview
                    source: root.screenshotUrl
                    smooth: false
                    mipmap: false
                    cache: false
                    asynchronous: false
                    width: implicitWidth * (root.zoomScale / root.monitorScale)
                    height: implicitHeight * (root.zoomScale / root.monitorScale)
                    x: loupeInner.width / 2 - (root.physX + 0.5) * (root.zoomScale / root.monitorScale)
                    y: loupeInner.height / 2 - (root.physY + 0.5) * (root.zoomScale / root.monitorScale)
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
