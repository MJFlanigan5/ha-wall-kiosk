# Native App Spec

Replacing the browser-based kiosk (touchkio or a custom Chromium/WPE
wrapper) with a real native app — no browser engine at all, the same
approach Savant/Control4/Crestron actually use on their own touch panels.

**Status: MVP phase (1 + 2) in progress**, building for personal use
regardless of whether the browser-based kiosk turns out to need it —
Mike's choice, not a performance-driven trigger anymore. Phases 3+ remain
deferred/incremental — add screens as needed rather than porting
everything up front.

## Design principle: config-driven, not hardcoded to one home

This is meant for other people to actually run against their own Home
Assistant instance, not just Mike's. That means:

- **No hardcoded room names, entity IDs, or area lists in code or QML.**
  A `config.yaml` (gitignored where it holds real values; a
  `config.example.yaml` checked in as a template) supplies the HA URL,
  auth token, and which areas/entities to show.
- **Prefer pulling structure from HA itself** (its Area registry, entity
  `area_id` assignments) over a hand-maintained room list, so someone
  else's existing HA organization "just works" rather than requiring them
  to redeclare their whole house in a second config format.
- **Credentials never touch this repo.** Long-lived access token lives in
  a local config file or environment variable, excluded via `.gitignore`,
  same discipline as the MQTT credentials note in the main README.

## Phases and time estimate

Estimated part-time (evenings/weekends), matching this project's pace:

| Phase | What | Estimate | Status |
|---|---|---|---|
| 1 | `Theme.qml` — port every design token from the mockup's CSS | 2-4 hours | **In progress** |
| 2 | HA WebSocket client + one working screen (Overview) end-to-end, live data | 3-7 days | **In progress** |
| 3 | Remaining screens (~15-25, ported one at a time from the HTML mockups) | 4-8 weeks | Not started |
| 4 | Service calls (write actions) on each interactive screen | rolled into 3 | Not started |
| 5 | Hardware testing + touch/perf polish on the real Pi | 3-5 days | Not started |

MVP (phases 1-2, plus a handful of the most-used screens) is realistically
**1-2 weeks** total. Full port of everything designed so far is **6-10
weeks**. Add screens incrementally after the MVP proves the architecture
works — don't try to port everything before using it for real.

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
