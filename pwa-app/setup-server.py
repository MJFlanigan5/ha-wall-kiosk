#!/usr/bin/env python3
"""First-run setup for Foyer's Basic Auth login — served in-browser at
/setup (nginx proxies it here, unauthenticated, since no credential exists
yet on first boot). Requires the one-time setup token entrypoint.sh printed
to the container logs, in addition to the username/password being chosen —
that token is what stops anyone who just finds the page on the LAN from
completing setup themselves; only whoever can read the container's logs
(i.e. whoever deployed it) has it. Once .htpasswd exists, every request
here is refused regardless of what's submitted — setup can only happen
once per deploy; delete .htpasswd on the host to redo it.

Stdlib only, no dependencies — same "no build step" principle as the rest
of this image. Binds to 127.0.0.1 only; nginx is the only thing that can
reach it, never exposed directly.
"""
import hmac
import http.server
import os
import subprocess
import urllib.parse

HTPASSWD_PATH = "/etc/nginx/.htpasswd"
SETUP_TOKEN = os.environ.get("SETUP_TOKEN", "")

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
<p>One-time setup for this install. The setup token is in the container's logs
(<code>docker compose logs</code>) — only whoever deployed this can see it.</p>
<form method="POST" action="/setup">
  <input name="token" placeholder="Setup token" autocomplete="off" />
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

SUCCESS = """
<h2>Foyer's ready</h2>
<p>Your login is set. Use it the next time you're prompted.</p>
<p><a href="/">Go to Foyer</a></p>
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # container logs stay reserved for the setup token, not request noise

    def _respond(self, code, html):
        body = html.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") != "/setup":
            self._respond(404, render("<h2>Not found</h2>"))
            return
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
        token = (params.get("token") or [""])[0]
        username = (params.get("username") or [""])[0].strip()
        password = (params.get("password") or [""])[0]

        # Constant-time comparison — this token is the actual secret guarding
        # setup now, so it deserves the same care as a real credential check,
        # not a plain == that leaks timing info.
        if not SETUP_TOKEN or not hmac.compare_digest(token, SETUP_TOKEN):
            self._respond(403, render(SETUP_FORM, error="Wrong or missing setup token."))
            return
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
        self._respond(200, render(SUCCESS))


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", 8081), Handler).serve_forever()
