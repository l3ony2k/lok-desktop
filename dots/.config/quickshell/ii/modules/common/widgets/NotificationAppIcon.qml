import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

MaterialShape { // App icon
    id: root
    property var appIcon: ""
    property string appName: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool isUrgent: urgency === NotificationUrgency.Critical
    property var image: ""
    readonly property string safeAppIcon: root.appIcon ?? ""
    readonly property string safeImage: root.image ?? ""
    // Apps such as Brave send the app icon as a file URL, which iconPath() would treat as a theme
    // icon name and render as "image-missing". Use file paths directly.
    readonly property string appIconSource: root.safeAppIcon.startsWith("file://") ? root.safeAppIcon
        : root.safeAppIcon.startsWith("/") ? "file://" + root.safeAppIcon
        : Quickshell.iconPath(root.safeAppIcon, "image-missing")
    readonly property bool isVinputGenericIcon: root.appName === "fcitx5-vinput" &&
        (safeAppIcon === "" || safeAppIcon === "dialog-information" || safeAppIcon === "dialog-error")
    readonly property bool useMaterialSymbol: safeImage === "" && (safeAppIcon === "" || root.isVinputGenericIcon)
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    property real smallAppIconScale: 0.49
    property real materialIconSize: implicitSize * materialIconScale
    property real appIconSize: implicitSize * appIconScale
    property real smallAppIconSize: implicitSize * smallAppIconScale

    implicitSize: 38 * scale
    property list<var> urgentShapes: [
        MaterialShape.Shape.VerySunny,
        MaterialShape.Shape.SoftBurst,
    ]
    shape: isUrgent ? urgentShapes[Math.floor(Math.random() * urgentShapes.length)] : MaterialShape.Shape.Circle

    // lok: a plain glyph; only an urgent notification keeps a shape behind its icon
    color: isUrgent ? Appearance.colors.colPrimaryContainer : Appearance.lok ? "transparent" : Appearance.colors.colSecondaryContainer
    Loader {
        id: materialSymbolLoader
        active: root.useMaterialSymbol
        anchors.fill: parent
        sourceComponent: MaterialSymbol {
            text: {
                if (root.isVinputGenericIcon) {
                    return root.appIcon === "dialog-error" ? "mic_off" : "mic"
                }
                const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("")
                const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary)
                return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                    "priority_high" : guessedIcon
            }
            anchors.fill: parent
            color: isUrgent ? Appearance.colors.colOnPrimaryContainer : Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnSecondaryContainer
            iconSize: root.materialIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Loader {
        id: appIconLoader
        active: root.safeImage === "" && root.safeAppIcon !== "" && !root.isVinputGenericIcon
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: root.appIconSource
        }
    }
    Loader {
        id: notifImageLoader
        active: root.safeImage !== ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            StyledImage {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width

                source: root.image
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true

                layer.enabled: !Appearance.lok // lok: square, no mask (the texture blurred hairlines)
                clip: Appearance.lok // stands in for the mask's clipping
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.size
                        height: notifImage.size
                        radius: Appearance.rounding.full
                    }
                }
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.safeAppIcon !== ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: root.appIconSource
                }
            }
        }
    }
}