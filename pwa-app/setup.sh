#!/bin/sh
# Interactive setup — prompts for Basic Auth credentials in the terminal
# and writes .env, instead of hand-editing .env.example. Same security
# property as before: credentials are set by whoever has terminal access
# to this host, before the container (and therefore the app) ever starts,
# not via a signup form reachable over the Cloudflare Tunnel. See
# Dockerfile/nginx.conf for why an unauthenticated first-run web setup
# isn't safe for this specific deployment (internet-reachable, no Access
# policy in front of it).
set -e
cd "$(dirname "$0")"

if [ -f .env ]; then
  echo "Found existing .env — starting with it. Delete it first if you want to set new credentials."
else
  echo "Set up Foyer's login (separate from the HA/Homey tokens you'll enter inside the app):"
  printf "Username: "
  read -r BASIC_AUTH_USER
  printf "Password: "
  # -t 0 guards stty, which errors out (and would otherwise abort the whole
  # script under set -e) whenever stdin isn't a real TTY — confirmed via
  # testing with piped input. Falls back to visible input in that case
  # rather than hard-crashing; normal interactive terminal use is unaffected.
  if [ -t 0 ]; then
    stty -echo
    read -r BASIC_AUTH_PASS
    stty echo
  else
    read -r BASIC_AUTH_PASS
  fi
  echo

  if [ -z "$BASIC_AUTH_USER" ] || [ -z "$BASIC_AUTH_PASS" ]; then
    echo "ERROR: username and password can't be empty." >&2
    exit 1
  fi

  {
    echo "BASIC_AUTH_USER=$BASIC_AUTH_USER"
    echo "BASIC_AUTH_PASS=$BASIC_AUTH_PASS"
  } > .env
  echo "Wrote .env."
fi

docker compose up -d --build
echo "Foyer is starting on port 8090."
