pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

RippleButton {
    id: root
    required property QsMenuEntry menuEntry
    property bool forceIconColumn: false
    property bool forceSpecialInteractionColumn: false
    readonly property bool hasIcon: menuEntry.icon.length > 0
    readonly property bool hasSpecialInteraction: menuEntry.buttonType !== QsMenuButtonType.None

    signal dismiss()
    signal openSubmenu(handle: QsMenuHandle)

    // lok: separators run edge to edge through the menu padding
    property real edgeBleed: 0

    colBackground: menuEntry.isSeparator ? (Appearance.lok ? "transparent" : Appearance.m3colors.m3outlineVariant) : ColorUtils.transparentize(Appearance.colors.colLayer0)
    colBackgroundHover: Appearance.lok ? Appearance.colors.colLokDialogHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.lok ? Appearance.colors.colLokDivider : Appearance.colors.colLayer1Active
    enabled: !menuEntry.isSeparator
    opacity: 1

    // lok: compact rows (28 px) and a 10 px inset
    horizontalPadding: Appearance.lok ? 10 : 12
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: menuEntry.isSeparator ? 1 : (Appearance.lok ? 28 : 36)
    Layout.topMargin: menuEntry.isSeparator ? (Appearance.lok ? 3 : 4) : 0
    Layout.bottomMargin: menuEntry.isSeparator ? (Appearance.lok ? 3 : 4) : 0
    Layout.leftMargin: menuEntry.isSeparator && Appearance.lok ? -edgeBleed : 0
    Layout.rightMargin: menuEntry.isSeparator && Appearance.lok ? -edgeBleed : 0
    Layout.fillWidth: true

    // lok: the line itself is a device-px hairline inside the 1 px layout slot
    Rectangle {
        visible: Appearance.lok && root.menuEntry.isSeparator
        width: parent.width
        height: Appearance.sizes.hairline
        color: Appearance.colors.colLokDivider
    }

    Component.onCompleted: {
        if (menuEntry.isSeparator) {
            root.buttonColor = root.colBackground;
        }
    }

    releaseAction: () => { 
        if (menuEntry.hasChildren) {
            root.openSubmenu(root.menuEntry);
            return;
        }
        menuEntry.triggered();
        root.dismiss(); 
    }
    altAction: (event) => { // Not hog right-click
        event.accepted = false;
    }

    contentItem: RowLayout {
        id: contentItem
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: Appearance.lok ? 6 : 8
        visible: !root.menuEntry.isSeparator

        // Interaction: checkbox or radio button
        Item {
            visible: root.hasSpecialInteraction || root.forceSpecialInteractionColumn
            implicitWidth: Appearance.lok ? 16 : 20
            implicitHeight: Appearance.lok ? 16 : 20

            Loader {
                anchors.fill: parent
                active: root.menuEntry.buttonType === QsMenuButtonType.RadioButton

                sourceComponent: StyledRadioButton {
                    enabled: false
                    padding: 0
                    checked: root.menuEntry.checkState === Qt.Checked
                }
            }

            Loader {
                anchors.fill: parent
                active: root.menuEntry.buttonType === QsMenuButtonType.CheckBox && root.menuEntry.checkState !== Qt.Unchecked

                sourceComponent: MaterialSymbol {
                    text: root.menuEntry.checkState === Qt.PartiallyChecked ? "check_indeterminate_small" : "check"
                    iconSize: Appearance.lok ? 16 : 20
                }
            }
        }

        // Button icon
        Item {
            visible: root.hasIcon || root.forceIconColumn
            implicitWidth: Appearance.lok ? 16 : 20
            implicitHeight: Appearance.lok ? 16 : 20

            Loader {
                anchors.centerIn: parent
                active: root.menuEntry.icon.length > 0
                sourceComponent: IconImage {
                    asynchronous: true
                    source: root.menuEntry.icon
                    implicitSize: Appearance.lok ? 16 : 20
                    mipmap: true
                }
            }
        }

        StyledText {
            id: label
            text: root.menuEntry.text
            font.pixelSize: Appearance.font.pixelSize.smallie
            Layout.fillWidth: true
        }

        Loader {
            active: root.menuEntry.hasChildren

            sourceComponent: MaterialSymbol {
                text: "chevron_right"
                iconSize: Appearance.lok ? 16 : 20
                color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.m3colors.m3onBackground
            }
        }
    }
}
