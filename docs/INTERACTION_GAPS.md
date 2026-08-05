# Interaction Gaps / Not Yet Speced

A catalog of interaction types the app will eventually need that don't
have a spec yet — so they don't get forgotten and rediscovered late.
Deliberately **not** full specs like `NOTIFICATIONS_SPEC.md` or
`MUSIC_SPEC.md` — most of these don't warrant that depth yet, either
because they're blocked on hardware/backend that doesn't exist, or because
they're genuinely a scope decision that hasn't been made. Promote an entry
to its own spec doc when it's actually about to be built.

## Live camera viewing (distinct from notification snapshots)

`NOTIFICATIONS_SPEC.md` covers a static camera *image* inside a doorbell
alert. Actually browsing live camera feeds on demand — full-screen view,
switching between cameras, a multi-camera grid — is a separate, bigger
technical problem (streaming, not a single image fetch). The README's
"Dashboard-side performance constraints" already caps concurrent live feeds
at ~4, which assumes this gets built eventually but doesn't say how.

## Climate / thermostat control

**Currently blocked, not just unspec'd** — per existing project notes, the
climate/water-heater side isn't HA-controllable yet (Homey-owned, not
exposed). This is a real Savant-style screen (dial interface, same pattern
as the pool/spa dial already in the HTML mockup) but there's nothing to
build against until the backend exposes it.

## Security panel / door locks

**Deferred, no hardware yet** — arm/disarm with code entry, sensor status
list, lock/unlock. Already tracked as deferred until the actual hardware
exists; listed here just so it's not lost when hardware does show up.

## Scenes / moods

Homey already has a real "moods" concept (activate/create/list) as a
backend capability — this is a legitimate quick-tap interaction ("Movie
Night," "Good Morning," "Away") that's cheaper to wire up than most of the
above since the backend piece already exists. Not yet decided how/where
this surfaces in the app (a dedicated row of scene buttons? per-room?).

## Kiosk exit / admin access

**Genuinely missed until now.** The wall panel is a full-screen always-on
kiosk — there's no spec anywhere for how you (the owner) get *out* of it
for maintenance without SSHing in every time. Needs some kind of
deliberately-hard-to-trigger-by-accident gesture or PIN-gated settings
screen. Worth deciding before the app is actually mounted on the wall, not
after.

## Idle behavior / screensaver / wake

Savant panels typically dim or show a screensaver (clock, photo) after
inactivity and wake on touch or presence. This project already has
presence sensing running for 8 rooms via Magic Areas — a natural fit for
wake-on-approach instead of wake-on-touch-only, but not decided or built.

## Voice / Assist

HA has its own voice pipeline (default "Hey Jarvis" wake word). Separate
question from the dedicated Voice PE hardware (which turned out to be
defective and was returned): does the *app itself* ever want a
push-to-talk/mic button that invokes Assist, independent of any dedicated
voice hardware? Not decided — flagging so it's a deliberate "not doing
this" if that ends up being the answer, not an oversight.

## Connection loss / degraded state

The native app's connection-status dot (gray/green, per
`native-app/README.md`) covers "connecting vs. connected," but not what the
rest of the screen does during a HA restart or network blip — stale data
with a "last updated" indicator? A full error takeover? Silent retry? This
matters more here than on a phone app, since a wall panel that just freezes
or blanks during a routine HA restart is a bad daily experience, not an
edge case.

## Other device domains not yet inventoried

Covers (garage doors, blinds/shades), vacuums, irrigation, and any other
entity domains that exist in the house but haven't come up in a spec yet.
Worth a real pass against the actual HA entity list once the native app's
Overview screen is live and pulling real data — easier to inventory what
actually exists than to guess here.
