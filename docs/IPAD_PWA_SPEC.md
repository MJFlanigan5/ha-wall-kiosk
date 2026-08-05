# iPad PWA Spec

The same Savant-styled control experience as the wall panel, but for iPad —
via a PWA wrapping the existing HTML mockup, not a port of the Pi native
app.

**Status: not started, spec only.**

## Why PWA, not a native port

- The Pi went custom/no-browser specifically because of the Pi 5 2GB memory
  ceiling. iPads don't have that constraint, so the reason "no browser"
  was worth the engineering effort on the wall panel doesn't carry over.
- The Pi app's backend is Python (PySide6), which doesn't run on iOS at
  all. Porting to Qt for iOS means rewriting the backend in C++; a native
  SwiftUI app means rewriting everything. Both are full second projects,
  not ports.
- The existing mockup is already fully designed and visually complete.
  Wrapping it as a PWA reuses finished work instead of re-implementing the
  same screens a third time (HA default → QML → SwiftUI).

## Current state (checked 2026-08-04)

Source: `savant-dashboard-mockup/index.html` (sibling project, not in this
repo), 2405 lines. **100% static** — zero `fetch`/`WebSocket` calls found,
every room/screen is mock content. Visual design is done; no live data
wiring exists yet.

## Phases

| Phase | What | Notes |
|---|---|---|
| 1 | JS HA WebSocket client | Auth via long-lived token, subscribe to `state_changed`, pull Area/Device/Entity registries — same job as this repo's `native-app/ha_client.py`, written in JS instead of Python |
| 2 | Wire live state into the existing DOM | Replace mock content per room/screen with real entity data, one screen at a time |
| 3 | Service calls | Write actions (toggle, dim, scenes) once the read path is solid |
| 4 | PWA wrapper | `manifest.json`, icons, service worker, full-screen "Add to Home Screen" mode |
| 5 | Real iPad testing | Safari, touch interactions, full-screen behavior, no browser chrome |

Phases 1 and 3 mirror the native app's phases 2 and 4. Phase 2 here is
lighter than the native app's screen-porting phase — the screens already
exist as finished HTML, this is data wiring, not UI construction.

## Design principle

Same discipline as the native app (see
[`NATIVE_APP_SPEC.md`](NATIVE_APP_SPEC.md)): config-driven, not hardcoded
to one home. HA URL, token, and area/entity selection come from config, not
baked into the JS. Credentials never touch this repo.

## Relationship to the native Pi app

Not a port of each other — two separate implementations of the same design
language, for two different hardware targets with different constraints.
Both should draw from the same design tokens (the mockup's CSS custom
properties), but no code is shared between them.

## When to actually start this

Not started. Sequenced after the wall-kiosk native app reaches a working
state end-to-end — same "prove the first one works before building the
second" discipline used throughout this project.
