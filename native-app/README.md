# Native app (PySide6 + QML)

MVP phase (see [`docs/NATIVE_APP_SPEC.md`](../docs/NATIVE_APP_SPEC.md)):
`Theme.qml` + a live-data-connected Overview screen, no browser engine.
Config-driven — reads areas/entities from your Home Assistant instance's
own Area/Device/Entity registries, nothing hardcoded to one home.

## Setup

```bash
cd native-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cp config.example.yaml config.yaml
# edit config.yaml: set home_assistant.url to your instance, and either
# paste a long-lived access token into home_assistant.token, or leave it
# blank and export HA_TOKEN instead:
#   export HA_TOKEN="your-token-here"
```

Get a long-lived access token from Home Assistant: your profile (bottom
of the sidebar) → **Security** tab → **Long-lived access tokens** →
Create Token.

## Run

```bash
python main.py
```

Opens a window sized to `display.orientation` in `config.yaml` — 1200×1920
portrait (the Touch Display 2's native resolution) or 1920×1200 landscape
if you set `orientation: "landscape"` — showing every area Home Assistant
knows about, live-updating as entity states change. Connection status dot
top-right: gray = connecting, green = connected.

Orientation is a pure rendering decision here, not tied to the physical
panel — one real advantage of custom software over a browser-based kiosk.
The area grid also adjusts its column count for landscape, not just the
outer window size.

## Status / what's actually been verified

**First real run against a live HA instance (2026-08-06): confirmed
working.** Ran with a real long-lived access token against a large home
(hundreds of entities across dozens of integrations) — connected,
authenticated, and the area grid populated with real live data.

One real bug found and fixed on that first run:
- **Fixed:** `websockets.connect()` used the library's default 1MiB frame
  size limit. This instance's registry/state dump exceeds that easily
  (many entities, many integrations), so the connection authenticated
  then immediately dropped with `1009 (message too big)` and kept
  retrying forever. Fix: pass `max_size=None` in `ha_client.py`'s
  `_connect_and_listen()`. Confirmed clean connect + populated grid after
  the fix, no further errors.

Earlier headless smoke test (`QT_QPA_PLATFORM=offscreen`, stub HA client)
had already caught one load-time bug and confirmed layout/orientation
logic before this real run — see git history for that pass's notes if
needed; superseded by the real-run result above.

## Ambient Mode pass + write-action proof (2026-08-06)

Same session, moved past the plain area grid. Bounded scope, matching
this project's "prove one thing before templating" discipline — not the
full PWA Ambient Mode port (no brightness stepper, color presets,
day/night shift, or global Night/Day buttons yet, those are real PWA
features but bigger scope):

- **Clock + date header**, room cards now read "N of M lights on" instead
  of a raw entity dump.
- **First real write action, confirmed end-to-end**: tap a room card →
  `light.toggle` on every light entity in that area → verified against
  real HA state, not just the UI. Also fixed a real perf bug found in the
  process: `areasChanged` was firing on *every* state_changed event
  house-wide (hundreds of entities), rebuilding the whole grid each time
  — now only fires (debounced 150ms) when a tracked entity actually
  changes.
- **Real entity-curation bug found via live testing**: Master Bedroom's
  light count was wrong (6 shown, should be ~3-4) — HA's Area registry
  had picked up a UniFi switch's status LED (not a room fixture) plus
  duplicate entities from integration re-adds (confirmed via
  `get_device_details`: same physical Govee bulb, two live integrations
  both reporting it). Added `display.excluded_entities` in `config.yaml`
  as a stopgap (same evolutionary path the PWA took — hand-edited config
  first, real on-device picker later, not built yet).
- **Second connection added**: `homey_client.py`, a Python port of the
  PWA's `homey-client.js` (same minimal REST pattern — get/set device
  capability, polled not pushed), for the handful of real devices HA
  can't reach directly. Proven working end-to-end this pass (real read,
  real write, confirmed via Homey state). One genuine Homey-side bug
  surfaced in the process: a device bridged through Homey's
  `io.home-assistant` app 500'd on every write attempt — logged cleanly,
  didn't crash the app. `config.yaml`'s `homey.device_ids` is empty for
  now — Mike's swapping the Master Bedroom ceiling bulbs soon, so
  tonight's specific entity IDs will be obsolete shortly. Same discovery
  process (HA + Homey cross-check, confirm real vs. duplicate, verify via
  a real toggle) once the new hardware is in.

**Still not tested:** anything past this one screen — no other views, no
Pi hardware deployment, no visual port of the PWA's actual Ambient Mode
look (icons, rail nav, card polish — this pass proved the architecture,
not the visual design).
