import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    borderWidth: (Appearance.lok && isToday == 1) ? 1 : 0 // lok: shared selected style
    borderColor: Appearance.colors.colSelectedEdge
    buttonRadius: Appearance.rounding.small
    
    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (Appearance.lok && bold && isToday != 1) ? Appearance.colors.colSubtext : (isToday == 1) ? Appearance.colors.colOnPrimary : 
            (isToday == 0) ? Appearance.colors.colOnLayer1 : 
            (Appearance.lok ? Appearance.colors.colLokMuted : Appearance.colors.colOutlineVariant)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}

