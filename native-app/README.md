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

Ran a headless smoke test (`QT_QPA_PLATFORM=offscreen`, stub HA client, no
real connection) to catch load-time bugs before handing this off — no
visible window appears in that mode, so it can't confirm what this
actually *looks* like, but it did catch one real bug:

- **Fixed:** `Overview.qml` originally tried `import HaWallKiosk 1.0` to
  reach the `Theme` singleton, which failed (module not found via the
  configured import path). `Theme.qml` + `qmldir` live in the same
  directory as `Overview.qml`, so QML resolves the singleton
  automatically without an explicit module import — removed the bad
  import line, confirmed the fix loads cleanly.
- **Confirmed working:** window loads and resizes correctly for *both*
  orientations (1200×1920 portrait, 1920×1200 landscape, verified by
  reading back the actual `width`/`height` properties after load — not
  just "no crash"), `Theme` singleton resolves, `Repeater` renders
  against stub data, `AppConfig`'s `isPortrait` correctly drives both the
  window size and the area grid's column count.
- **Not fully resolved — a console warning, not a crash:** during headless
  runs, `haClient`/`appConfig` properties briefly evaluate as null in some
  binding passes, even though the final, measured state (window size,
  grid layout) is correct every time. This specific warning only shows up
  when running two QML engines back-to-back in one process, which only my
  test harness does — the real `main.py` creates exactly one engine, one
  time, so this may simply not apply to normal operation. Still can't
  fully rule it out without a real windowed run.
- **Not tested at all:** the actual HA WebSocket connection/auth/registry
  flow in `ha_client.py` — the smoke test used a stub client, not a real
  HA instance. Area/device/entity registry resolution (entities assigned
  to an area *via their device*, not just directly) is implemented per
  HA's real registry model but unverified against live data.

First real run should be treated as a debugging pass, not "should just
work." Report back what you see (or any tracebacks, or that console
warning showing up for real) and we'll fix from there.
