pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common

Item {
    id: root

    signal clicked(event: var)
    property alias iconText: fabWidget.iconText
    default property alias fabData: fabWidget.data
    property bool enableShadow: true

    anchors {
        verticalCenter: parent.verticalCenter
    }
    implicitWidth: fabWidget.implicitWidth
    implicitHeight: fabWidget.implicitHeight
    Loader {
        active: root.enableShadow
        anchors.fill: parent
        z: Appearance.lok ? 1 : 0 // lok: the frame sits on top of the fill, not under it
        sourceComponent: StyledRectangularShadow {
            target: fabWidget
            radius: fabWidget.buttonRadius
        }
    }
    FloatingActionButton {
        id: fabWidget
        onClicked: e => root.clicked(e)
        baseSize: Appearance.lok ? 56 : 48 // lok: same height as the toolbar it pairs with
        colBackground: Appearance.colors.colTertiaryContainer
        colBackgroundHover: Appearance.colors.colTertiaryContainerHover
        colRipple: Appearance.colors.colTertiaryContainerActive
        colOnBackground: Appearance.colors.colOnTertiaryContainer
    }
}