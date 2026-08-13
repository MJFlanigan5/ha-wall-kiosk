#!/usr/bin/env python3
"""First-run setup + login for Foyer — served in-browser at /setup and
/login. Before setup, nginx is running nginx-presetup.conf, which sends
every path (not just /setup) here unauthenticated, since no credential
exists yet. Same security model Home Assistant and Homey themselves use
for their own first-run setup: whoever's first to the browser right after
a fresh deploy sets the login, no separate token to go find — the real
gate is deliberately choosing when to point a public tunnel at this
container, not a secret required to complete setup. On success, this
swaps nginx to nginx-postsetup.conf and reloads it, so the login gate
takes effect immediately without a container restart. Once .htpasswd
exists, every request here is refused regardless of what's submitted —
setup can only happen once per deploy; delete .htpasswd on the host to
redo it.

Login itself (2026-08-13) replaced nginx's Basic Auth with a real
in-browser page — Basic Auth's native browser credential prompt can't be
restyled and re-prompts on every browser restart with no way to log out.
nginx-postsetup.conf now gates every path with `auth_request /auth-check`
against this same process instead of `auth_basic`; a session cookie
(HttpOnly, not JS-readable) replaces the credential being resent on every
request. Sessions are kept in a small JSON file next to .htpasswd (same
mounted volume) so logins survive a redeploy, not just an in-memory dict
that would forget everyone on every `docker compose up --build`.

Deliberately no "Secure" cookie flag: this container never terminates TLS
itself (Cloudflare Tunnel does, from a plain-HTTP hop to nginx), so nginx
has no reliable way to tell whether the browser's own connection was
HTTPS — a wrong guess there would silently break login instead of just
skipping a flag. HttpOnly + SameSite=Lax + a 256-bit random token is the
actual security boundary; Basic Auth had no equivalent protection at all
(it retransmits the real password on every single request, this system
only sends it once at login), so this is strictly safer, not a regression.

Stdlib only, no dependencies — same "no build step" principle as the rest
of this image. Binds to 127.0.0.1 only; nginx is the only thing that can
reach it, never exposed directly.
"""
import hmac
import http.server
import json
import os
import secrets
import subprocess
import time
import urllib.parse
from http.cookies import SimpleCookie

HTPASSWD_PATH = "/etc/nginx/auth/.htpasswd"
SESSIONS_PATH = "/etc/nginx/auth/sessions.json"
SESSION_COOKIE = "foyer_session"
SESSION_TTL = 60 * 60 * 24 * 30  # 30 days — a wall kiosk/phone should stay logged in

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


# .htpasswd's apr1 hash is "$apr1$<salt>$<digest>" — re-hashing the
# submitted password with the same salt and comparing the full string is
# the standard way to verify it without a pure-Python apr1-md5 implementation.
def verify_password(username, password):
    if not already_configured():
        return False
    try:
        with open(HTPASSWD_PATH) as f:
            line = f.readline().strip()
    except OSError:
        return False
    if ":" not in line:
        return False
    stored_user, stored_hash = line.split(":", 1)
    parts = stored_hash.split("$")
    if len(parts) < 4 or parts[1] != "apr1":
        return False
    salt = parts[2]
    result = subprocess.run(
        ["openssl", "passwd", "-apr1", "-salt", salt, password],
        capture_output=True, text=True, check=True,
    )
    candidate = result.stdout.strip()
    # Both comparisons run unconditionally (not `and` short-circuited on
    # username first) so a wrong username doesn't return faster than a
    # wrong password would — hmac.compare_digest already defends the
    # per-string comparison, this defends against timing the username too.
    user_ok = hmac.compare_digest(stored_user, username)
    hash_ok = hmac.compare_digest(candidate, stored_hash)
    return user_ok and hash_ok


def load_sessions():
    try:
        with open(SESSIONS_PATH) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}
    now = time.time()
    return {token: exp for token, exp in data.items() if exp > now}


def save_sessions(sessions):
    tmp = SESSIONS_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(sessions, f)
    os.replace(tmp, SESSIONS_PATH)


