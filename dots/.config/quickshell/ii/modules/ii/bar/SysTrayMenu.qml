pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    required property QsMenuHandle trayItemMenuHandle
    property string trayItemId: ""
    property real popupBackgroundMargin: 0

    signal menuClosed
    signal menuOpened(qsWindow: var) // Correct type is QsWindow, but QML does not like that

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitHeight: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitHeight, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }
    implicitWidth: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitWidth, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }

    function open() {
        root.visible = true;
        root.menuOpened(root);
    }

    function close() {
        root.visible = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.RightButton
        onPressed: event => {
            if ((event.button === Qt.BackButton || event.button === Qt.RightButton) && stackView.depth > 1)
                stackView.pop();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: Appearance.lok ? 3 : 4
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: Config.options.bar.vertical ? parent.verticalCenter : undefined
                top: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? undefined : parent.top
                bottom: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? parent.bottom : undefined
                margins: root.padding
            }

            // lok: same floating surface as every other popup/dialog
            color: Appearance.lok ? Appearance.colors.colLokDialog : Appearance.colors.colLayer0
            radius: Appearance.rounding.windowRounding
            border.width: Appearance.lok ? 0 : 1 // lok: LokFrame below (border drops sides at 1.333 scale)
            LokFrame { visible: Appearance.lok; z: 99; color: parent?.border?.color ?? Appearance.colors.colLokFrame }
            border.color: Appearance.colors.colLayer0Border
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: stackView.implicitWidth + popupBackground.padding * 2
            implicitHeight: stackView.implicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            StackView {
                id: stackView
                anchors {
                    fill: parent
                    margins: popupBackground.padding
                }
                pushEnter: NoAnim {}
                pushExit: NoAnim {}
                popEnter: NoAnim {}
                popExit: NoAnim {}

                implicitWidth: currentItem.implicitWidth
                implicitHeight: currentItem.implicitHeight

                initialItem: SubMenu {
                    handle: root.trayItemMenuHandle
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu
        required property QsMenuHandle handle
        property bool isSubMenu: false
        property bool shown: false
        opacity: shown ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle
        }

        spacing: 0

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible
            sourceComponent: RippleButton {
                id: backButton
                buttonRadius: popupBackground.radius - popupBackground.padding
                horizontalPadding: Appearance.lok ? 10 : 12
                implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                implicitHeight: Appearance.lok ? 28 : 36
                colBackgroundHover: Appearance.lok ? Appearance.colors.colLokDialogHover : Appearance.colors.colLayer1Hover
                colRipple: Appearance.lok ? Appearance.colors.colLokDivider : Appearance.colors.colLayer1Active

                downAction: () => stackView.pop()

                contentItem: RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: backButton.horizontalPadding
                        rightMargin: backButton.horizontalPadding
                    }
                    spacing: 8
                    MaterialSymbol {
                        iconSize: Appearance.lok ? 16 : 20
                        text: "chevron_left"
                        color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.m3colors.m3onBackground
                    }
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.lok ? Appearance.font.pixelSize.smallie : Appearance.font.pixelSize.small
                        text: Translation.tr("Back")
                    }
                }
            }
        }
        RippleButton {
            id: pinEntry
            buttonRadius: popupBackground.radius - popupBackground.padding
            horizontalPadding: Appearance.lok ? 10 : 12
            implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
            implicitHeight: Appearance.lok ? 28 : 36
            colBackgroundHover: Appearance.lok ? Appearance.colors.colLokDialogHover : Appearance.colors.colLayer1Hover
            colRipple: Appearance.lok ? Appearance.colors.colLokDivider : Appearance.colors.colLayer1Active
            Layout.topMargin: 0
            Layout.bottomMargin: 0
            Layout.fillWidth: true

            visible: root.trayItemId !== undefined && root.trayItemId.length > 0 && stackView.depth === 1
            releaseAction: () => TrayService.togglePin(root.trayItemId);

            contentItem: RowLayout {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: pinEntry.horizontalPadding
                    rightMargin: pinEntry.horizontalPadding
                }
                spacing: Appearance.lok ? 6 : 8

                MaterialSymbol {
                    // lok: sits in the 16 px check column so its label lines up with the entries
                    Layout.preferredWidth: Appearance.lok ? 16 : implicitWidth
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.lok ? 15 : 18
                    text: "push_pin"
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.m3colors.m3onBackground
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.lok ? Appearance.font.pixelSize.smallie : Appearance.font.pixelSize.small
                    text: TrayService.isPinned(root.trayItemId) ? Translation.tr("Unpin") : Translation.tr("Pin")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.lok ? "transparent" : Appearance.colors.colSubtext
            Layout.topMargin: Appearance.lok ? 3 : 4
            Layout.bottomMargin: Appearance.lok ? 3 : 4
            // lok: a hairline divider running edge to edge, like the dialog separators
            Layout.leftMargin: Appearance.lok ? -popupBackground.padding : 0
            Layout.rightMargin: Appearance.lok ? -popupBackground.padding : 0
            Rectangle {
                visible: Appearance.lok
                width: parent.width
                height: Appearance.sizes.hairline
                color: Appearance.colors.colLokDivider
            }
        }

        Repeater {
            id: menuEntriesRepeater
            property bool iconColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].icon.length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }
            model: menuOpener.children
            delegate: SysTrayMenuEntry {
                required property QsMenuEntry modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                menuEntry: modelData

                buttonRadius: popupBackground.radius - popupBackground.padding
                edgeBleed: popupBackground.padding

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent.createObject(null, {
                        handle: handle,
                        isSubMenu: true
                    }));
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
