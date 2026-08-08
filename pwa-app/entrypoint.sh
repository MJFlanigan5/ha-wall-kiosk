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

# /etc/nginx/auth is the mounted volume (see docker-compose.yml) — without
# it, .htpasswd only ever lived in the container's own writable layer,
# meaning every redeploy (docker compose up --build, down+up, even a
# plain `docker rm` + `run`) silently wiped the configured login and
# reopened the wide-open pre-setup state. Confirmed live: recreated the
# container after completing setup, and it reverted to showing the setup
# form again — a real, not theoretical, gap given redeploys happen every
# time this repo gets updated. mkdir here since a freshly created named
# volume mounts as an empty directory.
mkdir -p /etc/nginx/auth

# Only if .htpasswd doesn't already exist — without this check, leaving
# BASIC_AUTH_USER/PASS set in .env (e.g. leftover from earlier testing)
# would silently overwrite a real login someone already created through
# /setup on every subsequent restart. Same "can only happen once" rule
# /setup itself already follows; this path should be no different.
if [ -n "$BASIC_AUTH_USER" ] && [ -n "$BASIC_AUTH_PASS" ] && [ ! -f /etc/nginx/auth/.htpasswd ]; then
  HASH=$(openssl passwd -apr1 "$BASIC_AUTH_PASS")
  if [ -z "$HASH" ]; then
    echo "ERROR: password hash generation failed." >&2
    exit 1
  fi
  echo "$BASIC_AUTH_USER:$HASH" > /etc/nginx/auth/.htpasswd
  echo "Basic Auth configured from BASIC_AUTH_USER/BASIC_AUTH_PASS."
fi

# Which config nginx loads depends on whether a login already exists —
# .htpasswd may already be there from the block above, from a previous
# run (persisted volume), or from a completed /setup on an earlier boot.
# setup-server.py performs the same swap+reload itself the moment setup
# completes mid-session, so this stays correct either way.
if [ -f /etc/nginx/auth/.htpasswd ]; then
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
