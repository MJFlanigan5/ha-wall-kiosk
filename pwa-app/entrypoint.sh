#!/bin/sh
# Generates the Basic Auth password file from env vars at container start —
# no credentials ever get baked into the image or committed to the repo,
# same principle as the HA/Homey tokens (per-device localStorage, nothing
# in source). Required because this is exposed via a Cloudflare Tunnel with
# no Access policy in front of it, so nginx has to be the actual gate.
set -e

if [ -z "$BASIC_AUTH_USER" ] || [ -z "$BASIC_AUTH_PASS" ]; then
  echo "ERROR: BASIC_AUTH_USER and BASIC_AUTH_PASS must both be set." >&2
  exit 1
fi

HASH=$(openssl passwd -apr1 "$BASIC_AUTH_PASS")
if [ -z "$HASH" ]; then
  echo "ERROR: password hash generation failed." >&2
  exit 1
fi
echo "$BASIC_AUTH_USER:$HASH" > /etc/nginx/.htpasswd

exec "$@"
