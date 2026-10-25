"""Foyer MCP server.

Foyer is a static PWA that talks straight to Home Assistant from the
browser, so there is no REST API to wrap (unlike Kith). This server instead
runs a headless Chrome pointed at Foyer's token-gated agent listener
(:8091), seeds the per-device HA config the app expects in localStorage,
and exposes inspect/navigate/press tools. HA service calls the app makes
are recorded, and by default blocked (dry run) so wiring can be tested
without actuating devices.

Env:
  FOYER_URL        agent listener, default http://192.168.2.25:8091
  FOYER_TOKEN      value of FOYER_AGENT_TOKEN on the Foyer container
  FOYER_HA_URL     HA websocket URL, default ws://homeassistant.local:8123/api/websocket
  FOYER_HA_TOKEN   HA long-lived access token
  FOYER_VIEWPORT   WxH, default 1280x800
  FOYER_CHROME     "chrome" (system Chrome, default) or "" for Playwright's Chromium
  FOYER_CHROME_PATH  explicit browser binary (used in the container), optional
  FOYER_HOMEY_URL / FOYER_HOMEY_TOKEN  optional Homey local API, seeds the app's Homey features
  FOYER_MCP_TRANSPORT  "stdio" (default) or "http" (serves /mcp on :8092 behind a bearer token)
  FOYER_MCP_TOKEN  required when transport is http
"""
import asyncio
import hmac
import json
import os

from mcp.server.fastmcp import FastMCP, Image
from playwright.async_api import async_playwright

FOYER_URL = os.environ.get("FOYER_URL", "http://192.168.2.25:8091").rstrip("/")
FOYER_TOKEN = os.environ["FOYER_TOKEN"]
HA_URL = os.environ.get("FOYER_HA_URL", "ws://homeassistant.local:8123/api/websocket")
HA_TOKEN = os.environ["FOYER_HA_TOKEN"]
W, H = (int(x) for x in os.environ.get("FOYER_VIEWPORT", "1280x800").split("x"))
CHANNEL = os.environ.get("FOYER_CHROME", "chrome") or None
CHROME_PATH = os.environ.get("FOYER_CHROME_PATH") or None
HOMEY_URL = os.environ.get("FOYER_HOMEY_URL", "")
HOMEY_TOKEN = os.environ.get("FOYER_HOMEY_TOKEN", "")

mcp = FastMCP("foyer")

_pw = _browser = _ctx = _page = None
_console: list[str] = []
_lock = asyncio.Lock()

# Wraps haClient.callService to record every call and, unless window.__send
# is set, resolve without sending it. Installed after each load.
_HOOK = """
() => {
  const c = window.haClient;
  if (!c) return false;
  if (c.__rec) return true;
  const orig = c.callService.bind(c);
  window.__calls = []; window.__send = false;
  c.callService = (domain, service, entity, data) => {
    const rec = {domain, service, entity: entity || null, data: data || null, sent: !!window.__send};
    window.__calls.push(rec);
    return window.__send ? orig(domain, service, entity, data) : Promise.resolve();
  };
  c.__rec = true;
  return true;
}
"""

# Plain-data read of what the screen is showing. Top-level `let`s in the
# app's classic scripts are reachable by name from evaluate().
_STATE = """
() => {
  const q = (s) => document.querySelector(s);
  const toast = q('#errorToast');
  const ambient = q('#ambientOverlay');
  return {
    haConnected: !!(window.haClient && window.haClient.connected),
    currentRoom: typeof currentRoom !== 'undefined' ? currentRoom : null,
    ambientVisible: !!(ambient && ambient.classList.contains('visible')),
    toast: toast && toast.classList.contains('visible') ? toast.textContent : null,
    rooms: [...document.querySelectorAll('.rail-item')].map(b => ({
      id: b.dataset.room, label: (b.querySelector('.label') || b).textContent.trim(),
      active: b.classList.contains('active')})),
    recirculation: (typeof waterHeaterRecircState !== 'undefined' && waterHeaterRecircState) ? waterHeaterRecircState.state : null,
    waterHeater: (typeof waterHeaterState !== 'undefined' && waterHeaterState) ? waterHeaterState.state : null,
  };
}
"""


async def _route(route):
    req = route.request
    if req.url.startswith(FOYER_URL):
        await route.continue_(headers={**req.headers, "x-foyer-agent-token": FOYER_TOKEN})
    else:
        await route.continue_()


