# Static file server for the HA Wall Kiosk PWA. No build step — the app
# ships as plain HTML/CSS/JS, so this just serves it. No secrets are baked
# into the image: each device supplies its own HA URL + long-lived token
# via the onboarding screen, stored in that device's localStorage.
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY index.html config.js ha-client.js homey-client.js rooms.config.js \
     manifest.json sw.js /usr/share/nginx/html/
COPY icons/ /usr/share/nginx/html/icons/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://localhost/ || exit 1
