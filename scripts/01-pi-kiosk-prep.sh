#!/usr/bin/env bash
# Prepares a fresh Raspberry Pi OS (64-bit, Desktop) install for unattended
# kiosk use: disables screen blanking, enables desktop autologin, updates
# packages, and applies memory/performance tuning for the 2GB Pi 5 tier
# (zram compressed swap, Bluetooth off, boot splash off). Run this on the
# Pi itself after first boot, not on your Mac.
#
# Usage: bash 01-pi-kiosk-prep.sh
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root/sudo directly (it calls sudo itself where needed)."
  exit 1
fi

echo "==> Updating package lists and upgrading system"
sudo apt update
sudo apt full-upgrade -y

echo "==> Enabling Desktop Autologin (raspi-config boot behaviour B4)"
# NOTE: the numeric code for "Desktop Autologin" has been B4 on recent
# Raspberry Pi OS (Bookworm) releases. If this doesn't stick, open
# `sudo raspi-config` -> System Options -> Boot / Auto Login -> Desktop Autologin
# and set it manually instead.
sudo raspi-config nonint do_boot_behaviour B4 || {
  echo "!! nonint boot_behaviour call failed or code mismatch -- set this manually via 'sudo raspi-config'."
}

echo "==> Disabling screen blanking / DPMS sleep"
sudo raspi-config nonint do_blanking 1 || {
  echo "!! nonint blanking call failed -- set this manually via 'sudo raspi-config' -> Display Options -> Screen Blanking."
}

echo "==> Ensuring filesystem is expanded to fill the boot drive"
sudo raspi-config nonint do_expand_rootfs || true

echo "==> Disabling Bluetooth (not used by this kiosk, frees a bit of RAM/CPU)"
# NOTE: 0 = enabled, 1 = disabled on raspi-config's do_bluetooth. If this
# doesn't stick, set it manually via 'sudo raspi-config' -> Interface Options.
sudo raspi-config nonint do_bluetooth 1 || {
  echo "!! nonint bluetooth call failed -- set this manually via 'sudo raspi-config'."
}

echo "==> Disabling boot splash animation (minor boot-time saving)"
sudo raspi-config nonint disable_splash 1 || true

echo "==> Installing zram-tools for compressed RAM swap"
# On a 2GB board, zram gives real extra headroom under memory pressure
# without the wear/slowness of swapping to disk. Compressed RAM swap is
# much faster than even NVMe swap.
sudo apt install -y zram-tools
echo "ALGO=zstd" | sudo tee /etc/default/zramswap > /dev/null
echo "PERCENT=50" | sudo tee -a /etc/default/zramswap > /dev/null
sudo systemctl restart zramswap.service || true

echo "==> Done. Reboot recommended before running the native app: sudo reboot"