async def _page_ready():
    """Start the browser on first use and return the live page."""
    global _pw, _browser, _ctx, _page
    async with _lock:
        if _page is not None and not _page.is_closed():
            return _page
        if _pw is None:
            _pw = await async_playwright().start()
        if _browser is None or not _browser.is_connected():
            _browser = await _pw.chromium.launch(
                channel=None if CHROME_PATH else CHANNEL, executable_path=CHROME_PATH, headless=True,
                args=["--no-sandbox", "--disable-dev-shm-usage"] if CHROME_PATH else [],
            )
        _ctx = await _browser.new_context(viewport={"width": W, "height": H}, service_workers="block")
        await _ctx.route("**/*", _route)
        seed = {"ha_url": HA_URL, "ha_token": HA_TOKEN}
        if HOMEY_URL and HOMEY_TOKEN:
            seed.update(homey_url=HOMEY_URL, homey_token=HOMEY_TOKEN)
        await _ctx.add_init_script(
            "try{const s=%s;for(const k in s)localStorage.setItem(k,s[k]);}catch(e){}" % json.dumps(seed)
        )
        _page = await _ctx.new_page()
        _page.on("console", lambda m: _console.append(f"[{m.type}] {m.text}") if m.type in ("error", "warning") else None)
        _page.on("pageerror", lambda e: _console.append(f"[pageerror] {e}"))
        await _load(_page)
        return _page


async def _load(page):
    await page.goto(FOYER_URL + "/", wait_until="load")
    try:
        await page.wait_for_function("window.haClient && window.haClient.connected", timeout=15000)
    except Exception:
        pass  # state tool reports haConnected=false
    await page.evaluate(_HOOK)


@mcp.tool()
async def foyer_state() -> dict:
    """What Foyer is showing: HA connection, current room, ambient screen, visible toast, rail items, water heater state."""
    page = await _page_ready()
    return await page.evaluate(_STATE)


@mcp.tool()
async def foyer_screenshot() -> Image:
    """Screenshot of the headless Foyer page."""
    page = await _page_ready()
    return Image(data=await page.screenshot(type="png"), format="png")


@mcp.tool()
async def foyer_navigate(target: str) -> dict:
    """Go to a room or panel by its data-room id or label (see foyer_state.rooms), or "ambient" for the ambient screen."""
    page = await _page_ready()
    if target.lower() == "ambient":
        await page.evaluate("showAmbient()")
    else:
        await page.evaluate("document.getElementById('ambientOverlay')?.classList.remove('visible')")
        rail = page.locator(".rail-item")
        item = rail.filter(has=page.locator(f"xpath=self::*[@data-room='{target.lower()}']"))
        if await item.count() == 0:
            item = rail.filter(has_text=target)
        if await item.count() == 0:
            raise ValueError(f"No room matching {target!r}; see foyer_state.rooms")
        await item.first.click()
    await page.wait_for_timeout(400)
    return await page.evaluate(_STATE)


@mcp.tool()
async def foyer_press(text: str, send: bool = False) -> dict:
    """Click a visible button or control by its text (e.g. "Hot Water", "Run").

    Dry run by default: HA service calls the click triggers are recorded and
    returned but not sent. Pass send=True to actually fire them. If the
    ambient screen's overlay blocks a control, navigate to the room first.
    """
    page = await _page_ready()
    await page.evaluate("(s) => { window.__calls = []; window.__send = s; }", send)
    target = page.get_by_role("button", name=text, exact=True)
    if await target.count() == 0:
        target = page.get_by_text(text, exact=True)
    if await target.count() == 0:
        raise ValueError(f"No visible control with text {text!r}")
    await target.first.click(timeout=5000)
    await page.wait_for_timeout(700)
    calls = await page.evaluate("window.__calls || []")
    await page.evaluate("window.__send = false")
    return {"calls": calls, "state": await page.evaluate(_STATE)}


@mcp.tool()
async def foyer_console(clear: bool = True) -> list[str]:
    """Console errors/warnings and uncaught page errors since the last read."""
    await _page_ready()
    out = list(_console)
    if clear:
        _console.clear()
    return out


@mcp.tool()
async def foyer_reload() -> dict:
    """Reload Foyer (picks up a fresh deploy) and re-attach the call recorder."""
    page = await _page_ready()
    await _load(page)
    return await page.evaluate(_STATE)


class _BearerGate:
    """Rejects any HTTP request without the configured bearer token."""

    def __init__(self, app, token: str):
        self.app, self.expected = app, f"Bearer {token}".encode()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            got = dict(scope["headers"]).get(b"authorization", b"")
            if not hmac.compare_digest(got, self.expected):
                await send({"type": "http.response.start", "status": 401, "headers": [(b"content-type", b"text/plain")]})
                await send({"type": "http.response.body", "body": b"unauthorized"})
                return
        await self.app(scope, receive, send)


if __name__ == "__main__":
    if os.environ.get("FOYER_MCP_TRANSPORT", "stdio") == "http":
        import uvicorn

        from mcp.server.transport_security import TransportSecuritySettings

        mcp.settings.host, mcp.settings.port = "0.0.0.0", 8092
        # The bearer gate below is the access control; the default Host-header
        # allowlist only knows localhost and rejects LAN addresses.
        mcp.settings.transport_security = TransportSecuritySettings(enable_dns_rebinding_protection=False)
        uvicorn.run(_BearerGate(mcp.streamable_http_app(), os.environ["FOYER_MCP_TOKEN"]), host="0.0.0.0", port=8092)
    else:
        mcp.run()
