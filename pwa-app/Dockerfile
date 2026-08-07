# Static file server for the HA Wall Kiosk PWA. No build step — the app
# ships as plain HTML/CSS/JS, so this just serves it. No HA/Homey secrets
# are baked into the image: each device supplies its own long-lived
# token via the onboarding screen, stored in that device's localStorage.
# The Basic Auth password IS generated at container start (see
# entrypoint.sh) from env vars — this app is exposed via a Cloudflare
# Tunnel with no Access policy in front of it, so nginx has to be the
# actual login gate.
FROM nginx:alpine

RUN apk add --no-cache openssl

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY index.html config.js ha-client.js homey-client.js rooms.config.js \
     manifest.json sw.js /usr/share/nginx/html/
COPY icons/ /usr/share/nginx/html/icons/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://localhost/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
