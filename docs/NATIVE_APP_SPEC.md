# Native App Spec (deferred — not started)

This is a spec for replacing the browser-based kiosk (touchkio or a custom
Chromium/WPE wrapper) with a real native app — no browser engine at all,
the same approach Savant/Control4/Crestron actually use on their own touch
panels. **Not started.** Written up now so it's ready to pick up later,
after the browser-based setup is running and proven, and only if 2GB
performance genuinely turns out to be a problem in practice.

## Decision: PySide6 + QML (not Kivy, not raw Qt/C++)

| Option | Verdict |
|---|---|
| **PySide6 + QML** | **Chosen.** See reasoning below. |
| Kivy | Real alternative, pure Python, mature on Pi. Passed over because its KV markup language is a bigger conceptual jump from our existing HTML/CSS/JS than QML is — less of our existing design work translates directly. |
| Raw Qt/C++ | Smallest possible footprint, but adds a C++ build toolchain and a much steeper iteration loop for no real benefit over PySide6 at this scale. |
| PyQt6 | Same Qt/QML benefits as PySide6, but GPL or paid-commercial-license only. **Ruled out** — this repo is public and meant to be usable by others without a licensing catch. |

Why QML specifically:

- **Declarative + property-binding model** — a tree of components with
  bound properties and inline JS expressions. Structurally the closest
  match to how the existing HTML/CSS/JS mockup (`savant-dashboard-mockup`)
  is already built, of any native UI option.
- **Qt is what real embedded touch panels use.** "Qt for Device Creation"
  is marketed at exactly this product category — this is the same
  category of tool actual commercial touch-panel vendors build on, not an
  analogy.
- **GPU-accelerated via Qt Quick's scene graph**, well-suited to the Pi 5's
  VideoCore VII GPU. Baseline memory footprint is a fraction of a Chromium
  instance — tens of MB rather than hundreds, since there's no browser
  engine, no HTML/CSS parsing/layout engine, no JS engine running
  arbitrary web content.
- **PySide6 is LGPL** (the official Qt Company Python binding) — no
  licensing complication for a public repo, unlike PyQt6.

## Architecture

```
Home Assistant server (existing, separate machine — unchanged)
        |
        |  WebSocket API (wss://.../api/websocket) — auth via
        |  long-lived access token, subscribe to state_changed events
        |  for only the entities the dashboard actually uses
        v
Python backend (on the Pi)
  - HA client module: connects, authenticates, maintains the
    subscription, re-connects on drop
  - Exposes state to QML as Qt properties on QObject-derived classes
    (e.g. one class per "screen" or per entity group), emitting Qt
    signals when HA pushes a state_changed event
  - Service calls (turning things on/off, etc.) go back out over the
    same WebSocket connection or plain REST, triggered from QML via
    exposed Python slots
        |
        v
QML frontend (on the Pi, same process)
  - Theme.qml singleton: ports the mockup's design tokens (colors,
    fonts, radii, spacing) as QML properties — this is the direct
    equivalent of the CSS custom-property block in the current mockup
  - One .qml file per screen, mirroring the existing HTML mockup's
    screen list (Overview, room detail, quick actions, camera view,
    etc.) — layout structure ported screen-by-screen, not rewritten
    from a blank page
  - Bindings read directly from the Python-exposed properties above;
    UI updates automatically when HA pushes new state, no polling
```

## Suggested project structure

```
ha-wall-kiosk/
  native-app/
    main.py              # entry point, sets up QML engine + HA client
    ha_client.py          # WebSocket connection, auth, subscriptions
    models/                # QObject subclasses exposing HA state to QML
      area.py
      camera.py
      ...
    qml/
      Theme.qml           # ported design tokens
      Overview.qml
      RoomDetail.qml
      QuickActions.qml
      ...
    requirements.txt       # PySide6, websockets, etc.
```

## Porting plan (phased, matches how the HTML mockup itself was built)

1. **Theme.qml first** — port every design token from the mockup's CSS
   custom-property block. Verify it visually against the real mockup
   before building anything on top of it (same "prove one thing before
   templating" discipline used throughout this project).
2. **One real screen, fully wired to live HA data** — Overview is the
   natural first target, matching the existing mockup's structure.
   Confirm the WebSocket data flow actually works end-to-end (auth,
   subscribe, receive updates, render) before porting anything else.
3. **Remaining screens, one at a time**, screenshot-verified against the
   HTML mockup equivalent each time, same pattern as the rest of this
   project.
4. **Service calls last** — read-only display first, write actions
   (toggling lights, calling scenes, etc.) once the read path is solid.

## Honest scope

This is a real software project, not a config swap. Given the number of
screens already designed in the HTML mockup (area cards, quick actions,
camera feeds, room details, and whatever else "the whole thing" ends up
covering), this is realistically **weeks of part-time work**, not a
weekend. Treat it as its own project with its own plan when it's actually
started — don't back into it opportunistically off of a performance worry
that turns out to be unfounded once the browser-based setup is actually
running.

## When to actually start this

Only after:
1. The browser-based kiosk (touchkio, or the lighter custom wrapper) is
   running on the real hardware, and
2. It's demonstrated to actually be a problem in practice — not a
   theoretical 2GB concern, but an observed one.

If the browser-based approach works fine, this spec stays exactly what it
is: a spec, not a build.
