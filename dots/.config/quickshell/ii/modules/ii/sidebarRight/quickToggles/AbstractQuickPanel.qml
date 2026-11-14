import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    radius: Appearance.rounding.normal
    // lok: a card, same as the left sidebar's (layer 2 + divider frame); the only filled container
    color: Appearance.lok ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
    LokFrame { visible: Appearance.lok; z: 99; color: Appearance.colors.colLokDivider }

    signal openAudioOutputDialog()
    signal openAudioInputDialog()
    signal openBluetoothDialog()
    signal openNightLightDialog()
    signal openWifiDialog()
    signal openTailscaleDialog()
    signal openMihomoDialog()
    signal openSshLanDialog()
}
