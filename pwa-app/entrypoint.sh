#!/bin/sh
# Two ways to get Basic Auth credentials in place before nginx starts:
#
# 1. BASIC_AUTH_USER/BASIC_AUTH_PASS set (scripted/automated deploys) —
#    write .htpasswd directly, same as before, no setup screen needed.
# 2. Neither set (normal path now) — generate a one-time setup token,
#    print it to the container logs, and start setup-server.py so /setup
#    can create the real credential through the browser. The token is
#    what stops anyone who just finds /setup on the LAN from completing
#    it themselves — only whoever can read these logs has it.
set -e

if [ -n "$BASIC_AUTH_USER" ] && [ -n "$BASIC_AUTH_PASS" ]; then
  HASH=$(openssl passwd -apr1 "$BASIC_AUTH_PASS")
  if [ -z "$HASH" ]; then
    echo "ERROR: password hash generation failed." >&2
    exit 1
  fi
  echo "$BASIC_AUTH_USER:$HASH" > /etc/nginx/.htpasswd
  echo "Basic Auth configured from BASIC_AUTH_USER/BASIC_AUTH_PASS."
elif [ ! -f /etc/nginx/.htpasswd ]; then
  export SETUP_TOKEN=$(openssl rand -hex 8)
  echo "=============================================="
  echo " Foyer setup token: $SETUP_TOKEN"
  echo " Open /setup in your browser and enter this"
  echo " token to create your login."
  echo "=============================================="
fi

# Always started, not just in the token path above — setup-server.py
# already checks for .htpasswd itself and shows "already configured" when
# it exists, so this stays correct either way. Started conditionally
# before, hitting /setup on an env-var-configured deploy returned a bare
# 502 instead of that message, since nothing was listening on 8081 at all
# — found via actually curling it, not just reading the code back.
python3 /setup-server.py &

exec "$@"
