import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property string formattedDate: Qt.locale("en_US").toString(DateTime.clock.date, "yyyy-MM-dd ddd") // ISO date + short English weekday: 2026-11-20 Fri
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property string todosSection: Config.options.sidebar.todo.enable ? getUpcomingTodos() : ""
    readonly property var pendingTodos: Todo.list.filter(item => !item.done)

    function getUpcomingTodos() {
        const unfinishedTodos = Todo.list.filter(function (item) {
            return !item.done;
        });
        if (unfinishedTodos.length === 0) {
            return Translation.tr("No pending tasks");
        }

        // Limit to first 5 todos to keep popup manageable
        const limitedTodos = unfinishedTodos.slice(0, 5);
        let todoText = limitedTodos.map(function (item, index) {
            return `  ${index + 1}. ${item.content}`;
        }).join('\n');

        if (unfinishedTodos.length > 5) {
            todoText += `\n  ${Translation.tr("... and %1 more").arg(unfinishedTodos.length - 5)}`;
        }

        return todoText;
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }
    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    // lok (2026-11-20): date title over cards (time, uptime, to-do), same family as the resources popup
    Loader {
        anchors.centerIn: parent
        sourceComponent: Appearance.lok ? root.lokContent : root.classicContent
    }

    property Component lokContent: Component {
        ColumnLayout {
            spacing: 8
            StyledPopupHeaderRow {
                icon: "calendar_month"
                label: root.formattedDate
            }
            GridLayout {
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true
                Layout.fillWidth: true

                LokPopupCard {
                    symbol: "schedule"
                    title: Translation.tr("Time")
                    value: root.formattedTime
                    detail: Translation.tr("Week %1 · day %2").arg(root.isoWeek(DateTime.clock.date)).arg(root.dayOfYear(DateTime.clock.date))
                }
                LokPopupCard {
                    symbol: "timelapse"
                    title: Translation.tr("Uptime")
                    value: root.formattedUptime.replace(/,/g, "")
                    detail: Translation.tr("since boot")
                }
                LokPopupCard {
                    visible: Config.options.sidebar.todo.enable
                    Layout.columnSpan: 2
                    wide: true
                    symbol: "checklist"
                    title: Translation.tr("To do")
                    value: root.pendingTodos.length > 0 ? `${root.pendingTodos.length}` : ""
                    detail: root.pendingTodos.length > 0 ? Translation.tr("pending") : Translation.tr("all done")

                    Repeater {
                        model: root.pendingTodos.slice(0, 5)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.maximumWidth: 260
                            spacing: 8
                            Rectangle { // hollow square, like an unchecked box
                                implicitWidth: 6
                                implicitHeight: 6
                                color: "transparent"
                                LokFrame { color: Appearance.colors.colSubtext }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.content
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                    StyledText {
                        visible: root.pendingTodos.length > 5
                        Layout.leftMargin: 14
                        text: Translation.tr("+ %1 more").arg(root.pendingTodos.length - 5)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    property Component classicContent: Component {
        ColumnLayout {
            spacing: 4

            StyledPopupHeaderRow {
                icon: "calendar_month"
                label: root.formattedDate
            }

            StyledPopupValueRow {
                icon: "timelapse"
                label: Translation.tr("Uptime:")
                value: root.formattedUptime
            }

            Column {
                visible: Config.options.sidebar.todo.enable
                spacing: 0
                Layout.fillWidth: true

                StyledPopupValueRow {
                    icon: "checklist"
                    label: Translation.tr("To Do:")
                    value: ""
                }

                StyledText {
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colOnSurfaceVariant
                    text: root.todosSection
                }
            }
        }
    }
}
