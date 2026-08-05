# UI Modes Spec: Ambient, Active Control, Technical Status

Design direction from comparing our Savant-based approach against the
Loxone Wall Display 10" (2026-08-05 research, Loxone product page +
Mike's own comparison notes). Not picking one vendor's approach wholesale
— a hybrid, translated into concrete changes for this PWA.

## Source comparison (for context, not a spec itself)

**Savant TrueImage**: tap directly on a real photo of the room to control
the fixture shown in it — literal "touch the thing you want." Distributed
hardware model (touch panels + separate physical keypads). Admin lives in
a separate cloud product (Home Manager), subscription-gated.

**Loxone Wall Display 10"**: icon/shortcut-based, not photo-based. Local-
first, no login, no app-store dependency. **Ambient Mode**: up to 12
shortcuts + custom background + simplified glanceable view when idle —
distinct from the full active dashboard. Same hardware reframes itself by
context: whole-home overview, single-room control, or a technical/status
view. Admin folded into the same device, no separate portal.

## Decision: hybrid, not either vendor wholesale

1. **Keep photo-based active control** (Savant-style) as the long-term
   direction for room screens — but see "Deferred" below, this isn't built
   yet and the current list-based lighting UI stays the working baseline
   until it is.
2. **Adopt Loxone's Ambient Mode** for the idle/passive state — building
   this now, see below.
3. **Add a technical/status view**, separate from room control — smaller
   scope, expands what the footer's connection dot already started.
4. **Physical keypads vs. one hub** stays an independent hardware
   decision, not tied to this software.
5. **No subscription/cloud admin layer** — already true. This build is
   fully HA-native and self-hosted; there was never a Home-Manager-style
   cloud gate to remove.

## Ambient Mode (building now, 2026-08-05)

Auto-triggers after a period of no touch interaction. Replaces whatever
room screen was showing with a simplified glanceable view:

- Clock (already exists elsewhere in the app, reused here)
- A curated set of quick-action shortcuts (Loxone caps at 12 — reasonable
  ceiling to match, not a hard technical limit on our side)
- Custom/ambient background, not the full room-control chrome
- Any touch anywhere dismisses back to the last active room screen

Any live state change relevant to what's shown (a light left on, etc.)
still updates in the background — Ambient Mode is a different view of the
same live data, not a separate offline mode.

## Technical/status view (smaller scope, next after Ambient Mode)

Expand the footer's existing connection-status dot/text into a real
screen: HA WebSocket connection state, last state update time, per-room
entity health. Not built yet — the footer indicator is the seed of this,
not the finished version.

## Deferred: photo-based tap-target lighting control

**This is a content-authoring task, not primarily a coding one** — it
needs real photos of each actual room plus hand-placed tap zones
calibrated to exactly where each fixture appears in that specific photo.
The current mockup's `photoImg` paths are placeholders; the current
lighting screen is list-based (named switches/sliders), not
tap-the-fixture-in-the-photo. Keep the list-based control as the reliable
baseline. Revisit photo-tap as a visual enhancement layer once the app is
proven in daily use, not before.

## Physical install note (context, not a change here)

Loxone's flush wall-mount (cabling hidden, screen clicks into a slim
frame, no visible tablet edges) is the same physical direction this
project is already pursuing with the arm-locking mount — no change needed,
just confirms the existing hardware approach is aligned with this research.
