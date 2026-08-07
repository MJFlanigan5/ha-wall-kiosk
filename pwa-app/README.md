# PWA app (iPad + phone)

MVP built 2026-08-05 (see [`docs/IPAD_PWA_SPEC.md`](../docs/IPAD_PWA_SPEC.md)
for the full phase plan). Live HA data wired into the existing Savant
mockup for 3 rooms' lighting — everything else in the mockup is still mock
content.

## What's actually wired to live data

- **Lighting only, 3 rooms**: Living Room, Kitchen, Utility Room — the
  specific entities are in `rooms.config.js`, chosen because they're real,
  clean entities (no duplicates, no network-hardware LEDs mixed in — the
  live instance has a lot of those, see note below).
- Toggle, brightness slider, global brightness presets, and the color
  wheel all push real `light.turn_on`/`light.turn_off` service calls.
- State stays live via HA's `state_changed` WebSocket subscription — if
  you turn a light on with a switch/Homey/voice, the app updates without
  a refresh.
- **Music, 2 of 3 rooms** (2026-08-05, corrected 2026-08-06): each room's
  real device assigned via Admin Mode — Kitchen → `media_player.utility_room`
  (odd entity_id, real friendly_name/area is Kitchen), Utility Room →
  `media_player.utility_room_tv_2`. Both had duplicate/unavailable siblings
  sharing the same friendly_name — same mess as the light duplicates,
  caught and resolved by hand for each one. Living Room's assignment
  (`media_player.ht_a3000`) was wrong and has been removed: HA's area
  registry confirms that entity is physically in the Master Bedroom, not
  Living Room, and Living Room has no other real speaker entity right now
  — its Music section is intentionally unassigned until one exists.

## Ambient Mode (v7, all rooms + merged presence 2026-08-06)

Reworked one more time per Mike's direction: room cards merged with
presence (one card per room again, a small dot next to the room name
carries presence instead of a separate tile), the vertical pill is now the
only lighting control (removed the chevron button — dragging to the
bottom turns the light off, no redundant toggle next to the slider), and
expanded from 3 rooms to all 6 with real wired lighting: Living Room,
Kitchen, Utility Room, **Office** (`light.floor_lamp_office`), **Master
Bedroom** (`light.h612d_1746` — picked over the older `light.master_under_bed`
duplicate because it has a real `area_id`, same duplicate-entity pattern as
earlier tonight), **Dining Room** (`light.dining_room_right`). All three new
rooms also got real Magic Areas presence entities and were added to
`ROOM_ORDER` so they're reachable from the main rail nav too, not just
Ambient.

Layout is now two rows: system/status cards on top (Music, Comfort,
Security, Energy Flow, Packages, CO2, Energy Produced — 8 grid units, Music
spans 2), every room's merged card on the bottom row (6 units). Comfort
sits immediately after Music per explicit direction. Grid widened to 8
columns to fit this.

**Real bug found while adding these rooms:** `getRoomEntityMap()` returns
the Admin Mode localStorage override *wholesale* if one exists at all — it
does not merge with `rooms.config.js`. A stale override from earlier Admin
Mode testing on this dev browser (only living/kitchen/utility) completely
shadowed the 3 new rooms until the override was cleared. This is a latent
gotcha for anyone editing `rooms.config.js` after ever having touched Admin
Mode on that device — the file change won't appear until the override is
cleared or Admin Mode re-saves a fresh snapshot. Not fixed at the root
(would mean redesigning how overrides layer on the static config, a real
decision, not a quick patch) — documented here so it isn't a mystery next
time.

## Ambient Mode (v6, exact 1:1 grid match to reference 2026-08-06)

v5 still picked which tile *types* to show based on what data existed.
Rebuilt one more time as a literal 1:1 copy of the reference screenshot's
11-tile grid — same positions, same labels, same icons — real data where
it exists, a plain "—" (no invented numbers) where it doesn't:

