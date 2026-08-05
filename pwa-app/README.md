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

## Ambient Mode (added 2026-08-05)

After 90 seconds of no touch, the app drops into a full-screen idle view —
clock, date, and one quick-action button per wired room (toggles all of
that room's lights). Any tap anywhere wakes back to whatever screen was
showing before. See [`docs/UI_MODES_SPEC.md`](../docs/UI_MODES_SPEC.md)
for the design reasoning (Loxone Wall Display comparison). Not tested on
a real device yet, same caveat as everything else below.

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
