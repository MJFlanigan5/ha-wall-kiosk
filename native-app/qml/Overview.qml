import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
// Theme is a pragma-Singleton declared in qmldir in this same directory --
// QML resolves it automatically for files in this directory, no explicit
// module import needed.

// Ambient Mode, ported from the PWA's proven design (pwa-app/index.html,
// renderAmbientActions()) card for card -- not just the room-grid anatomy
// from the first pass, but the full status row too (Music, Comfort,
// Packages, Energy Flow, Water Usage, Home Usage, Water Heater, Security),
// same real entities/devices the PWA already proved out. Exact entity IDs
// mirrored from pwa-app/index.html's AMBIENT_*_ENTITY constants into
// ha_client.py's AMBIENT_ENTITY_IDS -- same real house, same real data.
//
// Deliberately still text-only: no SVG/icon-asset pipeline exists in the
// native app yet, so every card's icon slot is just omitted rather than
// faked. Presence dot is now wired (Magic Areas' per-area aggregate
// sensor, matched by naming convention, not a hardcoded room map).
//
// Still deliberately NOT included (real PWA features, bigger scope):
// drag-to-set brightness/volume on the vertical pill or volume bar (tap
// transport buttons work; dragging doesn't yet), color presets, day/night
// theme shift, the global Night/Day buttons, the bottom quick-nav row.
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

    // Real device, one house -- same hardcoded-constant pattern
    // pwa-app/index.html uses for NEST_THERMOSTAT_DEVICE_ID. Bridged
    // Homey -> HA for its display sensors, but written to directly via
    // Homey's local API (see ha_client.py/homey_client.py comments on
    // why: HA's mirrored climate entity doesn't accept writes here).
    readonly property string nestThermostatDeviceId: "7d030c67-4001-483b-8765-75f7d34efa59"

    function brightnessWord(pct) {
        if (pct <= 0) return "Off"
        if (pct < 40) return "Dim"
        if (pct < 75) return "On"
        return "Bright"
    }

    function fmtKw(stateObj) {
        if (!stateObj || stateObj.state === null || stateObj.state === undefined) return "—"
        var v = parseFloat(stateObj.state)
        return isNaN(v) ? "—" : v.toFixed(2) + " kW"
    }

    function packagesTotal() {
        var a = haClient.ambient
        var keys = ["package_amazon", "package_usps", "package_fedex", "package_ups", "package_dhl"]
        var sum = 0
        for (var i = 0; i < keys.length; i++) {
            var v = parseInt(a[keys[i]].state, 10)
            if (!isNaN(v)) sum += v
        }
        return sum
    }

    function isArmed(state) {
        return !!state && (state.indexOf("armed") === 0 || state === "arming" || state === "pending")
    }

    function alarmLabel(state) {
        if (!state) return "—"
        var s = state.replace("armed_", "Armed ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function findPlayingMedia() {
        var areas = haClient.areas
        var withMedia = []
        for (var i = 0; i < areas.length; i++) {
            if (areas[i].hasMedia) withMedia.push(areas[i])
        }
        for (var j = 0; j < withMedia.length; j++) {
            if (withMedia[j].mediaPlaying) return withMedia[j]
        }
        return withMedia.length > 0 ? withMedia[0] : null
    }

    // Exact HA Area registry names for pwa-app/index.html's AMBIENT_ROOMS
    // slugs, in the same dictated order (living, kitchen, dining, office,
    // master, bedroom3, bedroom4) -- confirmed against this house's real
    // area registry, not guessed.
    readonly property var ambientRoomNames: ["Living Room", "Kitchen", "Dining Room", "Office", "Master Bedroom", "Bedroom 3", "Bedroom 4"]
    // pwa-app/index.html's ROOMS object gives bedroom3/bedroom4 display
    // names of "Guest East"/"Guest West" -- the HA Area registry's own
    // names ("Bedroom 3"/"Bedroom 4") are only used to find the right
    // area/entities, not shown on screen. Same index order as above.
    readonly property var ambientRoomDisplayNames: ["Living Room", "Kitchen", "Dining Room", "Office", "Master Bedroom", "Guest East", "Guest West"]

    function ambientRooms() {
        var order = root.ambientRoomNames
        var display = root.ambientRoomDisplayNames
        var areas = haClient.areas
        var result = []
        for (var i = 0; i < order.length; i++) {
            for (var j = 0; j < areas.length; j++) {
                if (areas[j].name === order[i]) {
                    var room = Object.assign({}, areas[j])
                    room.displayName = display[i]
                    result.push(room)
                    break
                }
            }
        }
        return result
    }

    // Same "Bedroom 3"/"Bedroom 4" -> "Guest East"/"Guest West" override
    // used by room cards, applied wherever a raw HA area name is shown to
    // the user (e.g. the Music card's room label, if a Guest room's media
    // happens to be the one playing).
    function displayNameFor(rawName) {
        var idx = root.ambientRoomNames.indexOf(rawName)
        return idx >= 0 ? root.ambientRoomDisplayNames[idx] : rawName
    }

    // Matches the PWA's updateClock interval (setInterval(updateClock,
    // 1000*15)) -- a clock only needs to be accurate to the minute here.
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            // Manual JS date math instead of Qt.formatTime/formatDate --
            // Qt's "h" token silently switches to 24-hour once no "ap" is
            // present in the format string, which broke this once already.
            // This mirrors updateAmbientClock() in pwa-app/index.html
            // exactly: clock has no am/pm suffix (appended to the date
            // line instead, e.g. "Thursday, August 6 · PM").
            var h = now.getHours()
            var m = now.getMinutes()
            var ampm = h >= 12 ? "PM" : "AM"
            h = h % 12 || 12
            clockText.text = h + ":" + String(m).padStart(2, "0")
            var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            dateText.text = days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate() + " · " + ampm
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        // Clock + date + grid are ONE centered block, matching the PWA's
        // .ambient-overlay exactly (`flex-direction: column; align-items:
        // center; justify-content: center`) -- not a top-left header row
        // sitting above a separately-positioned grid. Connection status
        // moved to its own corner indicator below so it doesn't disturb
        // this structure (the PWA's Ambient screen has no such indicator
        // at all -- this app's own addition, kept but out of the way).
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    // .ambient-clock: font-family var(--font-mono);
                    // font-size clamp(64px, 12vw, 140px) -- resolves to
                    // exactly 140 at both 1200 and 1920 logical width, so
                    // hardcoded rather than a live vw calculation.
                    font.family: Theme.fontMono
                    font.pixelSize: 140
                    font.weight: Font.DemiBold
                    color: Theme.text
                    font.letterSpacing: -1
                }
                Text {
                    id: dateText
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 34 // .ambient-date's margin-bottom:40px minus the 6px column spacing already above it
                    font.family: Theme.fontMono
                    font.pixelSize: 15
                    color: Theme.textDim
                    font.letterSpacing: 1
                    font.capitalization: Font.AllUppercase
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    // Exact match to pwa-app/index.html's .ambient-actions:
                    // `grid-template-columns: repeat(8, 130px); gap: 12px;`
                    columns: 8
                    columnSpacing: 12
                    rowSpacing: 12

                // ---------- Status row (matches renderAmbientActions()'s
                // row 1: Music, Comfort, Packages, Energy Flow, Water
                // Usage, Home Usage, Water Heater) ----------

                Rectangle {
                    id: musicCard
                    property var playing: root.findPlayingMedia()
                    Layout.preferredWidth: 130 * 2 + 12
                    Layout.columnSpan: 2
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: (playing && playing.mediaPlaying) ? Theme.onDim : Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Image {
                            source: (musicCard.playing && musicCard.playing.mediaPlaying) ? "icons/music-on.svg" : "icons/music.svg"
                            sourceSize.width: 18
                            sourceSize.height: 18
                            Layout.bottomMargin: 8
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: musicCard.playing ? (musicCard.playing.mediaPlaying ? musicCard.playing.mediaTrack : "Paused") : "Nothing playing"
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: musicCard.playing ? root.displayNameFor(musicCard.playing.mediaName) : "Music"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            visible: !!musicCard.playing
                            spacing: 8
                            Layout.topMargin: 10

                            Rectangle {
                                width: 40; height: 32; radius: Theme.radiusChip
                                color: Theme.base; border.color: Theme.hairline; border.width: 1
                                Image { anchors.centerIn: parent; source: "icons/skip-back.svg"; sourceSize.width: 14; sourceSize.height: 14 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: haClient.callService("media_player", "media_previous_track", [musicCard.playing.mediaEntityId])
                                }
                            }
                            Rectangle {
                                width: 40; height: 32; radius: Theme.radiusChip
                                color: Theme.base; border.color: Theme.hairline; border.width: 1
                                Image {
                                    anchors.centerIn: parent
                                    source: (musicCard.playing && musicCard.playing.mediaPlaying) ? "icons/pause.svg" : "icons/play.svg"
                                    sourceSize.width: 14
                                    sourceSize.height: 14
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: haClient.callService("media_player", "media_play_pause", [musicCard.playing.mediaEntityId])
                                }
                            }
                            Rectangle {
                                width: 40; height: 32; radius: Theme.radiusChip
                                color: Theme.base; border.color: Theme.hairline; border.width: 1
                                Image { anchors.centerIn: parent; source: "icons/skip-forward.svg"; sourceSize.width: 14; sourceSize.height: 14 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: haClient.callService("media_player", "media_next_track", [musicCard.playing.mediaEntityId])
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: comfortCard
                    property real thermoTemp: parseFloat(haClient.ambient.thermostat_temp.state)
                    property real thermoCool: parseFloat(haClient.ambient.thermostat_cool.state)
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                            Image { source: "icons/thermometer.svg"; sourceSize.width: 18; sourceSize.height: 18 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Hallway"
                                font.family: Theme.fontBody
                                font.pixelSize: 11
                                color: Theme.textDim
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: !isNaN(comfortCard.thermoTemp) ? Math.round(comfortCard.thermoTemp) + "°" : "—"
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: !isNaN(comfortCard.thermoCool) ? "Comfort · cools to " + Math.round(comfortCard.thermoCool) + "°" : "Comfort"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !isNaN(comfortCard.thermoCool)

                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: Theme.radiusChip
                                color: Theme.base; border.color: Theme.hairline; border.width: 1
                                Text { anchors.centerIn: parent; text: "−"; color: Theme.textDim; font.pixelSize: 16 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var target = Math.round(comfortCard.thermoCool) - 1
                                        homeyClient.setCapabilityBool(root.nestThermostatDeviceId, "nest_thermostat_eco", false)
                                        homeyClient.setCapabilityNumber(root.nestThermostatDeviceId, "target_temperature.cool", target)
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 32; radius: Theme.radiusChip
                                color: Theme.base; border.color: Theme.hairline; border.width: 1
                                Text { anchors.centerIn: parent; text: "+"; color: Theme.textDim; font.pixelSize: 16 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var target = Math.round(comfortCard.thermoCool) + 1
                                        homeyClient.setCapabilityBool(root.nestThermostatDeviceId, "nest_thermostat_eco", false)
                                        homeyClient.setCapabilityNumber(root.nestThermostatDeviceId, "target_temperature.cool", target)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Image { source: "icons/package.svg"; sourceSize.width: 18; sourceSize.height: 18; Layout.bottomMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root.packagesTotal()
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Packages"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Image { source: "icons/zap.svg"; sourceSize.width: 18; sourceSize.height: 18; Layout.bottomMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root.fmtKw(haClient.ambient.power)
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Energy Flow"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                        ColumnLayout {
                            Layout.topMargin: 8
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Solar"; font.family: Theme.fontBody; font.pixelSize: 12; color: Theme.textDim; Layout.fillWidth: true }
                                Text { text: root.fmtKw(haClient.ambient.solar); font.family: Theme.fontBody; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Battery"; font.family: Theme.fontBody; font.pixelSize: 12; color: Theme.textDim; Layout.fillWidth: true }
                                Text { text: root.fmtKw(haClient.ambient.battery); font.family: Theme.fontBody; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Grid"; font.family: Theme.fontBody; font.pixelSize: 12; color: Theme.textDim; Layout.fillWidth: true }
                                Text { text: root.fmtKw(haClient.ambient.grid); font.family: Theme.fontBody; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Image { source: "icons/droplets.svg"; sourceSize.width: 18; sourceSize.height: 18; Layout.bottomMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: haClient.ambient.water_usage.state != null ? parseFloat(haClient.ambient.water_usage.state).toFixed(1) : "—"
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "gal · Water Today"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Image { source: "icons/sprout.svg"; sourceSize.width: 18; sourceSize.height: 18; Layout.bottomMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: haClient.ambient.home_usage.state != null ? parseFloat(haClient.ambient.home_usage.state).toFixed(1) : "—"
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "kWh · Home Usage"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 170
                    radius: Theme.radiusCard
                    color: Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        Image { source: "icons/droplet.svg"; sourceSize.width: 18; sourceSize.height: 18; Layout.bottomMargin: 8 }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: {
                                var attrs = haClient.ambient.water_heater.attributes
                                var t = attrs ? attrs.temperature : null
                                return t !== null && t !== undefined ? Math.round(t) + "°" : "—"
                            }
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Water Heater"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true; height: 32; radius: Theme.radiusChip
                            color: Theme.base; border.color: Theme.hairline; border.width: 1
                            Text { anchors.centerIn: parent; text: "Hot Water"; color: Theme.textDim; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: haClient.callService("script", "turn_on", ["script.shower_prep_now"])
                            }
                        }
                    }
                }

                // ---------- Room cards ----------

                Repeater {
                    // Curated to the exact 7 rooms + order Mike dictated
                    // for AMBIENT_ROOMS in pwa-app/index.html (2026-08-06)
                    // -- Ambient Mode is a deliberately fixed 8-column
                    // layout, not "every area HA reports" (that's what
                    // the interior/Admin screens are for).
                    model: root.ambientRooms()

                    delegate: Rectangle {
                        required property var modelData

                        Layout.preferredWidth: 130
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

                                RowLayout {
                                    Layout.fillWidth: true
                                    Image {
                                        source: modelData.lightOn ? "icons/lightbulb-on.svg" : "icons/lightbulb.svg"
                                        sourceSize.width: 18
                                        sourceSize.height: 18
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        Layout.maximumWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                        wrapMode: Text.WordWrap
                                        text: modelData.displayName
                                        font.family: Theme.fontBody
                                        font.pixelSize: 11
                                        color: Theme.textDim
                                    }
                                    Rectangle {
                                        visible: modelData.hasPresence
                                        width: 6; height: 6; radius: 3
                                        color: modelData.presenceOn ? Theme.on : Theme.textFaint
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: modelData.hasLight ? root.brightnessWord(modelData.lightPct) : "No light"
                                    font.family: Theme.fontHead
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    color: Theme.text
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
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

                Rectangle {
                    id: securityCard
                    property var alarmState: haClient.ambient.alarm.state
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 140
                    radius: Theme.radiusCard
                    color: root.isArmed(alarmState) ? Theme.onDim : Theme.baseRaised
                    border.color: Theme.hairline
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Image {
                            source: root.isArmed(securityCard.alarmState) ? "icons/shield-check-on.svg" : "icons/shield.svg"
                            sourceSize.width: 18
                            sourceSize.height: 18
                            Layout.bottomMargin: 8
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root.alarmLabel(securityCard.alarmState)
                            font.family: Theme.fontHead
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Security"
                            font.family: Theme.fontBody
                            font.pixelSize: 12
                            color: Theme.textDim
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true; height: 32; radius: Theme.radiusChip
                            color: Theme.base; border.color: Theme.hairline; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: root.isArmed(securityCard.alarmState) ? "Disarm" : "Arm Away"
                                color: Theme.textDim; font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: haClient.callService(
                                    "alarm_control_panel",
                                    root.isArmed(securityCard.alarmState) ? "alarm_disarm" : "alarm_arm_away",
                                    ["alarm_control_panel.alarmo"]
                                )
                            }
                        }
                    }
                }
                }

                // Bottom quick-nav row -- matches AMBIENT_QUICKNAV in
                // pwa-app/index.html exactly (security/music/settings).
                // Bare icons, no button chrome, same as the reference.
                // Not wired to navigation yet -- there's no room-screen
                // stack in the native app to navigate to (Ambient is the
                // only screen so far), so these are display-only for now.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 32
                    spacing: 30

                    Image { source: "icons/shield.svg"; sourceSize.width: 20; sourceSize.height: 20 }
                    Image { source: "icons/music.svg"; sourceSize.width: 20; sourceSize.height: 20 }
                    Image { source: "icons/settings.svg"; sourceSize.width: 20; sourceSize.height: 20 }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 18
                    text: "TAP A CARD TO OPEN THAT ROOM · TAP ANYWHERE ELSE TO WAKE"
                    font.family: Theme.fontBody
                    font.pixelSize: 12
                    font.letterSpacing: 0.5
                    color: Theme.textDim
                    opacity: 0.6
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

    // Theme toggle -- matches .ambient-theme-toggle exactly (bare icon,
    // top-right, no button chrome). Display-only for now: the PWA's
    // light/dark ambient theme swap (docs/UI_MODES_SPEC.md roadmap item)
    // isn't built in the native app yet, so this always shows the moon
    // (this app's only theme, dark, matching its current default).
    Image {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 40
        source: "icons/moon.svg"
        sourceSize.width: 24
        sourceSize.height: 24
    }

    // Connection status -- this app's own addition, not part of the PWA's
    // Ambient design at all. Only shown when something's actually wrong
    // (not connected), so the normal/expected screen stays text-for-text
    // identical to the PWA's Ambient overlay -- this only interrupts that
    // match when there's a real problem to surface.
    RowLayout {
        visible: !haClient.connected
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        spacing: 8

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: haClient.connected ? Theme.on : Theme.textFaint
        }
        Text {
            text: haClient.connected ? "connected" : "connecting…"
            font.family: Theme.fontMono
            font.pixelSize: 12
            color: Theme.textFaint
        }
    }
}
