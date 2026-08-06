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
  living: {
    lighting: [
      "light.living_room_couch",
      "light.spot",
      "light.floor",
    ],
  },
  kitchen: {
    lighting: [
      "light.kitchen_lifx_ceiling",
      "light.cob_kitchen_sink_2",
    ],
  },
  utility: {
    lighting: [
      "light.h61b3_785f",
      "light.entry_smells_diffuser_nightlight",
    ],
  },
  office: {
    lighting: [
      "light.floor_lamp_office",
    ],
  },
  master: {
    lighting: [
      "light.h612d_1746",
    ],
  },
  dining: {
    lighting: [
      "light.dining_room_right",
    ],
  },
  // Bedroom 4 (guest bedroom) — only fan-integrated lights exist right now
  // (the category Mike said is getting replaced with Inovelli switches +
  // plain fixtures soon). Using it now, flagged to swap the entity_id
  // once real fixtures land.
  bedroom4: {
    lighting: [
      "light.bedroom_4_fan_1",
    ],
  },
  // Bedroom 3 — area_id "bedroom" in HA's Area registry is actually named
  // "Bedroom 3" (confusingly, not "bedroom_3"). First search missed this;
  // real light is "Rocco Ceiling" (fan-integrated pair, same deferred
  // cleanup as other ceiling-fan light pairs this session — just using
  // one of the two here).
  bedroom3: {
    lighting: [
      "light.rocco_ceiling_1",
    ],
  },
};
