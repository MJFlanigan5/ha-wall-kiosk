# HA Wall Kiosk

A wall-mounted Home Assistant control panel: Raspberry Pi 5 + official 10.1"
Touch Display 2 (portrait), running **Foyer** — the same PWA used on iPad
and phone (see [`pwa-app/`](pwa-app/)) — in Chromium kiosk mode, in a
3D-printed arm-locking flush mount.

**Architecture decision, revised 2026-08-07:** this repo originally
planned a from-scratch native app (PySide6 + QML, no browser engine —
still documented at [`docs/NATIVE_APP_SPEC.md`](docs/NATIVE_APP_SPEC.md),
now parked, not deleted) specifically to avoid a browser engine's memory
footprint on the 2GB tier. That tradeoff no longer holds: Foyer has since
grown into the actual, working app (real Discovery, Climate, Sensors,
Quick Actions, notifications — none of which exist in the native app,
which never got past a stub-client smoke test), and a real perf pass
was done on Foyer specifically with this device's RAM ceiling in mind
(see "Dashboard-side performance constraints" below). Maintaining two
separate apps for the same dashboard stopped being worth it once one of
them was this far ahead. The Pi now runs the same app as iPad/phone —
one codebase, one data layer, one deploy.

This repo has both halves of the build: the physical mount (`hardware/`) and
the Pi/software setup (`scripts/` + this README). The dashboard itself
(`pwa-app/`) is a sibling directory in the same repo, not duplicated here.

