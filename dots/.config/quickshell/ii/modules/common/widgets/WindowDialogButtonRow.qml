import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: Appearance.lok ? 8 : 4

    // These shouldn't be needed but it would be a terrible waste of space to follow the spec
    Layout.margins: Appearance.lok ? 0 : -8  // lok buttons are framed, so they align with the content edge
    Layout.topMargin: 0
}
