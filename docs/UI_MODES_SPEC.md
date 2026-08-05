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

**Confirmed directly (2026-08-05) against a live Loxone demo instance and
the product marketing page, not just written material:**

- The demo app's actual nav is 4-way: **Favorites** (curated cross-cutting
  status cards — icon, location label, a live value as headline, a
  description underneath), **Central** (whole-house bulk actions per
  category — all lights off, all shades, etc.), **Räume** (browse by
  room — what our rail nav already is), **Kategorien** (browse by domain
  across the whole house — all lighting everywhere, regardless of room).
  Only Favorites is worth adopting now; Central and Kategorien are
  legitimate but lower-value, skipped for now rather than building all
  four nav modes at once.
- The product page's hero image shows Ambient Mode and Favorites-style
  quick-status tiles **combined into one view**, not two separate
  screens — floating cards (climate with +/- controls, a mode toggle, a
  light's brightness) sit directly over the clock/weather background,
  alongside energy/CO2/presence tiles, all visible without navigating
  anywhere. That's a better structure than treating them as separate
  screens — see the revised Ambient Mode section below.

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

## Ambient Mode v1 (built 2026-08-05, first pass)

Auto-triggers after 90s of no touch interaction. Clock, date, and one
quick-action button per wired room (toggles that room's lights). Any tap
wakes back to the previous screen. Live in `pwa-app/index.html`.

## Ambient Mode v2 (revised direction, 2026-08-05 — build next)

**Merge the status-card layer directly into Ambient Mode, not a separate
Favorites screen.** Confirmed against Loxone's own product marketing image
that their idle/ambient view already includes live status tiles overlaid
on the clock — not a bare clock you then have to navigate away from to see
anything useful. Revised Ambient Mode:

- Clock + date (unchanged from v1)
- A curated set of Loxone-style status cards around/below the clock: icon,
  a short location/context label, a live value as the headline (matches
  the card pattern seen on the live demo's Favorites view — e.g. a room's
  current light state, an energy reading, presence status), tap-through to
  the relevant detail screen
- Our own dark palette and visual weight, not Loxone's green branding —
  adopting the card *structure*, not their skin (Mike's call, and the
  right one — the whole thesis of this project is a more premium visual
  language than a generic DIY dashboard)
- Cap the curated set at a reasonable number (Loxone caps Favorites at a
  handful of cards — match that spirit, not a hard technical limit)

**This also answers the deferred photo-tap-target problem** (see below) —
a status-card grid gives the same "glanceable, tap to act, feels premium"
quality as Savant's TrueImage photo-tap concept, without needing real room
photography or hand-placed hotspots. Not a replacement for that idea long
-term, but a much cheaper way to get most of the value now.

**Explicitly not building now:** Central (bulk category actions) and
Kategorien (cross-room domain browsing) nav modes — legitimate patterns
seen on the live demo, but lower priority than getting one good merged
Ambient/Favorites view working first.

### Follow-up fixes, same day (2026-08-05)

- **Admin access from Ambient Mode itself.** The admin gear originally
  only lived in the room screens' footer, which Ambient Mode's full-screen
  overlay completely covers — meant tapping to wake first, then finding
  the gear, just to reach config. Since Ambient is meant to be the screen
  that's up most of the time, added a small, low-opacity gear directly on
  the Ambient overlay (bottom-right, same restrained treatment as the
  "tap anywhere to wake" hint) so admin is one tap away, not two.
- **Room screens no longer "fight" Ambient Mode's style.** Real user
  observation after seeing both side by side: the room-screen header was
  still the old "TrueImage" hero — an empty gradient placeholder literally
  labeled for a photo that was never built (see "Deferred" below), sitting
  right above a functional control list. Next to Ambient's confident card
  layout, that empty box read as unfinished and made the app feel like two
  different systems. Fix: `renderHero()` now reuses the *exact* `.ambient-
  card` component instead of the image placeholder — a small status-card
  row (Lighting always, Music if a player's assigned) at the top of every
  room screen. Same component, two places — one visual language across the
  whole app instead of an idle-screen skin bolted onto an unrelated control
  screen. This is the concrete resolution of "steal the layout" from
  earlier: not just Ambient Mode borrowing Loxone's card pattern, but that
  pattern becoming this app's actual shared design system.

## Admin Mode (not started — next up)

Loxone's Wall Display folds first-setup *and* later config changes into
the same device ("Admin Mode"), no separate portal. Real gap in our build
right now: `rooms.config.js` is a hand-edited file — adding a room or
entity, or changing what shows in Ambient Mode, means editing code and
redeploying, not something doable on-device. That directly blocks the
earlier "generic enough for anyone" goal too, not just convenience for us.

**What it needs to actually work:**
- An on-device screen to add/remove/reorder rooms and entities, browsing
  HA's real Area/Entity registries (same live data `ha-client.js` already
  pulls) rather than typing entity_ids by hand
- Choose which rooms/entities appear as Ambient Mode status cards
- Basic look/feel toggles (not a full theme editor — scope this small
  first)

**Real technical wrinkle:** a browser can't write back to `rooms.config.js`
on disk. The static file becomes the *shipped default*, and Admin Mode
changes get persisted to `localStorage` (same mechanism `config.js`
already uses for the HA URL/token) — an override layer on top of the
default, not a replacement for it. This also directly serves the
"generic enough for anyone" goal from earlier: someone else's install
would start from the same defaults and use Admin Mode to point at their
own rooms, instead of hand-editing a JS file.

Not built yet — real scope, not a quick add. Sequence after Ambient Mode
v2 is confirmed working, not built in the same pass.

## Technical/status view (smaller scope, still after Ambient Mode v2)

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
