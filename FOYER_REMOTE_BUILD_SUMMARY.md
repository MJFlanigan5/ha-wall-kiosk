# Foyer Remote Build Summary

## What was built

A new "Remote" rail item in `pwa-app/index.html`, added between Health and
Settings, following the existing rail-item conventions exactly (same
`data-room` routing pattern as Health/Settings/Sensors).

### Living Room Media (10 buttons)
Each button calls `window.homeyClient.triggerAdvancedFlow(flowId)` directly
against a real, already-built Homey Advanced Flow: Plex, Netflix, Disney+,
HBO Max, Prime Video, Hulu, YouTube, Movie (Apple TV), HDHomeRun, Spotify.

**Real correction to the original job spec**: the spec assumed these flows
lacked start nodes and would need new HA-side wrapper scripts calling
`rest_command.homey_webhook` (Option 2 in the spec). I checked all 10 flows
used here directly via the Homey API (`advanced_flows_get`) before writing
any code — all 10 have real `"start"` cards and report `"triggerable": true`.
So Option 1 (`HomeyClient.triggerAdvancedFlow(flowId)`, the exact pattern
already used for Vacation Mode and Morning Shower in the Settings page) is
what's actually wired up here — simpler than the spec assumed, and it's the
pattern that already exists in this codebase, so no new HA scripts were
needed for the media buttons.

### Quick Actions (3 buttons)
Each calls `window.haClient.callService("script", "turn_on", "script.<name>")`
against the three real, already-working HA scripts named in the spec:
`office_focus_mode`, `heading_out`, `utility_room_chore_tap`. This is the
exact same call pattern already used for `script.shower_prep_now` elsewhere
in this file (Power tab) — no new scripts, no new HA-side changes needed.

### Living Room Sony Bravia TV controls (added after initial merge)
Found that the Living Room Sony Bravia 7 is connected in Homey via a
**dedicated native Sony Bravia app**
(`homey:app:name.ricardoismy.sonybraviaandroidtv:sony-bravia-android-tv`),
not the generic Android TV Remote driver used elsewhere — confirmed live via
the Homey API, with a real PSK/IP already configured. This exposes real
capabilities the existing HA-based Living Room room page (media_player +
D-pad only) doesn't have: input switching (HDMI 1-4), audio output routing
(TV speaker / audio system / HDMI / speaker+HDMI), and a screen-off/ambient
mode. Added to the Remote page:

- Power toggle, mute toggle, volume +/- steppers, screen-off toggle
- Input tabs (HDMI 1-4) and audio-output tabs — all reflect real current
  device state, fetched via `homeyClient.getDevice()` on every render (not
  assumed/static), matching the app's existing philosophy (e.g. how Settings'
  Vacation Mode toggle reads the real logic variable rather than guessing).
- All write actions use `homeyClient.setCapability(deviceId, capability, value)`
  — an existing client method, not something new I had to build.
- Double-tap guards: power/mute/screen-off disable themselves immediately on
  click; the two volume steppers disable each other together to prevent
  stacked requests.
- Volume math rounds to 2 decimal places (caught and fixed a real floating-
  point precision issue during testing: naive addition produced
  `0.42000000000000004` sent to the real device API).

**Real edge cases tested via mocked render + click-through** (no real device
calls made): renders correctly with live-fetched real state (power/input/
audio-output all correctly reflected and highlighted); double-tap guards
verified to actually disable buttons synchronously on click; graceful
degradation confirmed for two real failure modes — `getDevice()` throwing
(Homey reachable but that one call fails) and `window.homeyClient` being
entirely absent (not configured on this device) — neither crashes the page,
both correctly render all Sony/media controls as disabled.

**One real, disclosed uncertainty**: `getDevice()`/`setCapability()` call
Homey's *local* device-manager REST API (`/api/manager/devices/device/...`),
which I have not been able to literally test against the real device in this
session (no device credentials in this workdir, and I didn't want to guess/
extract them). I'm inferring the response shape (`capabilitiesObj.<cap>.value`)
from Homey's standard Device object serialization, which the Homey Web/cloud
API (used elsewhere this session via MCP tools) confirmed matches exactly for
this specific device — high confidence, not a live-tested certainty.

## What was NOT built / left out

- No general lighting/climate controls were added to this page — the spec
  explicitly warned against duplicating controls that already exist
  elsewhere in the app (each room already has its own light/climate view),
  and I didn't find anything missing that this page needed to cover beyond
  media + the three quick-action scripts.
- No new icon was added for the individual media services (Plex/Netflix/etc
  logos) — buttons use plain text labels, matching the existing
  `switch-row`/`light-list` pattern used for Settings' Quick Actions and
  Homey Quick Actions sections (text-label buttons, not icon buttons).

## Verification performed

- `node --check` against the extracted inline `<script>` block: passes,
  exit code 0 — no syntax errors introduced.
- Confirmed `handleWriteError`, `.switch-btn`, `.switch-row`, `.light-list`,
  `.light-row-name`, and the `.flash` animation class all already exist in
  this file — nothing referenced that isn't real.
- Confirmed via live Homey API calls (not assumed) that all 10 of the media
  flow IDs used here have real, triggerable start nodes — every single one
  fetched individually via `advanced_flows_get` and checked for
  `"triggerable": true` and a real `"start"` card before being included.
- Not tested against the real running PWA in a browser (no way to load
  the live app and click through in this session) — the JS syntax is
  verified valid and follows established patterns exactly, but an actual
  click-through test in the browser would be the real remaining
  verification step.

## Files changed

- `pwa-app/index.html` — added `LIVING_ROOM_MEDIA_FLOWS`,
  `REMOTE_QUICK_ACTIONS` constants and `renderRemoteContent()` function;
  rail-item registration (added in an earlier overnight cron attempt,
  kept as-is: `ROOM_ORDER` entry, rail button, `renderContent()` routing
  case).
