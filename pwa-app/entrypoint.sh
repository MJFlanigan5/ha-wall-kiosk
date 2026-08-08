#!/bin/sh
# Two ways to get Basic Auth credentials in place before nginx starts:
#
# 1. BASIC_AUTH_USER/BASIC_AUTH_PASS set (scripted/automated deploys) —
#    write .htpasswd directly, no setup screen needed.
# 2. Neither set (normal path) — leave .htpasswd absent; setup-server.py
#    serves /setup so the login gets created through the browser, same
#    model Home Assistant/Homey use for their own first-run setup —
#    whoever's first to the browser after a fresh deploy sets it, no
#    separate token to go find. The real gate is deliberately choosing
#    when to point a public tunnel at this container, not a secret
#    required to complete setup.
set -e

if [ -n "$BASIC_AUTH_USER" ] && [ -n "$BASIC_AUTH_PASS" ]; then
  HASH=$(openssl passwd -apr1 "$BASIC_AUTH_PASS")
  if [ -z "$HASH" ]; then
    echo "ERROR: password hash generation failed." >&2
    exit 1
  fi
  echo "$BASIC_AUTH_USER:$HASH" > /etc/nginx/.htpasswd
  echo "Basic Auth configured from BASIC_AUTH_USER/BASIC_AUTH_PASS."
fi

# Which config nginx loads depends on whether a login already exists —
# .htpasswd may already be there from the block above, from a previous
# run (persisted volume), or from a completed /setup on an earlier boot.
# setup-server.py performs the same swap+reload itself the moment setup
# completes mid-session, so this stays correct either way.
if [ -f /etc/nginx/.htpasswd ]; then
  cp /etc/nginx/templates/nginx-postsetup.conf /etc/nginx/conf.d/default.conf
else
  cp /etc/nginx/templates/nginx-presetup.conf /etc/nginx/conf.d/default.conf
fi

# Always started regardless of which config is active — setup-server.py
# already checks for .htpasswd itself and shows "already configured" when
# it exists, so this stays correct either way. Started conditionally
# before, hitting /setup on an env-var-configured deploy returned a bare
# 502 instead of that message, since nothing was listening on 8081 at all
# — found via actually curling it, not just reading the code back.
python3 /setup-server.py &

exec "$@"
