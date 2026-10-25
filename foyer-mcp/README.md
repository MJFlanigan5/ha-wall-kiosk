# foyer-mcp-server

Drives a headless Chrome copy of the Foyer wall kiosk. Foyer has no API of
its own (static page talking straight to HA), so this loads it through the
token-gated agent listener and exposes: `foyer_state`, `foyer_screenshot`,
`foyer_navigate`, `foyer_press`, `foyer_console`, `foyer_reload`.

`foyer_press` is a dry run by default: HA service calls the click triggers
are returned but not sent. Pass `send=True` to fire them.

## Setup
1. Foyer container: set `FOYER_AGENT_TOKEN` (32+ URL-safe chars) in
   `pwa-app/.env`, then `docker compose up -d --build`. Port 8091 serves the
   app for requests carrying `X-Foyer-Agent-Token`. LAN only; never tunnel it.
2. Client env: `FOYER_URL`, `FOYER_TOKEN` (same value), `FOYER_HA_TOKEN`.
   Optional `FOYER_HA_URL`, `FOYER_VIEWPORT`, `FOYER_CHROME`.
3. Needs system Google Chrome (or `FOYER_CHROME=` plus `playwright install chromium`).

Secrets live in Infisical (`FOYER_AGENT_TOKEN`, `HA_LONG_LIVED_TOKEN`).
HA-only: Homey-backed features (thermostat, moods) are not seeded.
To share it, run this server beside the app on the Foyer LXC; it only needs the three env vars.
