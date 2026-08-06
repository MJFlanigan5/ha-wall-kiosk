// Which real HA entities populate each mockup room. Explicit and curated,
// not auto-discovered from the Area registry — the live instance has a lot
// of duplicate/orphaned entities and non-room devices (network switch LEDs,
// sensor status lights) mixed into area assignments, so blind auto-mapping
// produced garbage. Edit this file to add more rooms/entities as the app
// grows; each entry just needs a valid light entity_id from your instance.
//
// MVP scope (2026-08-05): lighting only. Climate is not included anywhere
// in this file on purpose — no climate entities exist in this HA instance
// (verified via live search, not assumed) except the Hallway thermostat,
// wired separately in index.html's Ambient Comfort tile.
//
// Expanded 2026-08-06 with 3 more rooms (Office, Master Bedroom, Dining
// Room) so the Ambient screen's room row can cover the whole house, not
// just the original 3. Each entity below was confirmed live via
// get_state before adding — same duplicate-entity caution as the
// original 3 (many devices in this house have a dead/unavailable twin).

const ROOM_ENTITY_MAP = {
  // No media_player here — the only speaker in this area is the Home
  // Assistant Voice PE, confirmed defective this session (zero streamed
  // output audio, refund requested). TV is the real Apple TV
  // (media_player.living_room_2, area_id: living_room, confirmed live).
  living: {
    lighting: [
      "light.living_room_couch",
      "light.spot",
      "light.floor",
    ],
    tv: "media_player.living_room_2",
    airQuality: { pm25: "sensor.h5106_3136_pm25", temp: "sensor.h5106_3136_temperature", humidity: "sensor.h5106_3136_humidity" },
  },
  // media_player added 2026-08-06 — pilot room for wiring real per-room
  // speakers/TVs. Kitchen's Sonos speaker is oddly entity-id'd
  // "media_player.utility_room" (friendly_name "Kitchen") — a real house
  // naming quirk, not a mistake; confirmed live (area_id: kitchen,
  // volume_level 0.77, idle). TV picked from several near-duplicate
  // "Kitchen TV 2" entities — this one has no numeric HA-generated
  // suffix, the others (_2, _airplay) are Cast/AirPlay bridge duplicates
  // of the same physical set.
  kitchen: {
    lighting: [
      "light.kitchen_lifx_ceiling",
      "light.cob_kitchen_sink_2",
    ],
    media_player: "media_player.utility_room",
    tv: "media_player.kitchen_tv_2",
    // No airQuality here — the Smart Air Purifier only reports the
    // computed AQI number (confirmed broken, see index.html's renderHero),
    // no raw PM2.5/temp/humidity sensors like the other rooms' Govee AQ
    // monitors have. Nothing real to show for this room.
  },
  // No speaker/TV added here — the only media_player candidates in Utility
  // Room's area are appliance-adjacent, not a real listening device.
  utility: {
    lighting: [
      "light.h61b3_785f",
      "light.entry_smells_diffuser_nightlight",
    ],
    tv: "media_player.utility_room_tv_2",
    airQuality: { pm25: "sensor.utility_room_air_quality_pm25", temp: "sensor.utility_room_aq_temperature", humidity: "sensor.utility_room_aq_humidity" },
  },
  // Speaker is "Veda" (a real house nickname for this room's Google Home,
  // not a mistake) — not area-tagged in HA's registry the way Kitchen's
  // was, confirmed instead by cross-referencing the device list (device
  // "Google Home Veda" -> area_id office) plus get_state (live, Music
  // Assistant Queue). No TV device exists in this room.
  office: {
    lighting: [
      "light.floor_lamp_office",
    ],
    media_player: "media_player.veda",
    airQuality: { pm25: "sensor.h5106_1378_pm25", temp: "sensor.h5106_1378_temperature", humidity: "sensor.h5106_1378_humidity" },
  },
  // Speaker is the Google Home Mini (master_bedroom_speaker), not the
  // HT-A3000 soundbar (that's TV-paired audio, not an independent music
  // zone) and not "Master Bathroom" (a different physical room's Sonos).
  master: {
    lighting: [
      "light.h612d_1746",
    ],
    media_player: "media_player.master_bedroom_speaker",
    tv: "media_player.master_bedroom_tv_2",
    airQuality: { pm25: "sensor.h5106_568d_pm25", temp: "sensor.h5106_568d_temperature", humidity: "sensor.h5106_568d_humidity" },
  },
  // TV picked as the Cast-bridge entity (dining_room_tcl_tv, matches the
  // same supported_features scheme as Kitchen/Utility's working Cast
  // entities) over the native-integration duplicate (55a300w_television)
  // for consistency with the pattern already verified live in Kitchen.
  // No airQuality here — this room's Qingping CGS1 sensor is uncalibrated
  // (temperature reads 181, humidity/CO2/PM2.5 all "unknown"), same known
  // issue already noted for its CO2 reading elsewhere in this app.
  dining: {
    lighting: [
      "light.dining_room_right",
    ],
    media_player: "media_player.dining_room_speaker",
    tv: "media_player.dining_room_tcl_tv",
  },
  // Bedroom 4 (guest bedroom) — fan-integrated light physically removed
  // (2026-08-06, Mike's call). No real light for this room right now;
  // real switches + fixtures (and eventually the fan itself) are coming
  // later. Add the new light entity_id here once installed.
  bedroom4: {
    lighting: [],
    media_player: "media_player.bedroom_4_speaker",
    tv: "media_player.guest_bedroom_tv_2",
    airQuality: { pm25: "sensor.h5106_2a62_pm25", temp: "sensor.h5106_2a62_temperature", humidity: "sensor.h5106_2a62_humidity" },
  },
  // Bedroom 3 — area_id "bedroom" in HA's Area registry is actually named
  // "Bedroom 3" (confusingly, not "bedroom_3"). First search missed this;
  // real light is "Rocco Ceiling" (fan-integrated pair, same deferred
  // cleanup as other ceiling-fan light pairs this session — just using
  // one of the two here). No TV device exists in this room.
  bedroom3: {
    lighting: [
      "light.rocco_ceiling_1",
    ],
    media_player: "media_player.bedroom_3_speaker",
    airQuality: { pm25: "sensor.bedroom_3_air_quality_pm25", temp: "sensor.bedroom_3_air_quality_temperature", humidity: "sensor.bedroom_3_air_quality_humidity" },
  },
};