Row 1: Media (2-col) · Living Room light · Kitchen Comfort (real temp
sensor) · Kitchen light · Security (Night Mode's slot).
Row 2: Front window/Cover (no real cover entity — static, "—") · Energy
Flow (real) · CO2 emission saved (no CO2 sensor — static, "—") · Energy
Produced (no cumulative sensor — static, "—") · Presence · Utility Room
light.

Grid is real CSS Grid now (6 fixed 130px columns), not flex-wrap — media
card spans 2 columns exactly like the reference's double-wide tile. Pill
button icon changed from a power glyph to chevron-down to match the
reference's dropdown control.

## Ambient Mode (v5, room cards replaced with individual favorites 2026-08-06)

v4 (below) still put one card per configured room, showing that room's
aggregate lighting state. That's not what the Loxone reference actually
shows — its screen has no "whole room lighting" tiles at all, it favorites
specific individual devices (one named light, a temp reading, a cover). On
reflection, a per-room aggregate is also redundant here: every room is
already one tap away via the rail nav, so a summary card that just repeats
"which rooms have lights on" doesn't add anything Loxone's own design
doesn't already skip.

Replaced the 3 room cards with 3 individual light-favorite cards — one
representative light per room (Living Room's couch light, Kitchen's LIFX
ceiling, Utility Room's main strip), each showing that specific light's own
name as the subtext instead of the room name. Header/primary/vertical-pill/
toggle mechanics are otherwise identical to v4, just re-scoped from "the
whole room's lighting array" to "this one light" (`roomId:lightIndex` key
instead of `roomId`). Verified live: toggled `light.living_room_couch`
via the new per-light power button, confirmed `light.turn_on` landed at
100% brightness by reading HA state directly, restored to off after.

No cover or CO2 entities exist in this HA instance (checked via
`search_entities` — the only "cover" match is an unrelated HA statistics
sensor, not a real cover domain entity), so those two tile types from the
reference aren't represented here — consistent with the project's standing
rule against fabricating tiles for data that doesn't exist.

## Ambient Mode (v4, tile anatomy rebuilt 2026-08-06)

After 90 seconds of no touch, the app drops into a full-screen idle view.
v3 was still "our own interpretation" of the Loxone reference — close, but
the actual tile anatomy (horizontal slider, chip-style header, verbose
status text) didn't match the real screenshot closely enough. v4 rebuilds
every card from scratch against the literal reference anatomy instead of
reinterpreting it:

- **Card anatomy** — small icon top-left, room/zone label top-right (bare
  text, no chip), one bold single-word primary status ("Off"/"Bright"/
  "Presence"), a dim device-type subtext line underneath. Every card is the
  same fixed 148px width — a uniform grid, not the mixed-width layout v3
  had.
- **Vertical pill slider** (replaces v3's horizontal `.slider-track` reuse)
  — Loxone's actual brightness control is a tall narrow capsule that fills
  from the bottom, not a horizontal bar. New `.ambient-vpill-track`
  component, drag sets brightness via inverted-Y pointer math (higher on
  the pill = brighter). Verified live: dispatched real pointer events
  against a real light (`light.living_room_couch` + 2 others), confirmed
  `light.turn_on` fired with the correct `brightness_pct` by reading HA
  state directly afterward, then restored the lights to off.
- **Presence split into its own card type** — v3 folded a presence line
  into the lighting card; the reference shows presence as its own separate
  tile (icon + "Presence"/"No Presence" + room name), so v4 does too, one
  per room with a `PRESENCE_ENTITY_BY_ROOM` mapping to the real Magic Areas
  sensors.
- **Tap-to-navigate** — unchanged from v3: tapping a card's body opens that
  room's real screen and exits Ambient (`goToRoom()`, shared with the rail
  nav). The pill, power toggle, and transport controls are separate inner
  elements that stop propagation and stay on Ambient.
- **Music card** — real album art, prev/next transport, and a real volume
  slider (`media_player.volume_set`), restructured to the new header/
  primary/sub anatomy but otherwise unchanged from v3.
- **Energy Flow card** — real Tesla Powerwall solar/battery/grid breakdown,
  same header/primary/sub restructure, content unchanged from v3.
- **Security card** — real Alarmo panel, single-tap Arm Away / Disarm,
  unchanged from v3 (see prior reasoning below on why this replaced a
  whole-house Night Mode tile).
- **Bottom quick-nav row** — now bare icons only (no text labels), matching
  the reference's plain glyph row exactly. Security/Video/Music/Settings,
  real navigation to those rail-nav destinations.
- **Corner theme toggle** — now a bare icon (no button chrome/circle),
  matching the reference's plain moon glyph instead of v3's filled button.
- **Light/dark theme** — a real second palette (moon/sun icon, top right),
  scoped entirely to `.ambient-overlay.ambient-light` via CSS
  custom-property overrides, so it never touches the interior room screens.

Dropped from v3: inline color-preset swatches on room cards (the reference
doesn't show them on its lighting tiles — the interior room screen's color
wheel still has full color control, so this isn't a capability loss, just
moved off the idle screen).

**Real bug found and fixed during this redesign:** removing HT-A3000 from
Living Room's Music assignment earlier the same night left
`ROOMS.living.media` frozen on its original fabricated placeholder data
("Evening Mix — KEXP") — `populateRoomsFromMap()` only touched `.media` when
a `media_player` was assigned, never cleared it when one was removed. The
Music screen was displaying that stale mock data as if it were genuinely
playing. Fixed by explicitly resetting `.media` to an empty/inert shape
when no player is assigned.

See [`docs/UI_MODES_SPEC.md`](../docs/UI_MODES_SPEC.md) for the original
v1/v2 design reasoning. Not tested on a real device yet, same caveat as
everything else below.

**Service worker fixed (2026-08-05):** it was shipping cache-first with a
cache name that never got bumped across any of tonight's pushes — every
push after the first was silently invisible on reload. Rewritten to
network-first (cache is now just an offline fallback), so a reload always
gets the latest code when online.

## Energy screen (Overview + Water Heater wired, 2026-08-06)

Reached from the rail nav ("Energy") or Ambient's Energy Flow card:

- **Overview** — Power Flow, Ring, and Power Mix cards read real Tesla
  Powerwall solar/battery/grid sensors (no code changes needed to those
  components — they always just rendered `POWER.mix`/`totalKw`/`battery`,
  which now hold real numbers instead of fabricated ones). "Top Consumers"
  and "Est. until full" are gone entirely — no per-device wattage or
  battery-ETA data exists anywhere in this HA instance, so rather than
  fabricate it the sections were dropped.
- **Water Heater** — real Rinnai tankless entities (set temp, recirculation,
  flow rate, away/vacation mode). Vacation Mode calls the real
  `water_heater.set_away_mode` service instead of flipping a local boolean.
- **History** — real 7-day daily totals (Solar/Grid/Battery) via HA's
  recorder statistics (2026-08-07, see below). **Automation** is still mock
  (a real rule-builder is its own separate, larger project — explicitly
  out of scope for now, not just unwired). **EV Charging** and **Events**
  (Message Center) were removed entirely, not left mock — see 2026-08-07
  section below.

## Admin Mode (added 2026-08-05)

Gear icon in the footer opens an on-device config screen — no more
hand-editing `rooms.config.js` to add a room or entity:

- **Add a new room** (name only) — gets a real Overview/Lighting screen
  immediately, using safe defaults for climate/media/security/shades so
  other screens don't crash on missing data; those stay placeholder until
  those domains are actually wired.
- **Add/remove lighting entities** per room, picked from a live list of
  your instance's `light.*` entities (already-assigned ones filtered out).
- **Assign one music player per room** (`media_player.*` domain) — but
  this is **basic wiring only**: on/off, track/artist name, and play/pause
  work; volume, shuffle, repeat, and the progress bar do **not** — those
  need the real interpolation/feature-gating work in
  [`docs/MUSIC_SPEC.md`](../docs/MUSIC_SPEC.md), not done here.

**Real bug found and fixed (2026-08-06):** the live instance has multiple
entities sharing the same `friendly_name` (e.g. 4 different "HT-A3000"
media_players — one real, the rest stale/unavailable duplicates from
integration re-adds, the same mess already hand-curated around for
lighting in `rooms.config.js`). Admin's live picker wasn't filtering this,
so it was possible to pick a dead duplicate with no way to tell from the
label alone — assigned it, tapped Play, nothing happened, because the
entity itself was unreachable. Fixed two ways: entities in state
`unavailable` are now excluded from what you can pick at all, and every
option now shows its real `entity_id` alongside the friendly name so
same-named duplicates are distinguishable.

Changes save to `localStorage` on that device only — `rooms.config.js`
stays the shipped default, Admin Mode changes are a per-device override on
top of it (same pattern as the HA URL/token in `config.js`). A page reload
correctly restores rooms created via Admin Mode (their name is saved, not
just their entity assignments — this was a real bug caught and fixed
before shipping: without it, a new room's lighting would still be saved,
but the room itself would silently vanish from navigation on reload).

## Layout: landscape (iPad/wall panel) vs. portrait (phone)

No new work needed here — the existing responsive breakpoint (rail nav
above 768px CSS width, bottom `mobile-rail` nav below 640px) already lines
up with the real usage split: iPad and the wall-mounted Pi run landscape
(wide viewport → side rail), phone runs portrait as normal (narrow
viewport → bottom nav). `manifest.json`'s `orientation: "any"` is
deliberate — locking to one orientation would break the other device
class.

## Security + Cameras (wired 2026-08-07)

Both were previously fully mock — a hand-authored per-room "fault list"
with no real backing data at all, a local-only 3-way arm toggle, and a
4-camera grid (Front Door/Driveway/Back Door/Backyard) where only Front
Door is a real device.

- **Arm/Disarm** — real `alarm_control_panel.alarmo`, same live-updated
  state the Ambient card already used (`AMBIENT_ALARM_ENTITY`). Stay →
  `alarm_arm_home`, Away → `alarm_arm_away`, Disarmed → `alarm_disarm`.
- **Status tab (per-room faults) — removed entirely**, not wired. Checked
  live via `search_entities`: zero contact/window/motion sensors exist
  anywhere in this HA instance, and Alarmo's own `open_sensors` is `null`
  — there was no real data to put there.
- **Lock Doors / Unlock Front Door / Open Door Entry — removed.** No lock
  entities exist (`sensor.locks` reports 0; the one `binary_sensor.front_door_locked`
  is stuck on `unknown`, a dead restored entity).
- **Turn On Porch Lights — kept, now real**, calls `light.turn_on` on
  `group.front_porch_exterior_lights` (the same group already used
  elsewhere in the live HA config).
- **Cameras — now the one real camera** (`camera.front_door_entry_high_resolution_channel`).
  Snapshot polling every 8s via `/api/camera_proxy/<entity>` with the
  Bearer token (blob URL, revoked each refresh to avoid leaking memory
  over a long kiosk session) — not a true video stream, a refreshing
  still image. A real HLS stream is a further step if wanted later.

## Discovery, Climate, Sensors, Video/TV, Notifications (2026-08-07)

A bigger pass, built generically on purpose so it works for any HA/Homey
setup, not just this specific house.

- **Sensors page** (new nav item) — every `sensor.*`/`binary_sensor.*`
  entity in HA, grouped by real room via the area/device/entity
  registries. Zero per-entity config; anything wired into HA shows up
  automatically (Beszel homelab monitoring, Flo water usage, air quality,
  everything). Registries fetched once per session, live values poll on a
  plain interval only while the page is open.
- **Climate** — real per-room section, generic by design: any room can
  have a Homey thermostat-class device assigned (Admin Mode), detected by
  capability shape (`target_temperature*`) **and** Homey's own
  `device.class === "thermostat"` (tightened 2026-08-07 after confirming
  capability-alone can false-positive on other device types, e.g. some
  water heater apps). Renders whatever capabilities the assigned device
  actually exposes — separate heat/cool setpoints, mode enum, read-only
  activity/humidity — instead of assuming a fixed shape. Assignment
  picker auto-suggests a room by matching the device's Homey zone name
  against room names, always listing every unassigned candidate so the
  suggestion can be overridden. Writes go straight to Homey then re-fetch
  (HA's mirrored sensors for this bridge lag 15s+); Eco mode is turned
  off first, generically (any setable boolean capability matching
  `/eco/i`), since it blocks every manual write on the real device this
  was built against. Ambient Mode's Comfort tile was consolidated onto
  this same system (it used to be a separate, duplicate one).
- **Missing-room suggestions** (Admin Mode) — cross-references real HA
  areas + Homey zones against Foyer's existing rooms and surfaces the gap
  with a real device count per candidate, "suggest, don't auto-build" by
  explicit choice: every HA area/Homey zone becoming a full room screen
  automatically would produce flat placeholder screens for spaces that
  don't belong in a wall-kiosk UI (Server Rack, Attic, etc). "Add Room"
  reuses the existing create-room flow directly.
- **Ambient Mode visibility is now opt-in per room**, not automatic —
  `getRoomEntityMap()[roomId].showOnAmbient`, toggled from each room's
  Admin Mode block. Previously a new room forced its way onto Ambient
  with no way to opt out, unlike Utility Room's manual exclusion; both
  now go through the same mechanism.
- **Video/TV — real remote D-pad.** Any room's TV gets one whenever its
  assigned `media_player` has a paired `remote.*` entity on the same HA
  device — found generically via the entity/device registries, not
  hardcoded to Living Room's Apple TV. Command set is HA's own documented
  `apple_tv` `remote.send_command` vocabulary (up/down/left/right/select,
  menu/home/play/pause).
- **Notifications (Settings) — real**, not local-only mock state. 4
  `input_boolean` helpers gate 4 real automations: Climate (thermostat
  reading out of 40–78°), Door Entry (gates the existing front-door
  person-detection automations — the literal doorbell *ring* push turned
  out to be native to the UniFi Protect app, unreachable from HA),
  Lighting (a light still on 10 min after every `person.*` entity is
  `not_home`, via HA's `zone` trigger + `entity_id: all` so it isn't
  hardcoded to one person), Entertainment (any `media_player` still
  playing at 1am).
- **Energy History — actually wired**, and the "Sources is real,
  Consumers is fake" framing from the 2026-08-06 pass turned out to be
  wrong on inspection: *both* were 100% mock (Solar/Grid/Battery values
  were hardcoded arrays too). Sources is now real 7-day daily totals via
  `HAClient.getStatistics()` (HA's `recorder/statistics_during_period` WS
  command — undocumented on HA's side, same one its own energy dashboard
  uses) against real cumulative energy sensors. Consumers, EV Charging,
  and Message Center (Events) were removed entirely rather than fixed —
  zero backing entities exist for any of them, not fixable by wiring.
- **First-run nudge** — the first time a device ever completes
  onboarding, Admin Mode opens automatically to the room-suggestions
  list, instead of requiring the user to already know it exists. Fires
  once per device.
- **Water heater set-temperature — confirmed broken**, not just slow
  polling as previously suspected: a real write + 10 minute wait showed
  `last_updated` advancing (so the integration did poll fresh data) while
  the target temperature itself never changed. Likely in the third-party
  `custom_components.rinnai` HACS integration's cloud round-trip, not a
  bug in this app — Foyer's write path correctly calls the real
  `water_heater.set_temperature` service.

## What's still mock content

As of 2026-08-07: **shades** (no `cover` domain entities exist anywhere
in this HA instance — a real backend gap, not something this app can
fix) and **Power Automation's rule builder** (its own separate, larger
project). Climate, Video/TV, and Message Center/EV Charging were all
still-mock as of the last pass through this doc — see the 2026-08-07
section below for what changed. There is no pool/spa screen in this app
— never was.

## Why only 3 rooms / a curated entity list, not full auto-discovery

Checked the live instance's `light` domain: 80+ entities, many duplicated
(same physical light appearing twice under different entity_ids, one with
a real area assigned and one with `area_id: null`), plus UniFi network
switch status LEDs and sensor onboard indicator lights mixed into room
areas. Auto-populating rooms straight from the Area registry would have
put garbage in the UI. `rooms.config.js` is an explicit, hand-picked list
instead — edit it to add more rooms/entities as they're confirmed clean.

## Setup (per device)

No build step, no config file with secrets. On first load, the app asks
for your HA WebSocket URL and a long-lived access token (HA profile →
Security → Long-lived access tokens), stored in that device's
`localStorage` only — never sent anywhere else, never committed to this
repo.

## Running it right now

```bash
cd pwa-app
python3 -m http.server 8900
```

Open `http://<this-machine's-LAN-IP>:8900/` from your iPad/phone on the
same network.

**Real limitation right now: this is plain HTTP, not HTTPS.** Live
lighting control works fine over HTTP — WebSocket connections don't need
HTTPS. But the service worker (offline app-shell caching, full "Add to
Home Screen" install behavior) requires a secure context, which mobile
Safari does not consider a bare LAN IP to be. Service worker registration
will likely silently fail on a real device until this is hosted over real
HTTPS — that's Phase 4 in the spec, not done yet. Test the actual lighting
control in mobile Safari now; treat "installed as an app" as not fully
working until real hosting is set up.

## What hasn't been verified at all

- Never opened on a real iPad or iPhone — built and syntax-checked
  (`node --check`) on this Mac only, no jsdom/browser runtime available in
  this environment to catch DOM/runtime bugs before a real device does.
- No responsive/phone-specific layout pass yet — this is the tablet-sized
  mockup as-is, phone rendering is untested and likely needs real
  adjustment (Phase 5 in the spec).
- Color wheel → `hs_color` service call payload shape is written to match
  HA's documented API but not confirmed against a real color-capable light
  responding correctly.

First real open on a device should be treated as a debugging pass, same
discipline as the native Pi app's first run — report back whatever breaks.
