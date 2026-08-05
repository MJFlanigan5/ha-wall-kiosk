# Music / Media Player Spec

How Music Assistant (and whatever it's streaming from — Spotify, etc.)
actually gets controlled from the Savant-style apps. Media players are a
genuinely different entity shape than the toggles/sensors the rest of the
project has dealt with so far, so this gets its own spec.

**Status: not started, spec only.**

## Auth is simpler than it looks

Music Assistant owns the Spotify connection itself (via your own Spotify
Premium account, authenticated inside Music Assistant, not the app). From
the app's side this is just another `media_player` entity in HA — no
Spotify SDK, no separate Spotify auth flow, no API keys in the native app
or the PWA. Same WebSocket/token auth as everything else in
`NATIVE_APP_SPEC.md`.

## The nonobvious part: progress/scrubbing

HA does not push a continuously ticking "elapsed time." A `media_player`
entity's state includes `media_position` (seconds) and
`media_position_updated_at` (a timestamp) — a snapshot, not a stream. To
show a smoothly moving progress bar while a track is playing, the app has
to interpolate client-side:

```
elapsed = media_position + (now - media_position_updated_at)   # only while state == "playing"
```

This is the same pattern HA's own frontend uses. Getting it wrong looks
like either a frozen scrubber or one that drifts out of sync — worth
implementing correctly the first time rather than polling `media_position`
repeatedly (which HA doesn't push fast enough for anyway).

## Controls must respect `supported_features`

Not every player supports every control — seek, shuffle, and repeat depend
on the specific speaker and whether it's grouped. `media_player` entities
expose a `supported_features` bitmask; the UI needs to check it and hide
controls a given player doesn't actually support rather than assuming
every player is full-featured. Relevant service calls:

- `media_player.media_play` / `media_pause`
- `media_player.media_next_track` / `media_previous_track`
- `media_player.media_seek`
- `media_player.volume_set`
- `media_player.shuffle_set` / `repeat_set`

## Album art needs authenticated image fetches

`entity_picture` is a path through HA (not a public URL) — same pattern as
the doorbell camera image in `NOTIFICATIONS_SPEC.md`: fetch it with the
long-lived access token attached, don't treat it as a plain public image
URL.

## Open scope questions (not yet decided)

- **Multi-room / zone grouping.** Music Assistant supports joining/
  unjoining speakers into groups — this is one of Savant's actual
  signature features (whole-home audio zones). Are we building room
  selection and grouping, or just transport controls on whatever's
  already playing in one place? Real scope decision, not a technical
  detail — affects how much of the "Global Now Playing hub" screen (already
  built in the HTML mockup, see `renderMusicContent`) needs real backing
  logic vs. just a single active player.
- **Search/browse.** Picking a new song, artist, or playlist from Spotify's
  catalog requires Music Assistant's browse/search API — a materially
  bigger feature than controlling what's already playing. Decide whether
  this is in scope for v1 or deferred (e.g., v1 = control + room selection
  only, browse/search added later once the base is working).

## Sequencing

Not started. Same rule as the other specs: resolve this after the wall
panel native app has a working baseline (steady-state display + basic
service calls) — media player control is a distinct, more complex entity
type to add once the core app architecture is proven, not something to
build in parallel with the MVP.
