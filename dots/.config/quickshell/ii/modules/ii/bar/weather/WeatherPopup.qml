import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

StyledPopup {
    id: root

    // lok (2026-11-20): city title, a "Now" card, then metric cards from the shared LokPopupCard.
    // Material keeps the original layout below.
    Loader {
        anchors.centerIn: parent
        sourceComponent: Appearance.lok ? root.lokContent : root.classicContent
    }

    property Component lokContent: Component {
        ColumnLayout {
            spacing: 8
            StyledPopupHeaderRow {
                icon: "location_on"
                label: Weather.data.city
            }
            GridLayout {
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true
                Layout.fillWidth: true

                LokPopupCard {
                    Layout.columnSpan: 2
                    symbol: "thermostat"
                    title: Translation.tr("Now")
                    value: Weather.data.temp
                    detail: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                }
                LokPopupCard { symbol: "wb_sunny"; title: Translation.tr("UV index"); value: Weather.data.uv }
                LokPopupCard { symbol: "air"; title: Translation.tr("Wind"); value: Weather.data.wind; detail: Weather.data.windDir }
                LokPopupCard { symbol: "rainy_light"; title: Translation.tr("Precipitation"); value: Weather.data.precip }
                LokPopupCard { symbol: "humidity_low"; title: Translation.tr("Humidity"); value: Weather.data.humidity }
                LokPopupCard { symbol: "visibility"; title: Translation.tr("Visibility"); value: Weather.data.visib }
                LokPopupCard { symbol: "readiness_score"; title: Translation.tr("Pressure"); value: Weather.data.press }
                LokPopupCard { symbol: "wb_twilight"; title: Translation.tr("Sunrise"); value: Weather.data.sunrise }
                LokPopupCard { symbol: "bedtime"; title: Translation.tr("Sunset"); value: Weather.data.sunset }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Updated %1").arg(Weather.data.lastRefresh)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }

    property Component classicContent: Component {
        ColumnLayout {
            id: columnLayout
            implicitWidth: Math.max(header.implicitWidth, gridLayout.implicitWidth)
            implicitHeight: gridLayout.implicitHeight
            spacing: 5

            // Header
            ColumnLayout {
                id: header
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    MaterialSymbol {
                        fill: 0
                        font.weight: Font.Medium
                        text: "location_on"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.lok ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        text: Weather.data.city
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        color: Appearance.lok ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant // lok: title brighter than the cards
                    }
                }
                StyledText {
                    id: temp
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    text: Weather.data.temp + " • " + Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                }
            }

            // Metrics grid
            GridLayout {
                id: gridLayout
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true

                WeatherCard {
                    title: Translation.tr("UV Index")
                    symbol: "wb_sunny"
                    value: Weather.data.uv
                }
                WeatherCard {
                    title: Translation.tr("Wind")
                    symbol: "air"
                    value: `(${Weather.data.windDir}) ${Weather.data.wind}`
                }
                WeatherCard {
                    title: Translation.tr("Precipitation")
                    symbol: "rainy_light"
                    value: Weather.data.precip
                }
                WeatherCard {
                    title: Translation.tr("Humidity")
                    symbol: "humidity_low"
                    value: Weather.data.humidity
                }
                WeatherCard {
                    title: Translation.tr("Visibility")
                    symbol: "visibility"
                    value: Weather.data.visib
                }
                WeatherCard {
                    title: Translation.tr("Pressure")
                    symbol: "readiness_score"
                    value: Weather.data.press
                }
                WeatherCard {
                    title: Translation.tr("Sunrise")
                    symbol: "wb_twilight"
                    value: Weather.data.sunrise
                }
                WeatherCard {
                    title: Translation.tr("Sunset")
                    symbol: "bedtime"
                    value: Weather.data.sunset
                }
            }

            // Footer: last refresh
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.smaller
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
