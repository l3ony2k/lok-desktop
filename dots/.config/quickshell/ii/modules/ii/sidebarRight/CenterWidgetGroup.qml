import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    // lok: a card, same as the left sidebar's (layer 2 + divider frame); the only filled container
    color: Appearance.lok ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
    LokFrame { visible: Appearance.lok; z: 99; color: Appearance.colors.colLokDivider }

    NotificationList {
        anchors.fill: parent
        anchors.margins: 5
    }
}
