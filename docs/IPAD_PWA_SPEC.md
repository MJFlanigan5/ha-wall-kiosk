# iPad + Phone PWA Spec

The same Savant-styled control experience as the wall panel, but for iPad
*and* phone — via a single PWA wrapping the existing HTML mockup, not a
port of the Pi native app.

**Status: MVP in progress (2026-08-05).** Phases 1-4 have a first pass —
live HA WebSocket client, 3 rooms' lighting wired to real data and real
service calls, PWA wrapper (manifest + service worker). Not yet tested on
a real device, no responsive/phone pass, most screens still mock content.
See [`pwa-app/README.md`](../pwa-app/README.md) for exactly what's
verified vs. not.

## Phone comes with iPad, not as a separate build (2026-08-05)

Because this is HTML/CSS, not a platform-native UI toolkit, the same PWA
codebase serves both iPad and phone — there's no second app to build, just
responsive breakpoints so layout adapts to a narrower screen. This is not
free, though: the mockup's CSS was built tablet-first (multi-column
layouts, larger touch targets), so a real responsive pass — narrower
columns, phone-appropriate touch targets, possibly a different nav pattern
on small screens — is genuine work, called out as its own phase below. The
win is architectural (one codebase, one data layer, one deploy), not "zero
extra effort."

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

## Phases and time estimate

Estimated part-time (evenings/weekends), matching this project's pace —
meaningfully faster than the native Pi app because the screens are already
fully built HTML, not something being constructed from scratch:

| Phase | What | Estimate |
|---|---|---|
| 1 | JS HA WebSocket client — auth via long-lived token, subscribe to `state_changed`, pull Area/Device/Entity registries (same job as `native-app/ha_client.py`, in JS instead of Python) | 1-2 days |
| 2 | Wire live state into the existing DOM — replace mock content per room/screen with real entity data, one screen at a time | 3-7 days |
| 3 | Service calls — write actions (toggle, dim, scenes) once the read path is solid | 2-4 days |
| 4 | PWA wrapper + hosting — `manifest.json`, icons, service worker, full-screen "Add to Home Screen" mode; requires HTTPS hosting for service workers/installability (self-hosted, Mike's own infra) | 1-2 days |
| 5 | Responsive pass for phone + real device testing — narrower breakpoints, phone-appropriate touch targets, tested on both real iPad and real phone | 3-5 days |

**Total: roughly 2-3 weeks part-time.** Phases 1 and 3 mirror the native
app's phases 2 and 4. Phase 2 here is lighter than the native app's
screen-porting phase — the screens already exist as finished HTML, this is
data wiring, not UI construction. Phase 5 is new versus the original
iPad-only version of this spec, since phone support widens the testing
surface.

## Design principle

Same discipline as the native app (see
[`NATIVE_APP_SPEC.md`](NATIVE_APP_SPEC.md)): config-driven, not hardcoded
to one home. HA URL, token, and area/entity selection come from config, not
baked into the JS. Credentials never touch this repo.

## Notification styling — content yes, OS chrome no

Once `NOTIFICATIONS_SPEC.md`'s Web Push piece is built, this PWA's own
notifications are fully ours to style: icon, image, title, body, and
action buttons all render from content our own service worker controls.
What's **not** stylable: the OS-level notification banner shape and button
layout itself — that's Apple's system UI, the same for every app, PWA or
native. Separately, this doesn't apply at all to HA's own official
Companion App notifications (if that's ever used instead/also) — that's a
different app entirely, with its own fixed UI we have no access to.

## Relationship to the native Pi app

Not a port of each other — two separate implementations of the same design
language, for two different hardware targets with different constraints.
Both should draw from the same design tokens (the mockup's CSS custom
properties), but no code is shared between them.

## Sequencing: build this first (2026-08-05)

**Reversed from the original plan.** This now comes *before* the native Pi
app, not after — the reason for the original ordering (prove one thing
works before building the second) doesn't actually favor the Pi app here.
The PWA doesn't depend on any unfinished hardware: no mount, no Pi
assembly, no NVMe boot. Mike can self-host it today and use/test it on his
own iPad and phone immediately, giving real usage feedback while the
physical build is still in progress. The native Pi app stays blocked on
hardware regardless of which one is "spec'd first," so there's no
downside to building the thing that's actually testable right now.
