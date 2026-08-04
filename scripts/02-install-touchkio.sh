#!/usr/bin/env bash
# Installs touchkio (https://github.com/leukipp/touchkio) and points it at
# your Home Assistant instance. Run this on the Pi itself, after
# 01-pi-kiosk-prep.sh and a reboot.
#
# Usage: bash 02-install-touchkio.sh http://homeassistant.local:8123
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root/sudo."
  exit 1
fi

HA_URL="${1:-}"
if [ -z "$HA_URL" ]; then
  read -rp "Home Assistant URL (e.g. http://homeassistant.local:8123): " HA_URL
fi

echo "==> Installing touchkio via the official installer"
bash <(wget -qO- https://raw.githubusercontent.com/leukipp/touchkio/main/install.sh)

echo "==> Configuring touchkio to point at: $HA_URL"
CONFIG_DIR="$HOME/.config/touchkio"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/Arguments.json" <<EOF
{
  "web_url": ["$HA_URL"],
  "web_theme": "dark",
  "web_zoom": 1.0,
  "web_widget": true
}
EOF

echo "==> Restarting the touchkio service to pick up the new config"
systemctl --user restart touchkio.service

echo "==> Done. Check status with: systemctl --user status touchkio.service"
echo "    Logs: ~/.config/touchkio/logs/main.log"
