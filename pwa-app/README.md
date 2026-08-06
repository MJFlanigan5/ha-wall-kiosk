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

## Ambient Mode (v2, updated 2026-08-05)

After 90 seconds of no touch, the app drops into a full-screen idle view —
clock, date, and status cards: one per wired room (icon, name, "N of M
lights on"), a Music card (whichever room's assigned player is actively
playing, if any), and a Home Power card (real Tesla Powerwall load sensor,
`sensor.my_home_load_power` — confirmed to exist live before adding it,
not fabricated). Styled after Loxone's Favorites card pattern but merged
directly into the ambient/idle view rather than a separate screen, in our
own dark palette rather than Loxone's. Tapping a room card toggles its
lights; Music/Power cards are read-only for now. Tapping anywhere else
wakes back to whatever screen was showing before. See
[`docs/UI_MODES_SPEC.md`](../docs/UI_MODES_SPEC.md) for the full design
reasoning. Not tested on a real device yet, same caveat as everything else
below.

**Service worker fixed (2026-08-05):** it was shipping cache-first with a
cache name that never got bumped across any of tonight's pushes — every
push after the first was silently invisible on reload. Rewritten to
network-first (cache is now just an offline fallback), so a reload always
gets the latest code when online.

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

## What's still mock content

Every other screen (climate, media, security, cameras, shades, energy,
pool/spa, video/AppleTV, message center) — unchanged from the original
mockup, still fake data. Climate specifically isn't wired because **no
climate entities exist in this HA instance yet** (verified live via
`search_entities`, not assumed) — that's a backend gap, not something this
app can fix.

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
