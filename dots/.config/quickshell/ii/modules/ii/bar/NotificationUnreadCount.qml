import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    text: Notifications.silent ? "notifications_paused" : "notifications"
    iconSize: Appearance.font.pixelSize.larger
    color: rightSidebarButton.colText

    Rectangle {
        id: notifPing
        visible: !Notifications.silent && Notifications.unread > 0 && !Appearance.lok
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colOnLayer0
        z: 1

        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) : 8
        implicitWidth: implicitHeight

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colLayer0
            text: Notifications.unread
        }
    }

    // lok: no white block on the bell. A cut-out in the colour behind the button (bar, or the
    // button's fill while the sidebar is open) separates the mark from the bell; inside it sits
    // either a 5 px square or the count as bright text.
    Rectangle {
        id: lokCutout
        visible: Appearance.lok && !Notifications.silent && Notifications.unread > 0
        z: 1
        readonly property real pad: 1.5
        color: rightSidebarButton.toggled ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? -3 : -1
            topMargin: root.showUnreadCount ? 0 : 2
        }
        implicitWidth: (root.showUnreadCount ? lokCount.implicitWidth : 5) + pad * 2
        implicitHeight: (root.showUnreadCount ? lokCount.implicitHeight - 4 : 5) + pad * 2

        Rectangle {
            visible: !root.showUnreadCount
            anchors.centerIn: parent
            width: 5
            height: 5
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            id: lokCount
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            text: Notifications.unread > 9 ? "9+" : Notifications.unread
        }
    }
}
