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
