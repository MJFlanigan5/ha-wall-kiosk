// Which real HA entities populate each mockup room. Explicit and curated,
// not auto-discovered from the Area registry — the live instance has a lot
// of duplicate/orphaned entities and non-room devices (network switch LEDs,
// sensor status lights) mixed into area assignments, so blind auto-mapping
// produced garbage. Edit this file to add more rooms/entities as the app
// grows; each entry just needs a valid light entity_id from your instance.
//
// MVP scope (2026-08-05): lighting only, 3 rooms. Climate is not included
// anywhere in this file on purpose — no climate entities exist in this HA
// instance yet (verified via live search, not assumed).

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
};