**Built and tuned for the Pi 5 2GB tier on purpose** — not just because
that's what this build happens to use. The 4GB/8GB Pi 5 boards cost roughly
double the 2GB model, and there's no reason this project should push anyone
toward the pricier tier if 2GB runs it fine. Every setup and dashboard
choice here (see "Performance tuning" and "Dashboard-side performance
constraints" below) is made assuming the cheapest Pi 5 you can buy — if you
have a 4GB/8GB board, it'll just have more headroom to spare.

## Status / what's left

**Foyer (`pwa-app/`) is the app for all three surfaces now — iPad, phone,
and this wall panel.** It's real and working: live HA WebSocket client,
generic device Discovery (rooms, Climate, Video/TV remotes, Quick
Actions), real Sensors/Energy History/Notifications, Docker + Basic
Auth hosting. See [`pwa-app/README.md`](pwa-app/README.md) for the full,
current state.

**Physical (the only thing actually blocking the Pi build):**
1. Finish the mount — right side printed and working; left side needs a
   fix where the wall stud leaves zero cavity clearance for the arm-lock
   clamp (handled directly on the printed piece — drill/adhesive — not a
   frame redesign)
2. Assemble Pi 5 + POE HAT + NVMe SSD + Touch Display 2
3. Bootstrap NVMe boot (temporary SD card pass, see below)

**Software setup for the Pi (see "Software setup" below for the actual steps):**
4. `scripts/01-pi-kiosk-prep.sh` — 2GB tuning, zram, autologin
5. Chromium kiosk-mode autostart pointed at Foyer's URL — written below,
   **not yet verified against real hardware** (the Pi hasn't arrived as
   of this writing) — treat the exact autostart config/flags as the
   best-known starting point, not confirmed-working, until tested.
6. Confirm touch input, screen blanking staying off, and real memory
   headroom (`free -h`) once it's actually running.

**Parked, not deleted:** the from-scratch native Qt/QML app
([`docs/NATIVE_APP_SPEC.md`](docs/NATIVE_APP_SPEC.md),
[`native-app/`](native-app/)) — kept in the repo since it's real prior
work, not resumed unless Foyer-in-a-browser turns out not to fit the
2GB budget well in practice.

## Hardware

| Part | Notes |
|---|---|
| Raspberry Pi 5 (2GB) | [Pi Shop listing](https://www.pishop.us/product/raspberry-pi-5-2gb/) — DSI-only compatible, does **not** work with Pi 4/3/Zero |
| Raspberry Pi Touch Display 2 — 10.1" Portrait | [Pi Shop listing](https://www.pishop.us/product/raspberry-pi-touch-display-2-10-1inch-portrait/) — overall 161.8 × 247.3mm, active area 135.4 × 216.6mm, 1200×1920 native portrait |
| Waveshare POE M.2 HAT+ | [Product page](https://www.waveshare.com/poe-m.2-hat-plus.htm) — M.2 2230/2242 support, PCIe Gen2/3, includes its own fan + heatsink. **Do not also install the official Pi 5 Active Cooler** — this HAT isn't compatible with it and brings its own cooling. |
| WD SN740 256GB NVMe SSD (M.2 2242) | Boots the Pi directly — no microSD needed once set up, meaningfully faster than SD, especially for swap under memory pressure on the 2GB board |
| PoE switch or PoE injector (802.3af/at) | Required to actually use the HAT's PoE power — powers the whole Pi (5V/4.5A via GPIO) over the Ethernet cable, no separate USB-C supply needed. Skip this row and use the official Pi 5 USB-C PSU instead if you're not running PoE. |
| microSD card (temporary) | 8GB+ — only needed briefly during setup to bootstrap NVMe boot (see below), can be removed afterward |
| PETG filament | mount is designed for PETG (see Printables source below) |

Original mount design: [Home Assistant Wall Display — Raspberry Pi Touch
Display 2](https://www.printables.com/model/1405500-home-assistant-wall-display-raspberry-pi-touch-dis)
by The Stock Pot (Arm Locking Version), resized in Fusion 360 from the
original 7" Touch Display 2 footprint to the 10.1" panel's real dimensions.
Outer frame and cutting guide were non-uniformly scaled to the display's
official **Overall Dimensions** (161.8 × 247.3mm); the locking arm and screw
support hardware were left at their original size (they interface with
generic screws, not the screen) and repositioned to the new, larger frame's
four corners.

### Print files (`hardware/`)

| File | Qty | Notes |
|---|---|---|
| `Frame_10.1in.stl` | 1 | Outer frame |
| `Cutting_Guide_10.1in.stl` | 1 | Drywall cutting template, same footprint as Frame |
| `Screw_Support_A.stl` | 2 | Top-left & bottom-right corners |
| `Screw_Support_B_mirrored.stl` | 2 | Top-right & bottom-left corners |
| `Clamping_Arm_A.stl` | 2 | Pairs with Screw_Support_A |
| `Clamping_Arm_B_mirrored.stl` | 2 | Pairs with Screw_Support_B_mirrored |
| `HA_Wall_Display_ArmLocking_10.1in.f3d` | — | Full Fusion 360 archive of the resized assembly, for reference/further edits |

Print PETG, no supports needed except where noted on the original Printables
page. Cut the wall opening using `Cutting_Guide_10.1in.stl` as a template —
suits 10–15mm plasterboard.

## Software setup

### 1. Assemble the hardware

Mount the SN740 (2242) into the Waveshare POE M.2 HAT+, attach the HAT to
the Pi 5 via its 16-pin PCIe FFC cable (not the GPIO header — that's
separate), and connect the DSI ribbon + GPIO power cable from the display.
Don't install the official Pi 5 Active Cooler — the HAT's own fan/heatsink
takes its place.

If you're powering over PoE: connect Ethernet to a PoE switch/injector and
skip the USB-C supply entirely. Otherwise use the official Pi 5 USB-C PSU.
PoE delivers power *through* the Ethernet cable, so it's a package deal —
this also means the Pi is wired, not Wi-Fi, whenever it's PoE-powered.
That's a plus for a permanently wall-mounted device: no dropouts, and a
stable IP for SSH (see below) rather than a Wi-Fi address that can
change or lag.

### 2. Bootstrap onto the NVMe drive

The Pi 5 can boot directly from NVMe, but getting there needs one pass
through a temporary SD card first:

1. Flash a microSD card with Raspberry Pi OS (64-bit) **Desktop** (not
   Lite — see note below) using [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
   In the imager's advanced options: set hostname, enable SSH, Wi-Fi
   credentials if needed, locale/timezone.
2. Boot the Pi from that SD card with the HAT and NVMe already installed.
3. Update the bootloader and enable PCIe boot:
   ```bash
   sudo raspi-config
   # Advanced Options -> Bootloader Version -> Latest
   # Advanced Options -> PCIe Speed -> enable Gen 3 if you want max NVMe speed (optional)
   sudo rpi-eeprom-update -a
   sudo reboot
   ```
   (Exact menu wording can drift between Raspberry Pi OS releases — if
   `raspi-config` doesn't match this, search "Raspberry Pi 5 NVMe boot"
   for the current official steps rather than guessing.)
4. After reboot, run **Raspberry Pi Imager from the Pi itself** (it's
   preinstalled) and flash Raspberry Pi OS (64-bit) Desktop again, this
   time targeting the NVMe drive (it'll show up as a storage option, not
   the SD card) as the destination.
5. Power off, remove the SD card, power back on. The Pi should now boot
   from the NVMe drive directly — confirm with `lsblk` and check `/` is on
   `nvme0n1`.

### 3. Kiosk prep

Native display resolution is 1200×1920 portrait, so no display rotation
configuration is required — just the DSI + GPIO power cables, no HDMI.

SSH in (or use a keyboard/mouse directly), clone this repo, and run:

```bash
git clone https://github.com/MJFlanigan5/ha-wall-kiosk.git
cd ha-wall-kiosk/scripts
bash 01-pi-kiosk-prep.sh
sudo reboot
```

This disables screen blanking (critical — a kiosk display can't be allowed
to sleep), enables desktop autologin (so it boots straight into the kiosk
session with no login prompt), and updates packages.

**Why Desktop, not Lite:** Raspberry Pi OS Desktop ships labwc (Wayland)
by default, which gives Chromium GPU-accelerated rendering out of the
box — meaningfully smoother than software rendering for a live,
frequently-updating dashboard. You'll never see a normal desktop in
daily use (see the panel/taskbar-trimming step below). Lite + a minimal
X11/Wayland session + chromium-browser is a real, commonly-used lighter
alternative for exactly this kind of kiosk — worth trying if 2GB turns
out tight in practice, just not the default here since it's unverified
against this specific display/touch setup.

`01-pi-kiosk-prep.sh` also applies memory/performance tuning for the 2GB
tier — see below.

### Remote access (SSH)

SSH is enabled during the Imager flash (step 2, advanced options). For
reliable scripted/automated access afterward — running setup scripts
remotely, checking logs, having Claude run commands directly — set up
key-based auth instead of relying on password login each time:

```bash
# from your Mac, one-time:
ssh-copy-id mike@<pi-hostname-or-ip>
```

If `ssh-copy-id` isn't available, the manual equivalent: copy the contents
of `~/.ssh/id_ed25519.pub` (or generate one first with `ssh-keygen -t
ed25519` if you don't have a key yet) into the Pi's
`~/.ssh/authorized_keys`.

Since this Pi is PoE-powered, it's on wired Ethernet with a stable IP (see
the hardware note above) — check your router/PoE switch's client list or
`ping <hostname>.local` to find it rather than guessing. No dedicated MCP
server or special tooling needed beyond plain SSH — it's a normal Linux
box once it's on the network.

### Performance tuning (2GB Pi 5)

`01-pi-kiosk-prep.sh` automates the safe, well-established tweaks:

- **zram compressed swap** (50% of RAM, zstd) — gives real extra headroom
  under memory pressure without the wear/slowness of swapping to disk.
  Compressed RAM swap is far faster than even NVMe swap, and meaningfully
  better than the SD-card swap situation we'd have had without the drive
  upgrade.
- **Bluetooth disabled** — not used by this kiosk, frees a small amount of
  RAM/CPU.
- **Boot splash disabled** — trims a little boot time.

Two more worth doing by hand, since they're higher-risk to blind-script
(a bad edit here can leave you stuck at a broken session, so they're best
done once you can see the screen and verify):

- **Skip the desktop panel/taskbar in the kiosk session.** A full labwc
  desktop session normally starts a taskbar, wallpaper, and other chrome
  you'll never see behind TouchKio's fullscreen window — that's RAM and
  CPU spent on nothing. TouchKio starts itself via its own systemd user
  service (see below), independent of this file, so this step is purely
  about trimming labwc's own startup, not about "leaving room" for
  anything app-related. Once TouchKio is confirmed launching correctly,
  edit `~/.config/labwc/autostart` and comment out the lines that launch
  the panel/wallpaper apps. Reboot and confirm the kiosk still launches
  correctly before considering this done.
- **CPU governor to `performance`** (optional) — trades a little power/heat
  for more consistent UI responsiveness, reasonable given the HAT's active
  cooling gives thermal headroom. Add a `@reboot` cron entry or a small
  systemd unit that runs:
  ```bash
  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  ```

### 4. Run Foyer in kiosk mode (via TouchKio)

**Not yet verified against real hardware** (written before the Pi
arrived) — treat every step here as the best-known starting point, not
confirmed-working, until actually tested.

Using [TouchKio](https://github.com/leukipp/touchkio) rather than a
hand-rolled `chromium-browser --kiosk` autostart script — it's
purpose-built for exactly this (Pi + DSI/HDMI touch display + a URL in
kiosk mode), Debian/labwc-native, and handles the fiddly parts a raw
Chromium flag list doesn't: login credentials persist inside its own
config after the first entry (no plaintext Basic Auth in a shell
script), it ships a systemd user service instead of an autostart-file
edit, and it has on-screen-keyboard support (squeekboard) for that
first login on a device with no physical keyboard attached.

1. Install (the script handles .deb install, arch detection, and
   creating/enabling the systemd user service):
   ```bash
   bash <(wget -qO- https://raw.githubusercontent.com/leukipp/touchkio/main/install.sh)
   ```
2. Foyer needs to already be reachable from the Pi — either the
   Docker-hosted instance on the LAN (same network, PoE-wired, so this
   should just work — see [`pwa-app/README.md`](pwa-app/README.md) for
   how that's hosted) or the Cloudflare Tunnel URL if you'd rather not
   depend on a specific LAN address. LAN is the better default for a
   permanently wall-mounted device: lower latency, and it keeps working
   even if the Tunnel/internet is briefly down.
3. Point it at Foyer:
   ```bash
   touchkio --web-url=https://your-foyer-host/
   ```
   `--web-url` accepts any URL, not just Home Assistant's own dashboard
   — Foyer works the same way. First run walks through a CLI setup, then
   shows the login screen for Basic Auth — have a physical keyboard or
   VNC handy for that first entry (or use the on-screen keyboard if it's
   working on this hardware); credentials are remembered after that, no
   re-entry on reboot.
4. Confirm it starts on boot without re-running anything manually:
   ```bash
   systemctl --user status touchkio.service
   ```
5. Confirm touch input works correctly on the Touch Display 2 once
   Foyer is actually showing.

## Troubleshooting

- **2GB RAM headroom:** this is the low-end Pi 5 tier, and TouchKio is
  Electron (a real Chromium instance), not a lightweight native shell —
  expect its baseline footprint to be genuinely higher than "tens of
  MB." Check `free -h` if things feel sluggish. The Foyer-side perf work
  already done with this device in mind (icon-scan scoping, the Sensors
  page's collapsed-by-default areas so 1,000+ entities aren't all live
  in the DOM at once, camera snapshot blob cleanup — see
  [`pwa-app/README.md`](pwa-app/README.md)) should help, but this
  combination hasn't been measured on the real device yet — zram (see
  above) is the real safety net if it turns out tight.
- **Blank/black screen on boot:** confirm both the DSI ribbon and GPIO power
  cable are fully seated. Check `dmesg | grep -i dsi` for detection errors.
- **Screen sleeps after a few minutes:** re-run `sudo raspi-config` →
  Display Options → Screen Blanking → Disable, if the nonint script call in
  `01-pi-kiosk-prep.sh` didn't stick on your OS version.

## Dashboard-side performance constraints

This kiosk's Pi 5 2GB is the real, fixed hardware target for Foyer, not
just a general guideline — treat it as the design baseline for anything
new added to the dashboard, so it scales down cleanly to basically
anything rather than looking fine on a dev laptop and struggling here.
Already done with this device specifically in mind (2026-08-07, before
the Pi itself was available to test against — see
[`pwa-app/README.md`](pwa-app/README.md) for the full list): `lucide`
icon re-scans are now scoped to the changed DOM subtree instead of the
whole document on every render, the Sensors page (1,128 entities in this
HA instance) renders collapsed by default instead of all-expanded, and
camera snapshot blob URLs are properly revoked instead of leaking on
navigation. Keep applying the same standard going forward for anything
new:

- No CSS animations/transitions on state changes
- Cap concurrent live camera feeds at ~4
- Avoid GPU-expensive CSS on this device: heavy `backdrop-filter`/blur,
  large box-shadows, frequently-repainted gradients
- Avoid full-document DOM operations (icon re-scans, wide `querySelectorAll`)
  on anything that fires from a polling loop — scope to the subtree that
  actually changed
- Keep DOM complexity reasonable per screen, especially for
  large/generic listings (Sensors-style "show everything" pages) — this
  is a single full-time kiosk view, not a multi-tab desktop app

## iPad + phone + wall panel — one app

Foyer (`pwa-app/`) is the same PWA on all three surfaces now — iPad,
phone, and this wall panel via TouchKio (see "Run Foyer in kiosk mode"
above). Originally the wall panel was planned as a separate native app
specifically to avoid a browser engine's memory footprint on the 2GB
Pi tier; that's now handled instead by the perf work described above,
done directly in Foyer with this device's constraints in mind, rather
than by avoiding a browser at all. See
[`docs/IPAD_PWA_SPEC.md`](docs/IPAD_PWA_SPEC.md) for the PWA's own
history/spec.

## Notifications & interrupt events (not started, spec only)

How doorbell rings, finished timers, and alarm triggers actually reach and
render on both apps — different problem on the wall panel (already
connected, no push infra needed) vs. iPad (needs real Web Push since a PWA
can be backgrounded). See [`docs/NOTIFICATIONS_SPEC.md`](docs/NOTIFICATIONS_SPEC.md).

## Music / media player control (not started, spec only)

Controlling Music Assistant (Spotify, etc.) — a genuinely different entity
shape than toggles/sensors: client-side progress interpolation, per-player
feature gating, authenticated album art, and an open scope question on
multi-room grouping and search/browse. See
[`docs/MUSIC_SPEC.md`](docs/MUSIC_SPEC.md).

## Other interaction gaps (catalog, not yet speced)

Live camera viewing, climate control (blocked on backend exposure),
security/locks (blocked on hardware), scenes/moods, kiosk exit/admin
access, idle/screensaver behavior, voice/Assist, connection-loss handling,
and other device domains not yet inventoried. See
[`docs/INTERACTION_GAPS.md`](docs/INTERACTION_GAPS.md) so none of these get
forgotten and rediscovered late.

## Design background

This mount and kiosk pairs with the Savant-inspired Home Assistant dashboard
mockup work at [savant-dashboard-mockup](https://github.com/MJFlanigan5) —
see that project for the visual design this panel is meant to eventually
run. Screen orientation is portrait, matching Savant's own in-wall
touchscreen precedent (vertical, keypad-like), not landscape.
