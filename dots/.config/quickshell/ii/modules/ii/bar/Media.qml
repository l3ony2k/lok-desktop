import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    // The centre-clock layout hides this item when playback stops; do not leave a
    // stale hover state holding the preview open.
    onVisibleChanged: {
        if (!visible)
            GlobalStates.mediaControlsHovered = false;
    }

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton

        // Publish where the indicator is so MediaControls can align its left edge to it.
        function publishAnchorX() {
            const point = root.QsWindow?.mapFromItem(root, 0, 0);
            if (point)
                GlobalStates.mediaControlsAnchorX = point.x;
        }

        onEntered: {
            publishAnchorX();
            GlobalStates.mediaControlsHovered = true;
        }
        onExited: {
            GlobalStates.mediaControlsHovered = false;
        }

        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                // Click pins the popup open; only a click outside dismisses it.
                publishAnchorX();
                GlobalStates.mediaControlsOpen = true;
            }
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        MaterialSymbol { // lok: no glyph; the two-line block reads as media on its own
            visible: false
            Layout.alignment: Qt.AlignVCenter
            text: activePlayer?.isPlaying ? "pause" : "music_note"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colSubtext
        }

        ClippedFilledCircularProgress {
            id: mediaCircProg
            visible: !Appearance.lok
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            implicitSize: 20
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.hintingPreference: Font.PreferFullHinting
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        ColumnLayout { // lok: player app over the title
            visible: Appearance.lok && Config.options.bar.verbose
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.maximumWidth: 220
            spacing: -2
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: activePlayer?.identity || activePlayer?.desktopEntry || Translation.tr("Media")
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: root.cleanedTitle
            }
        }

        StyledText {
            visible: !Appearance.lok && Config.options.bar.verbose
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true // Ensures the text takes up available space
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Appearance.lok ? Text.AlignLeft : Text.AlignHCenter
            elide: Text.ElideRight // Truncates the text on the right
            color: Appearance.colors.colOnLayer1
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
            font.pixelSize: 14
        }

    }

}
