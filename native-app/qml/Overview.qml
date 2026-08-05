import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Theme is a pragma-Singleton declared in qmldir in this same directory --
// QML resolves it automatically for files in this directory, no explicit
// module import needed.

ApplicationWindow {
    id: root
    visible: true
    // 1200x1920 is the 10.1" Touch Display 2's native portrait
    // resolution. Dimensions swap for landscape per config.yaml's
    // display.orientation -- pure software decision, not tied to how
    // any particular physical panel is built. Runs windowed at this
    // size on a dev machine; full screen on the Pi.
    width: appConfig.isPortrait ? 1200 : 1920
    height: appConfig.isPortrait ? 1920 : 1200
    title: "HA Wall Kiosk"
    color: Theme.base

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Home"
                font.family: Theme.fontHead
                font.pixelSize: 40
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: haClient.connected ? Theme.on : Theme.textFaint
            }

            Text {
                text: haClient.connected ? "connected" : "connecting…"
                font.family: Theme.fontMono
                font.pixelSize: 14
                color: Theme.textDim
                leftPadding: 8
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GridLayout {
                width: root.width - 64
                // Landscape gets an extra column -- the point of making
                // orientation a config value instead of a hardcoded
                // portrait assumption is that layouts actually adapt,
                // not just the window's outer dimensions.
                columns: appConfig.isPortrait ? 2 : 3
                columnSpacing: 16
                rowSpacing: 16

                Repeater {
                    model: haClient.areas

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: Theme.radiusCard
                        color: Theme.baseRaised
                        border.color: Theme.hairline
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 6

                            Text {
                                text: modelData.name
                                font.family: Theme.fontHead
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                text: modelData.entities.length + " entities"
                                font.family: Theme.fontBody
                                font.pixelSize: 13
                                color: Theme.textDim
                            }

                            Repeater {
                                model: modelData.entities.slice(0, 4)

                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.name
                                        font.family: Theme.fontBody
                                        font.pixelSize: 13
                                        color: Theme.textFaint
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.state
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                        color: modelData.state === "on" ? Theme.on : Theme.textFaint
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
