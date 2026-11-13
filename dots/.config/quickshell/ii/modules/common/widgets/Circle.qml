import qs.modules.common
import QtQuick

Rectangle {
    property double diameter

    implicitWidth: diameter
    implicitHeight: diameter
    radius: (Appearance?.lok ?? false) ? 0 : diameter / 2
}
