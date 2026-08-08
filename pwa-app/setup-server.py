#!/usr/bin/env python3
"""First-run setup for Foyer's Basic Auth login — served in-browser at
/setup. Before setup, nginx is running nginx-presetup.conf, which sends
every path (not just /setup) here unauthenticated, since no credential
exists yet. Same security model Home Assistant and Homey themselves use
for their own first-run setup: whoever's first to the browser right after
a fresh deploy sets the login, no separate token to go find — the real
gate is deliberately choosing when to point a public tunnel at this
container, not a secret required to complete setup. On success, this
swaps nginx to nginx-postsetup.conf and reloads it, so Basic Auth takes
effect immediately without a container restart. Once .htpasswd exists,
every request here is refused regardless of what's submitted — setup can
only happen once per deploy; delete .htpasswd on the host to redo it.

Stdlib only, no dependencies — same "no build step" principle as the rest
of this image. Binds to 127.0.0.1 only; nginx is the only thing that can
reach it, never exposed directly.
"""
import http.server
import os
import subprocess
import time
import urllib.parse

HTPASSWD_PATH = "/etc/nginx/.htpasswd"

PAGE_STYLE = """
<style>
  body { margin:0; background:#0A0A0C; color:#EDEDEF; display:flex; align-items:center;
    justify-content:center; min-height:100vh; font-family:-apple-system,BlinkMacSystemFont,sans-serif; }
  .card { width:min(420px,90vw); }
  h2 { font-size:20px; margin-bottom:4px; }
  p { opacity:0.6; font-size:13px; margin-bottom:20px; }
  input { width:100%; box-sizing:border-box; padding:12px; margin-bottom:10px; background:#18181B;
    border:1px solid #2A2A2E; border-radius:8px; color:#EDEDEF; font-size:14px; }
  button { width:100%; padding:14px; background:#3CCB7F; border:none; border-radius:8px;
    color:#0A0A0C; font-weight:600; font-size:15px; cursor:pointer; margin-top:6px; }
  .error { color:#FF6B6B; font-size:13px; margin-top:12px; }
  a { color:#3CCB7F; }
</style>
"""


def already_configured():
    return os.path.exists(HTPASSWD_PATH)


def hash_password(password):
    result = subprocess.run(
        ["openssl", "passwd", "-apr1", password],
        capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


def render(body, error=""):
    error_html = f'<p class="error">{error}</p>' if error else ""
    return f"<!doctype html><html><head>{PAGE_STYLE}</head><body><div class=\"card\">{body}{error_html}</div></body></html>"


SETUP_FORM = """
<h2>Set up Foyer</h2>
<p>One-time setup for this install — choose the login you'll use going forward.</p>
<form method="POST" action="/setup">
  <input name="username" placeholder="Username" autocomplete="username" />
  <input name="password" type="password" placeholder="Password" autocomplete="new-password" />
  <button type="submit">Create login</button>
</form>
"""

ALREADY_DONE = """
<h2>Already set up</h2>
<p>This install already has a login configured. Delete <code>.htpasswd</code>
on the host if you need to redo it.</p>
<p><a href="/">Go to Foyer</a></p>
"""

# Deliberately no clever verification here, after trying two and finding
# each one broke something new: server-side polling from inside this
# request severed the connection every time (this request is proxied
# through the very nginx worker the reload recycles — confirmed live,
# "upstream prematurely closed connection"), and a client-side fetch()
# loop hung indefinitely instead (confirmed live via CDP timeout — same
# underlying live-reload fragility, different symptom). Both attempts
# were chasing "prove it's instant," which isn't actually true — nginx's
# graceful reload takes a real, if short, amount of time no matter how
# it's observed. Being honest about that in the copy, combined with the
# plain wait below before responding, is more robust than a verification
# mechanism with its own undiscovered failure modes.
SUCCESS = """
<h2>Foyer's ready</h2>
<p>Your login is set. It can take a couple of seconds to fully take effect —
if the next page doesn't prompt you to log in, wait a moment and reload.</p>
<p><a href="/">Go to Foyer</a></p>
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep container logs quiet — no ongoing reason to log setup requests

    def _respond(self, code, html):
        body = html.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        # Not restricted to literally "/setup" — nginx-presetup.conf routes
        # every path here (so landing on "/" itself shows this directly,
        # no redirect needed), while nginx-postsetup.conf only ever routes
        # "/setup" specifically. Either way, nginx's own config is what
        # decides when this backend is reachable at all, not this check.
        self._respond(200, render(ALREADY_DONE if already_configured() else SETUP_FORM))

    def do_POST(self):
        if self.path.rstrip("/") != "/setup":
            self._respond(404, render("<h2>Not found</h2>"))
            return
        if already_configured():
            self._respond(403, render(ALREADY_DONE))
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        params = urllib.parse.parse_qs(body)
        username = (params.get("username") or [""])[0].strip()
        password = (params.get("password") or [""])[0]

        if not username or not password:
            self._respond(400, render(SETUP_FORM, error="Username and password are both required."))
            return

        password_hash = hash_password(password)
        # "x" mode, not "w" — atomically fails if the file already exists
        # instead of just checking-then-writing, which would leave a race
        # window where two near-simultaneous POSTs could both pass the
        # already_configured() check above and the second overwrite the
        # first admin's credential.
        try:
            with open(HTPASSWD_PATH, "x") as f:
                f.write(f"{username}:{password_hash}\n")
        except FileExistsError:
            self._respond(403, render(ALREADY_DONE))
            return

        # nginx is currently running the wide-open pre-setup config (see
        # nginx-presetup.conf) — swap in the real gated one and reload so
        # Basic Auth takes effect. `nginx -s reload`'s worker drain is
        # asynchronous, so the command returning doesn't guarantee the old
        # auth-free workers are gone yet — confirmed live, twice, that
        # trying to actively verify this from inside the same request only
        # made things worse: polling nginx from here got this exact
        # connection severed ("upstream prematurely closed connection",
        # since it's proxied through the very worker being recycled), and
        # moving that same poll to client-side JS just hung indefinitely
        # instead, presumably the same underlying fragility surfacing
        # differently. A plain wait here isn't a hard guarantee either, but
        # it's the one approach that hasn't broken something new across
        # several dozen live tests — worker drain consistently completed
        # well within it. Without any wait at all, confirmed live that
        # auth was NOT yet enforced immediately after responding.
        subprocess.run(
            ["cp", "/etc/nginx/templates/nginx-postsetup.conf", "/etc/nginx/conf.d/default.conf"],
            check=True,
        )
        subprocess.run(["nginx", "-s", "reload"], check=True)
        time.sleep(1)

        self._respond(200, render(SUCCESS))


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", 8081), Handler).serve_forever()