# Loaded once at process start (this server runs single-threaded — see
# HTTPServer, not ThreadingHTTPServer — so no lock is needed around this).
SESSIONS = load_sessions()


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

LOGIN_FORM = """
<h2>Foyer</h2>
<p>Sign in to continue.</p>
<form method="POST" action="/login">
  <input name="username" placeholder="Username" autocomplete="username" autofocus />
  <input name="password" type="password" placeholder="Password" autocomplete="current-password" />
  <button type="submit">Log in</button>
</form>
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
<p>Your login is set and you're signed in on this device already.</p>
<p><a href="/">Go to Foyer</a></p>
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep container logs quiet — no ongoing reason to log setup/login requests

    def _respond(self, code, html, extra_headers=None):
        body = html.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        for key, value in (extra_headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, location, extra_headers=None):
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        for key, value in (extra_headers or {}).items():
            self.send_header(key, value)
        self.end_headers()

    def _session_cookie_header(self, token, max_age=SESSION_TTL):
        # No Secure flag — see module docstring. max_age=0 clears the
        # cookie (used by logout) while reusing the same header shape.
        return f"{SESSION_COOKIE}={token}; HttpOnly; SameSite=Lax; Max-Age={max_age}; Path=/"

    def _start_session(self):
        token = secrets.token_urlsafe(32)
        SESSIONS[token] = time.time() + SESSION_TTL
        save_sessions(SESSIONS)
        return token

    def _current_session_token(self):
        cookie_header = self.headers.get("Cookie")
        if not cookie_header:
            return None
        cookie = SimpleCookie()
        try:
            cookie.load(cookie_header)
        except Exception:
            return None
        morsel = cookie.get(SESSION_COOKIE)
        return morsel.value if morsel else None

    def _is_authenticated(self):
        token = self._current_session_token()
        if not token:
            return False
        exp = SESSIONS.get(token)
        return exp is not None and exp > time.time()

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/")

        # Internal-only in nginx (see nginx-postsetup.conf) — never
        # reachable directly from outside the container either way, since
        # this process only binds 127.0.0.1.
        if path == "/auth-check":
            self._respond(200 if self._is_authenticated() else 401, "")
            return

        if path == "/login":
            if self._is_authenticated():
                self._redirect("/")
                return
            self._respond(200, render(LOGIN_FORM))
            return

        if path == "/logout":
            token = self._current_session_token()
            if token:
                SESSIONS.pop(token, None)
                save_sessions(SESSIONS)
            self._redirect("/login", {"Set-Cookie": self._session_cookie_header("", max_age=0)})
            return

        # Not restricted to literally "/setup" — nginx-presetup.conf routes
        # every path here (so landing on "/" itself shows this directly,
        # no redirect needed), while nginx-postsetup.conf only ever routes
        # "/setup" specifically. Either way, nginx's own config is what
        # decides when this backend is reachable at all, not this check.
        self._respond(200, render(ALREADY_DONE if already_configured() else SETUP_FORM))

    def do_POST(self):
        path = self.path.split("?", 1)[0].rstrip("/")

        if path == "/login":
            self._handle_login()
            return

        if path != "/setup":
            self._respond(404, render("<h2>Not found</h2>"))
            return
        self._handle_setup()

    def _handle_login(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        params = urllib.parse.parse_qs(body)
        username = (params.get("username") or [""])[0].strip()
        password = (params.get("password") or [""])[0]

        if not verify_password(username, password):
            self._respond(401, render(LOGIN_FORM, error="Incorrect username or password."))
            return

        token = self._start_session()
        self._redirect("/", {"Set-Cookie": self._session_cookie_header(token)})

    def _handle_setup(self):
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
        # the login gate takes effect. `nginx -s reload`'s worker drain is
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

        # Log the creator in immediately — without this, "Go to Foyer"
        # would just bounce back to a fresh /login even though they set
        # the password ten seconds ago.
        token = self._start_session()
        self._respond(200, render(SUCCESS), {"Set-Cookie": self._session_cookie_header(token)})


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", 8081), Handler).serve_forever()
