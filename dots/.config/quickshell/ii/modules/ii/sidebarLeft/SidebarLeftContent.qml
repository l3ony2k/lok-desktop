import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    // lok: 9 logical = 12 device px at 1.333, so every inset and gap between cards is a whole pixel (same on both sidebars)
    property int sidebarPadding: Appearance.lok ? 9 : 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool dashboardEnabled: Config.options.sidebar.dashboard?.enable ?? false
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool animeCloset: Config.options.policies.weeb === 2
    property var tabButtonList: [
        ...(root.dashboardEnabled ? [{"icon": "monitoring", "name": Translation.tr("Dashboard")}] : []),
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"icon": "bookmark_heart", "name": Translation.tr("Anime")}] : [])
    ]
    property int tabCount: swipeView.count
    readonly property bool placeholderNeeded: root.tabButtonList.length === 0
        || (!root.dashboardEnabled && !root.aiChatEnabled && !root.translatorEnabled && root.animeCloset)

    // Pages are created once and kept. contentChildren used to call createObject() inside its
    // binding, so every re-evaluation (e.g. tabButtonList changing when the translation loads at
    // startup) built a new set of pages and left the old ones alive, parentless, until garbage
    // collection: their bindings kept running against torn-down internals ("Cannot find member
    // data" from Dashboard's cards) and their timers kept polling.
    property var pageCache: ({})
    function page(key: string, comp: Component): var {
        if (!pageCache[key])
            pageCache[key] = comp.createObject(null);
        return pageCache[key];
    }
    function dropPage(key: string): void {
        if (pageCache[key]) {
            pageCache[key].destroy();
            delete pageCache[key];
        }
    }
    onDashboardEnabledChanged: if (!dashboardEnabled) dropPage("dashboard")
    onAiChatEnabledChanged: if (!aiChatEnabled) dropPage("aiChat")
    onTranslatorEnabledChanged: if (!translatorEnabled) dropPage("translator")
    onAnimeEnabledChanged: if (!animeEnabled) dropPage("anime")
    onPlaceholderNeededChanged: if (!placeholderNeeded) dropPage("placeholder")

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            visible: tabButtonList.length > (Appearance.lok ? 1 : 0) // lok: a single tab needs no tab bar
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                currentIndex: swipeView.currentIndex
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            // lok: no extra layer between the sidebar and the pages' own cards
            color: Appearance.lok ? "transparent" : Appearance.colors.colLayer1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: tabBar.currentIndex

                clip: true
                layer.enabled: !Appearance.lok // lok: square, no mask (the texture blurred hairlines)
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: [
                    ...(root.dashboardEnabled ? [root.page("dashboard", dashboard)] : []),
                    ...(root.aiChatEnabled ? [root.page("aiChat", aiChat)] : []),
                    ...(root.translatorEnabled ? [root.page("translator", translator)] : []),
                    ...(root.placeholderNeeded ? [root.page("placeholder", placeholder)] : []),
                    ...(root.animeEnabled ? [root.page("anime", anime)] : []),
                ]
            }
        }

        Component {
            id: dashboard
            Dashboard {}
        }
        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: anime
            Anime {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: root.animeCloset ? Translation.tr("Nothing") : Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}