#!/usr/bin/env bash
# Plan B kiosk launcher, in case TouchKio (the primary plan — see root
# README "Run Foyer in kiosk mode") doesn't work out on this specific
# hardware. TouchKio is untested against this exact Pi/display/OS
# combination as of writing, so this exists as a fast, already-thought-
# through fallback rather than something to research from scratch under
# time pressure if TouchKio has trouble.
#
# What this gives up vs. TouchKio: no built-in on-screen keyboard, no
# systemd service (added below instead), no MQTT device integration.
# What it gains: one real Chromium process instead of Electron's bundled
# Chromium + Node.js runtime on top — worth trying first if 2GB turns out
# tight under TouchKio specifically.
#
# Before running this: stop TouchKio so both aren't fighting for the
# display -- `systemctl --user disable --now touchkio.service`.
#
# Usage (run on the Pi itself, as your normal user, not root):
#   FOYER_URL="https://your-foyer-host/" \
#   BASIC_AUTH_USER="your-user" \
#   BASIC_AUTH_PASS="your-password" \
#   bash 02-kiosk-fallback-chromium.sh
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not root/sudo directly (it calls sudo itself where needed)."
  exit 1
fi

: "${FOYER_URL:?Set FOYER_URL to the Foyer URL, e.g. https://your-foyer-host/}"
: "${BASIC_AUTH_USER:?Set BASIC_AUTH_USER to the Foyer Basic Auth username}"
: "${BASIC_AUTH_PASS:?Set BASIC_AUTH_PASS to the Foyer Basic Auth password}"

echo "==> Installing Chromium (skips if already present)"
sudo apt install -y chromium-browser

# Embeds credentials in the URL itself so Chromium's own Basic Auth
# handshake completes with no login prompt on every boot -- avoids
# depending on Chromium's profile-based password manager surviving
# reboots/updates, which TouchKio's own credential store was built
# specifically to not depend on either.
#
# Percent-encoded via python3 (preinstalled on Raspberry Pi OS), not
# embedded raw: a real password can easily contain @, :, or / -- all
# have delimiter meaning inside a URL's userinfo section, and an
# unencoded one would silently break the login instead of erroring.
urlencode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}
BASIC_AUTH_USER_ENC="$(urlencode "$BASIC_AUTH_USER")"
BASIC_AUTH_PASS_ENC="$(urlencode "$BASIC_AUTH_PASS")"

FOYER_URL_NO_SCHEME="${FOYER_URL#https://}"
FOYER_URL_NO_SCHEME="${FOYER_URL_NO_SCHEME#http://}"
SCHEME="https://"
case "$FOYER_URL" in http://*) SCHEME="http://" ;; esac
AUTH_URL="${SCHEME}${BASIC_AUTH_USER_ENC}:${BASIC_AUTH_PASS_ENC}@${FOYER_URL_NO_SCHEME}"

AUTOSTART_DIR="$HOME/.config/labwc"
AUTOSTART_FILE="$AUTOSTART_DIR/autostart"
MARKER_START="# --- foyer-kiosk-fallback (managed by 02-kiosk-fallback-chromium.sh) ---"
MARKER_END="# --- end foyer-kiosk-fallback ---"

mkdir -p "$AUTOSTART_DIR"
touch "$AUTOSTART_FILE"

echo "==> Writing kiosk launch into $AUTOSTART_FILE"
# Reruns replace the block between the markers instead of duplicating it,
# so this script is safe to run again after changing FOYER_URL/credentials.
# awk with exact-string variables (not sed regex) so the markers below
# never need special-character escaping.
if grep -qF "$MARKER_START" "$AUTOSTART_FILE" 2>/dev/null; then
  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$AUTOSTART_FILE" > "$AUTOSTART_FILE.tmp"
  mv "$AUTOSTART_FILE.tmp" "$AUTOSTART_FILE"
fi
{
  echo "$MARKER_START"
  echo "chromium-browser \\"
  echo "  --kiosk \\"
  echo "  --noerrdialogs \\"
  echo "  --disable-infobars \\"
  echo "  --disable-session-crashed-bubble \\"
  echo "  --check-for-update-interval=31536000 \\"
  echo "  --app=\"$AUTH_URL\" &"
  echo "$MARKER_END"
} >> "$AUTOSTART_FILE"

# Credentials are now in this file in plaintext.
chmod 600 "$AUTOSTART_FILE"

echo "==> Done. Reboot to test:"
echo "    sudo reboot"
echo ""
echo "If it doesn't launch: check ~/.config/labwc/autostart ran at all"
echo "(labwc logs), and confirm chromium-browser launches manually first:"
echo "  chromium-browser --app=\"$FOYER_URL\""
