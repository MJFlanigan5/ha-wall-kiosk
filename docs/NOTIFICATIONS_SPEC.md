# Notifications & Interrupt Events Spec

How doorbell rings, finished timers, alarm state changes, and similar
"attention now" events actually reach and render on the Savant-style apps
(wall panel + iPad) — as opposed to normal steady-state entity updates,
which the WebSocket state subscription already handles.

**Status: not started, spec only. Design direction below, not yet built.**

## Two different problems, not one

**Wall panel (Pi) — no new infrastructure needed.** The native app already
holds a persistent WebSocket connection to HA for normal state updates
(see `native-app/ha_client.py`). A doorbell press, a finished timer, an
alarm state change are just `state_changed` events on entities it can
already subscribe to. The hard part here isn't delivery — it's the UI
pattern: does the event take over the whole screen, show as a dismissible
banner, or something in between. See "Event types and treatment" below.

**iPad — a real gap.** A PWA can be backgrounded or the device locked, so
it can't rely on "always has an open socket" the way the wall panel does.
Getting an event to the user when the app isn't in the foreground requires
actual push notifications: Web Push (VAPID keys), supported by installed
iOS PWAs since iOS 16.4. That means running a small push server — genuine
new infrastructure, not just more app code. Not solved here; flagged so it
doesn't get discovered late.

## Design principle: automations stay in HA/Homey, the app just renders

"When to notify" logic (a doorbell press should trigger an alert; a
low-priority sensor change shouldn't) already belongs in HA/Homey
automations — don't duplicate that logic inside the app. The app should be
a generic renderer for a structured event, not a place where per-device
conditional logic lives. This matches the project's existing config-driven
principle (see `NATIVE_APP_SPEC.md`): the app shouldn't need to know
"doorbell → show camera," it should know "priority: high, has image →
takeover screen."

## Event contract (proposed)

Reuse HA's own convention for this rather than inventing a new one — the
official Companion App's `notify.mobile_app_*` service already has a
proven rich-payload shape (title, message, image, priority, actions).
Automations fire a structured event with:

```yaml
title: "Front Door"
message: "Someone's at the door"
image_url: "http://homeassistant.local:8123/api/camera_proxy/camera.front_door"
priority: high   # low | normal | high
entity_id: binary_sensor.front_door_doorbell
actions:
  - label: "Dismiss"
    service: none
  - label: "View camera"
    service: none  # opens the camera detail screen
```

Both the wall panel and iPad render the same payload shape the same way —
no per-event-type app code, just a priority → UI-pattern mapping (below).

## Event types and treatment (to decide, not yet decided)

| Priority | Example | Likely treatment |
|---|---|---|
| High | Doorbell, alarm triggered | Full-screen takeover, camera image if present, requires explicit dismiss |
| Normal | Timer finished | Banner/toast, auto-dismiss after N seconds, tap to expand |
| Low | Routine state change | No interrupt — normal tile update only, no event fired at all |

Exact banner vs. takeover boundaries, auto-dismiss timing, and whether
multiple simultaneous events stack or replace each other are open design
questions — resolve these once the base app (Pi native app phase 2) is
working, not before.

## What's needed for iPad specifically

- A small self-hosted Web Push server (VAPID keys) — HA doesn't provide
  this out of the box for arbitrary PWAs the way it does for its own
  Companion App via Nabu Casa/HA Cloud
- Service worker in the PWA to receive and display push notifications
  while backgrounded
- A bridge from "HA automation fires the event contract above" to
  "push server sends it to the registered PWA" — likely a small
  webhook/script HA calls, not something HA does natively for this case

## Sequencing

Not started. This depends on both the wall panel native app and the iPad
PWA reaching a working baseline first (steady-state display + service
calls) — interrupt events are a layer on top of a working app, not
something to build in parallel with the base app.
