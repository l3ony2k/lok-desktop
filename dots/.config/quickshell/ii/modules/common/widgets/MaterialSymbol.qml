import qs.modules.common
import QtQuick
import "lokIcons.js" as LokIcons

StyledText {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    property real truncatedFill: fill.toFixed(1) // Reduce memory consumption spikes from constant font remapping
    // lok style: draw the same Material Symbols name with Tabler glyphs ("Lok Icons" ligatures);
    // names the font does not know keep the Material font.
    readonly property bool useLokIcons: (Appearance?.lok ?? false) && LokIcons.has(root.text)
    renderType: Text.NativeRendering
    font {
        hintingPreference: Font.PreferNoHinting
        family: root.useLokIcons ? Appearance.font.family.iconLok : (Appearance?.font.family.iconMaterial ?? "Material Symbols Rounded")
        pixelSize: iconSize
        weight: root.useLokIcons ? Font.Normal : Font.Normal + (Font.DemiBold - Font.Normal) * truncatedFill
        variableAxes: root.useLokIcons ? ({}) : {
            "FILL": truncatedFill,
            // "wght": font.weight,
            // "GRAD": 0,
            "opsz": iconSize,
        }
    }

    // lok: Wi-Fi strength glyphs are partial arcs; draw the full symbol faintly
    // underneath so the level reads as "n of 3" like Material's outlined bars.
    readonly property bool lokWifiLevel: root.useLokIcons && /^(signal|network)_wifi_[0-3]_bar$/.test(root.text)
    Text {
        visible: root.lokWifiLevel
        z: -1
        anchors.fill: parent
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        renderType: root.renderType
        text: "wifi"
        font: root.font
        color: root.color
        opacity: 0.3
    }

    Behavior on fill { // Leaky leaky, no good
        enabled: !root.useLokIcons
        NumberAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}
