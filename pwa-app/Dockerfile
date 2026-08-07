# Static file server for the HA Wall Kiosk PWA. No build step — the app
# ships as plain HTML/CSS/JS, so this just serves it. No HA/Homey secrets
# are baked into the image: each device supplies its own long-lived
# token via the onboarding screen, stored in that device's localStorage.
# The Basic Auth password is set either from env vars (scripted deploys)
# or through the in-browser /setup screen (setup-server.py) on first boot
# — this app is exposed via a Cloudflare Tunnel with no Access policy in
# front of it, so nginx has to be the actual login gate either way.
FROM nginx:alpine

RUN apk add --no-cache openssl python3

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
COPY setup-server.py /setup-server.py
RUN chmod +x /entrypoint.sh

COPY index.html config.js ha-client.js homey-client.js rooms.config.js \
     manifest.json sw.js /usr/share/nginx/html/
COPY icons/ /usr/share/nginx/html/icons/

EXPOSE 80

# 127.0.0.1, not localhost — found via actually running the container that
# BusyBox wget resolves "localhost" to ::1 first per /etc/hosts, and nginx
# only listens on 0.0.0.0:80 (IPv4), not [::]:80, so every check failed
# with "Connection refused" despite the app being genuinely reachable over
# real (IPv4) traffic the whole time.
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
