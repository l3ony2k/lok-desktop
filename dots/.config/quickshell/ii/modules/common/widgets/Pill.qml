import QtQuick
import qs.modules.common

Rectangle {
    radius: Appearance.lok ? 0 : Math.min(width, height) / 2
}
