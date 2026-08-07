import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Theme is a pragma-Singleton declared in qmldir in this same directory --
// QML resolves it automatically for files in this directory, no explicit
// module import needed.

// Ambient Mode, ported from the PWA's proven design (pwa-app/index.html,
// docs/UI_MODES_SPEC.md "Ambient Mode v2") rather than the plain area grid
// this file started as -- per NATIVE_APP_SPEC.md "Port from the PWA, not
// the original mockup." This is a bounded first pass, not the full port:
// clock/date + per-room status cards with tap-to-toggle, the same "one
// quick-action per room" behavior Ambient Mode v1 shipped with in the PWA.
//
// Card anatomy (2026-08-06) updated to match the PWA's current
// Loxone-matched room card: room label, a brightness word (Off/Dim/On/
// Bright) as the primary text, the representative light's own name as the
// sub-text, and a vertical pill on the right showing brightness as a fill
// height -- same visual language as pwa-app/index.html's lightCard().
// Two things the PWA's card has that this one deliberately doesn't yet:
// a lightbulb icon (no SVG/icon-asset pipeline exists in the native app
// yet -- text-only for now rather than faking one) and the presence dot
// (no presence-sensor data wired into ha_client.py's model yet). Both are
// real, scoped follow-ups, not oversights.
//
// Still deliberately NOT included (real PWA features, just bigger scope):
// drag-to-set brightness on the pill itself (tap-to-toggle stays as the
// write action for now), color presets, day/night theme shift, the global
// Night/Day buttons. Follow-up passes, not this one.
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

    // Matches the PWA's updateClock interval (setInterval(updateClock,
    // 1000*15)) -- a clock only needs to be accurate to the minute here.
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clockText.text = Qt.formatTime(now, "h:mm ap")
            dateText.text = Qt.formatDate(now, "dddd, MMMM d")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 2
                Text {
                    id: clockText
                    font.family: Theme.fontHead
                    font.pixelSize: 56
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    id: dateText
                    font.family: Theme.fontBody
                    font.pixelSize: 16
                    color: Theme.textDim
                }
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
                        // brightnessWord() mirrors the PWA's
                        // ambientBrightnessWord() exactly -- same four
                        // bands, same thresholds.
                        function brightnessWord(pct) {
                            if (pct <= 0) return "Off"
                            if (pct < 40) return "Dim"
                            if (pct < 75) return "On"
                            return "Bright"
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        radius: Theme.radiusCard
                        color: modelData.lightOn ? Theme.onDim : Theme.baseRaised
                        border.color: Theme.hairline
                        border.width: 1

                        // Tap-to-toggle: the real write action this pass
                        // proves end-to-end. Toggles every light entity in
                        // the room via HA's own light.toggle (each entity
                        // flips independently based on its own current
                        // state, same semantics as the PWA's per-room
                        // quick-action button in Ambient Mode v1). No-op
                        // for rooms with no light entities.
                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.lightEntityIds.length > 0
                            onClicked: haClient.callService("light", "toggle", modelData.lightEntityIds)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                Text {
                                    text: modelData.name
                                    font.family: Theme.fontBody
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                }

                                Item { Layout.fillHeight: true }

                                Text {
                                    text: modelData.hasLight ? brightnessWord(modelData.lightPct) : "No light"
                                    font.family: Theme.fontHead
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.text
                                }

                                Text {
                                    text: modelData.hasLight ? modelData.lightName : "Fixture pending"
                                    font.family: Theme.fontBody
                                    font.pixelSize: 12
                                    color: Theme.textDim
                                }
                            }

                            // Vertical pill -- same fill-from-bottom
                            // brightness indicator as the PWA's
                            // .ambient-vpill-track/.ambient-vpill-fill.
                            // Display-only in this pass (shows current
                            // brightness; dragging to set it is a
                            // follow-up, not proven here yet).
                            Rectangle {
                                visible: modelData.hasLight
                                Layout.alignment: Qt.AlignBottom
                                width: 13
                                height: 46
                                radius: 999
                                color: Theme.hairline
                                clip: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: parent.height * (modelData.lightPct / 100)
                                    radius: 999
                                    color: modelData.lightOn ? Theme.on : Theme.textDim
                                }
                            }
                        }
                    }
                }
            }
        }

        // Devices Home Assistant can't reach directly (see homey_client.py) --
        // read/written straight from Homey's local API, second connection,
        // same pattern as the PWA's thermostat/moods. Kept as its own row
        // rather than merged into the area grid above: proving the second
        // connection works end-to-end first, merging into a unified room
        // view is a follow-up once this is confirmed live.
        RowLayout {
            Layout.fillWidth: true
            visible: homeyClient.devices.length > 0
            spacing: 12

            Text {
                text: "Homey"
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: Theme.textFaint
            }

            Repeater {
                model: homeyClient.devices

                delegate: Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 56
                    radius: Theme.radiusChip
                    color: modelData.on ? Theme.onDim : Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: homeyClient.setOnOff(modelData.id, !modelData.on)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        font.family: Theme.fontBody
                        font.pixelSize: 13
                        color: modelData.on ? Theme.on : Theme.textDim
                        elide: Text.ElideRight
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
