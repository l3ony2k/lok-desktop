import qs.modules.common
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls

/**
 * Material 3 styled TextField (filled style)
 * https://m3.material.io/components/text-fields/overview
 * Note: We don't use NativeRendering because it makes the small placeholder text look weird
 */
TextField {
    id: root
    Material.theme: Material.System
    Material.accent: Appearance.m3colors.m3primary
    Material.primary: Appearance.m3colors.m3primary
    Material.background: Appearance.m3colors.m3surface
    Material.foreground: Appearance.m3colors.m3onSurface
    Material.containerStyle: Material.Outlined
    renderType: Text.QtRendering

    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
    selectionColor: Appearance.colors.colSecondaryContainer
    // lok: the Material outlined field (rounded box, label floating into a notch in the
    // border) is replaced by a square inset field with an in-field placeholder
    placeholderTextColor: Appearance.lok ? "transparent" : Appearance.m3colors.m3outline
    property Item lokBackground: Rectangle {
        implicitHeight: 40
        color: Appearance.colors.colLayer1
        border.width: 0 // lok: LokFrame below (border drops sides at 1.333 scale)
        LokFrame { visible: true; z: 99; color: parent.border.color }
        border.color: root.activeFocus ? Appearance.colors.colSelectedEdge : Appearance.colors.colLokDivider
    }
    Binding on background {
        when: Appearance.lok
        value: root.lokBackground
    }
    Binding on verticalAlignment { when: Appearance.lok; value: TextInput.AlignVCenter }
    // Material reserves topInset for its floating label when clipped, which pushes the
    // box down while the text stays put; lok has no floating label
    Binding on topInset { when: Appearance.lok; value: 0 }
    Binding on bottomInset { when: Appearance.lok; value: 0 }
    Binding on topPadding { when: Appearance.lok; value: 10 }
    Binding on bottomPadding { when: Appearance.lok; value: 10 }
    Binding on leftPadding { when: Appearance.lok; value: 12 }
    Binding on rightPadding { when: Appearance.lok; value: 12 }
    clip: true

    font {
        family: Appearance.font.family.main
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
    wrapMode: TextEdit.Wrap

    Text { // lok placeholder: inside the field, gone once there is input
        visible: Appearance.lok && root.text.length === 0 && root.preeditText.length === 0
        x: root.leftPadding
        width: root.width - root.leftPadding - root.rightPadding
        // same box and alignment as the typed text, so placeholder and input sit on one line
        y: root.topPadding
        height: root.height - root.topPadding - root.bottomPadding
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.placeholderText
        color: Appearance.colors.colSubtext
        font: root.font
        renderType: Text.QtRendering
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
    }
}
