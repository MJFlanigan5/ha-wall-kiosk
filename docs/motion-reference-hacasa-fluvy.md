# Motion and surface reference: HaCasa Nova and Fluvy

Captured 2026-11-07 from the live HA instance (HaCasa Nova v3.1.0, Fluvy frontend 1.16.0), by reading computed styles
and `@keyframes` from each panel's DOM. Purpose: one shared motion language for Foyer and Kith.

These are observed values, not copied code. HaCasa is MIT and builds on the Homio design by iamtherufus; I have not checked
Fluvy's license, so treat Fluvy as visual reference only until that is confirmed.

Recording: `hacasa_nova_wizard_and_room_switch.gif` (in the browser Downloads folder), 39 frames: setup wizard, room switch.

## HaCasa Nova

**Feel:** large editorial type on a photo or gradient, frosted glass cards, soft spring-ish ease, content rises in.

| Token | Value |
|---|---|
| Main easing | `cubic-bezier(0.2, 0.7, 0.2, 1)` (fast start, long soft settle) |
| Entrance (`rise`) | opacity 0 to 1, `translateY(16px)` to 0, **0.55s**, stagger **0.06s per card** (0, .06, .12, .18, .24), later groups at 0.30s |
| Smaller entrance (`up`) | `translateY(10px)`, header bar `downT` 0.5s, bottom strip `upT` 0.6s |
| Hover/press | background, color, transform **0.15s ease**; card transform/background/border **0.25s** main easing |
| Height changes | **0.15s ease** |
| Page and popup | opacity and transform **0.45s**; panel transform **0.5s**; exits: `popOut`, `menuOut`, `viewOut`, `fadeOut` |
| Background | slow Ken Burns: `kb` scale 1 to 1.045 |
| Icon feedback | `iconPop`: scale 1, 1.22 with -4deg at 35%, 0.96 at 70%, 1 |
| Confirm | `checkPop`: scale 0.4 and -20deg to 1.15 and 4deg at 60% to rest |
| Active nav item | `tabBump`: scale 1, 1.15 at 40%, 1 |
| Toast | `toastIn`: `translate(-50%, 18px) scale(.96)` to rest |
| Loading | `shimmer` (background-position sweep), `breathe` (opacity .35 to .9), `pulse` (white ring, 0 to 8px) |
| Status | `blink` amber dot with glow, `drift`, `fanspin`; weather has its own set (`w-*`, `sk-*`) |

**Surfaces (glass):**
- Pill nav and status: `backdrop-filter: blur(20px) saturate(1.3)`, fill `rgba(255,255,255,.10)`, 1px border `rgba(255,255,255,.14)`, radius 999px
- Cards: `blur(16px) saturate(1.2)`, fill `.10` resting and `.34` to `.40` when on, 1px border `.14` resting and `.38` when on, radius 8px
- Popup/menu: `blur(16px)`, fill `.14`, radius 14px
- Page title: Hanken Grotesk, 92px, weight 600, letter-spacing -3.2px
- Dimmer: vertical slider on the card edge plus 25/50/75/100 preset pills

## Fluvy

**Feel:** dark Material-style surface, flat tiles, tight, quick, almost no decoration.

| Token | Value |
|---|---|
| Main easing | `cubic-bezier(0.2, 0, 0, 1)` (Material emphasized) |
| Entrance (`fv-enter`) | opacity 0 to 1, `translateY(8px) scale(.985)` to rest, **0.42s**, easing `cubic-bezier(0,0,0,1)` |
| Press/hover | transform, scale, background **0.12s** |
| Color changes | **0.18s** |
| Opacity fades | **0.18s** |
| Icon bump (`fv-pop`) | scale 1, 1.1 at 45%, 1 |
| Text swap (`fv-swap`) | opacity 0 and `translateY(3px)` to rest |
| Menu in (`fv-menu-in`) | `scale(.98) translateY(-4px)` to rest; out is a plain fade |
| Gauge/line draw | `fv-draw` (stroke-dashoffset 1 to 0), `fv-grow-x`, `fv-grow-y` |
| Idle | `fv-shimmer` (opacity .45 to 1), `fv-sweep` (360 degree rotate) |

**Surfaces:** no blur. Flat dark tiles, radius 20px, 1px inset ring (`rgb(47,49,55)` resting), round icon chips (50%), Inter.

## Side by side

| | HaCasa | Fluvy |
|---|---|---|
| Entrance | 16px rise, 0.55s, 60ms stagger | 8px rise plus .985 scale, 0.42s |
| Press | 0.15s to 0.25s | 0.12s |
| Easing | long soft settle | crisp, Material |
| Depth | blur and translucency over imagery | flat tiles, rings, no blur |
| Type | large, tight, 92px headline | small, regular, Inter |

## Suggested shared tokens for Foyer and Kith (proposal, not applied)

- Easing: `cubic-bezier(0.2, 0.7, 0.2, 1)` for entrances and panels; `cubic-bezier(0.2, 0, 0, 1)` for small controls
- Durations: press 120ms, color 180ms, small entrance 420ms, panel or popup 500ms
- Entrance: `translateY(12px)` plus opacity, **50ms stagger**, cap the stagger at 6 items so wall tablets never feel slow
- One feedback pop: scale 1.1 over 350ms for any state change (light on, fan on)
- Keep glass for Foyer (wall kiosk, large photo or gradient backgrounds), keep flat tiles for Kith (dense lists), but share radii, easing and timing so they feel like one product
- Respect `prefers-reduced-motion` in both

## Not captured

- Light popup (HaCasa): clicking the card body did not open it, and I did not press further because the lights are live.
- Fluvy interactions (menu, popup) were extracted from CSS only, not recorded.
