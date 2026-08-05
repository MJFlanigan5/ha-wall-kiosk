# HA Wall Kiosk

A wall-mounted Home Assistant control panel: Raspberry Pi 5 + official 10.1"
Touch Display 2 (portrait), running [touchkio](https://github.com/leukipp/touchkio)
in kiosk mode, in a 3D-printed arm-locking flush mount.

This repo has both halves of the build: the physical mount (`hardware/`) and
the Pi/software setup (`scripts/` + this README).

**Built and tuned for the Pi 5 2GB tier on purpose** — not just because
that's what this build happens to use. The 4GB/8GB Pi 5 boards cost roughly
double the 2GB model, and there's no reason this project should push anyone
toward the pricier tier if 2GB runs it fine. Every setup and dashboard
choice here (see "Performance tuning" and "Dashboard-side performance
constraints" below) is made assuming the cheapest Pi 5 you can buy — if you
have a 4GB/8GB board, it'll just have more headroom to spare.

## Status / what's left

**Physical (blocking everything else):**
1. Finish the mount — right side printed and working; left side needs a
   fix where the wall stud leaves zero cavity clearance for the arm-lock
   clamp (handled directly on the printed piece — drill/adhesive — not a
   frame redesign)
2. Assemble Pi 5 + POE HAT + NVMe SSD + Touch Display 2
3. Bootstrap NVMe boot (temporary SD card pass, see below)

**Software (scripts already written, just need to run on real hardware):**
4. `scripts/01-pi-kiosk-prep.sh` — 2GB tuning, zram, autologin
5. `scripts/02-install-touchkio.sh` — get touchkio actually showing the
   live HA dashboard on the screen

**Decision gate (not yet reached):**
6. Confirm touchkio actually runs fine on the 2GB Pi in practice. If yes —
   done, nothing else to build, the native app stays a spec. If it
   genuinely struggles — that's what unlocks native app work below.

**Conditional on step 6 tripping (currently just an untested MVP skeleton):**
7. Verify the native app's HA WebSocket client against real data (see
   `native-app/README.md` — untested against a live instance so far)
8. Port remaining screens one at a time
9. Wire service calls (write actions)
10. Hardware/perf testing on the real Pi

Full phase breakdown and time estimates for 7-10: [`docs/NATIVE_APP_SPEC.md`](docs/NATIVE_APP_SPEC.md).

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

**Why Desktop, not Lite:** touchkio is an Electron app; it needs a
Wayland/labwc compositor running underneath it even though you'll never see
a normal desktop in daily use.

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
  you'll never see behind a fullscreen kiosk window — that's RAM and CPU
  spent on nothing. Once touchkio is confirmed working (step 5), edit
  `~/.config/labwc/autostart` and comment out the lines that launch the
  panel/wallpaper apps, leaving only what starts `touchkio`. Reboot and
  confirm the kiosk still launches correctly before considering this done.
- **CPU governor to `performance`** (optional) — trades a little power/heat
  for more consistent UI responsiveness, reasonable given the HAT's active
  cooling gives thermal headroom. Add a `@reboot` cron entry or a small
  systemd unit that runs:
  ```bash
  echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  ```

### 4. Install touchkio

After the reboot:

```bash
cd ha-wall-kiosk/scripts
bash 02-install-touchkio.sh http://homeassistant.local:8123
```

Replace the URL with your actual Home Assistant instance's address. This
runs touchkio's official installer, writes your HA URL into
`~/.config/touchkio/Arguments.json`, and starts it as a systemd user
service that launches automatically on every boot.

### 5. Verify

```bash
systemctl --user status touchkio.service
```

The display should be showing your Home Assistant dashboard in kiosk mode
within a few seconds of boot. Logs live at `~/.config/touchkio/logs/main.log`.

## Configuration reference

Full options: `~/.config/touchkio/Arguments.json`. Key ones:

| Key | Default we set | Notes |
|---|---|---|
| `web_url` | your HA URL | can be a list — touchkio supports swiping between multiple pages |
| `web_theme` | `dark` | matches the Savant-style dark dashboard this panel is meant to run |
| `web_zoom` | `1.0` | touchkio's own default is `1.25`; adjust to taste once you see it on the real screen |
| `web_widget` | `true` | sidebar quick-access widget |

Edit the file directly and `systemctl --user restart touchkio.service` to
apply changes.

### Optional: MQTT device sensors

touchkio can publish its own device sensors (battery, temperature, CPU,
memory, screen state) back into Home Assistant via MQTT discovery, and
accept remote commands (brightness, reboot, screenshot). Add to
`Arguments.json`:

```json
{
  "mqtt_url": "mqtt://homeassistant.local:1883",
  "mqtt_user": "kiosk",
  "mqtt_password": "REPLACE_ME"
}
```

Don't commit real MQTT credentials to this repo — keep them local to the
Pi's config file only.

## Troubleshooting

- **2GB RAM headroom:** this is the low-end Pi 5 tier. Electron/Chromium is
  memory-hungry. Our dashboard is intentionally animation-free with at most
  4 camera feeds, which should be fine — but if things feel sluggish, check
  `free -h` and consider trimming concurrent camera cards before assuming
  it's a touchkio problem.
- **Blank/black screen on boot:** confirm both the DSI ribbon and GPIO power
  cable are fully seated. Check `dmesg | grep -i dsi` for detection errors.
- **Screen sleeps after a few minutes:** re-run `sudo raspi-config` →
  Display Options → Screen Blanking → Disable, if the nonint script call in
  `01-pi-kiosk-prep.sh` didn't stick on your OS version.
- **touchkio doesn't start on boot:** `systemctl --user status
  touchkio.service` — if the user service isn't running at boot, confirm
  desktop autologin is actually enabled (`sudo raspi-config` → System
  Options → Boot / Auto Login → Desktop Autologin).
- **Updating touchkio:**
  `bash <(wget -qO- https://raw.githubusercontent.com/leukipp/touchkio/main/install.sh) update`

## Dashboard-side performance constraints

This kiosk's Pi 5 2GB is the real, fixed hardware target — treat it as the
design baseline for whatever dashboard runs on it, so it scales down
cleanly to basically anything rather than looking fine on a dev laptop and
struggling here. When building the actual dashboard this panel displays:

- No CSS animations/transitions on state changes
- Cap concurrent live camera feeds at ~4
- Avoid GPU-expensive CSS on this device: heavy `backdrop-filter`/blur,
  large box-shadows, frequently-repainted gradients
- Prefer stock/Mushroom/card-mod patterns over JS-heavy custom cards,
  especially anything that polls or re-renders often
- Keep DOM complexity reasonable per screen — this is a single full-time
  kiosk view, not a multi-tab desktop app

## Going native (deferred)

Browser-based (touchkio, or a lighter custom Chromium/WPE wrapper) is the
practical path for now — it keeps the entire dashboard as the HTML/CSS
already built. A real native app (PySide6 + QML, no browser engine at all
— the same approach Savant/Control4/Crestron actually use) is spec'd out
in [`docs/NATIVE_APP_SPEC.md`](docs/NATIVE_APP_SPEC.md) for later, but
deliberately **not started** — only worth it if the browser-based setup
turns out to actually struggle in practice, not as a preemptive rewrite.

## Design background

This mount and kiosk pairs with the Savant-inspired Home Assistant dashboard
mockup work at [savant-dashboard-mockup](https://github.com/MJFlanigan5) —
see that project for the visual design this panel is meant to eventually
run. Screen orientation is portrait, matching Savant's own in-wall
touchscreen precedent (vertical, keypad-like), not landscape.
