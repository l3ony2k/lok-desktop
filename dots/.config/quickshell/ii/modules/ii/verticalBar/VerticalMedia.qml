import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.Mpris

import qs.modules.ii.bar as Bar

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitHeight: Appearance.lok ? lokGlyph.implicitHeight : mediaCircProg.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    // lok: same interaction as the horizontal bar's media item (Bar/Media.qml): hover previews the
    // media popup next to this glyph, a click pins it
    function publishAnchorY() {
        const point = root.QsWindow?.mapFromItem(root, 0, 0);
        if (point)
            GlobalStates.mediaControlsAnchorY = point.y;
    }
    onEntered: {
        if (!Appearance.lok) return;
        publishAnchorY();
        GlobalStates.mediaControlsHovered = true;
    }
    onExited: {
        if (Appearance.lok)
            GlobalStates.mediaControlsHovered = false;
    }
    onVisibleChanged: {
        if (!visible && Appearance.lok)
            GlobalStates.mediaControlsHovered = false;
    }

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    onPressed: (event) => {
        if (event.button === Qt.MiddleButton) {
            activePlayer.togglePlaying();
        } else if (event.button === Qt.BackButton) {
            activePlayer.previous();
        } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
            activePlayer.next();
        } else if (event.button === Qt.LeftButton) {
            if (Appearance.lok) {
                publishAnchorY();
                GlobalStates.mediaControlsOpen = true; // only a click outside dismisses it
            } else {
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
        }
    }

    MaterialSymbol { // lok: the glyph alone, bright while playing
        id: lokGlyph
        visible: Appearance.lok
        anchors.centerIn: parent
        text: "music_note"
        iconSize: Appearance.font.pixelSize.larger
        color: root.activePlayer?.isPlaying ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
    }

    ClippedFilledCircularProgress {
        id: mediaCircProg
        visible: !Appearance.lok
        anchors.centerIn: parent
        implicitSize: 20

        lineWidth: Appearance.rounding.unsharpen
        value: activePlayer?.position / activePlayer?.length
        colPrimary: Appearance.colors.colOnSecondaryContainer
        enableAnimation: false

        Item {
            anchors.centerIn: parent
            width: mediaCircProg.implicitSize
            height: mediaCircProg.implicitSize
            
            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: activePlayer?.isPlaying ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    Bar.StyledPopup {
        hoverTarget: root
        active: (GlobalStates.mediaControlsOpen || Appearance.lok) ? false : root.containsMouse

        Column {
            anchors.centerIn: parent
            spacing: 4

            Bar.StyledPopupHeaderRow {
                icon: "music_note"
                label: Translation.tr("Media")
            }

            StyledText {
                color: Appearance.colors.colOnSurfaceVariant
                text: `${cleanedTitle}${activePlayer?.trackArtist ? '\n' + activePlayer.trackArtist : ''}`
            }
        }
    }

}
