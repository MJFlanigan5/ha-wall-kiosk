// Home Assistant WebSocket client for the PWA.
// Mirrors native-app/ha_client.py's approach (auth, subscribe, registries,
// service calls) but in vanilla JS for the browser/PWA runtime.
//
// Config-driven, not hardcoded: URL and token come from HAConfig
// (see config.js), never baked into this file.

class HAClient {
  constructor(url, token) {
    this.url = url; // e.g. "ws://homeassistant.local:8123/api/websocket"
    this.token = token;
    this.ws = null;
    this.msgId = 1;
    this.pending = new Map(); // id -> {resolve, reject}
    this.stateListeners = new Set();
    this.connected = false;
    this.connectionListeners = new Set();
    this._reconnectDelay = 1000;
    this._reconnectTimer = null;
    this._setupResumeListeners();
  }

  // Mobile browsers throttle/suspend timers and WebSockets while
  // backgrounded, so a phone reopened after sleep can sit on a stale
  // connection for up to the full backoff delay before the next retry
  // fires on its own. Force an immediate reconnect attempt as soon as
  // the tab is visible again or the network comes back, instead of
  // waiting on the timer.
  _setupResumeListeners() {
    if (typeof document !== "undefined") {
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "visible") this._forceReconnectNow();
      });
    }
    if (typeof window !== "undefined") {
      window.addEventListener("online", () => this._forceReconnectNow());
    }
  }

  _forceReconnectNow() {
    if (this.connected) return;
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
    this._reconnectDelay = 1000;
    this.connect().catch(() => {});
  }

  onStateChanged(fn) {
    this.stateListeners.add(fn);
    return () => this.stateListeners.delete(fn);
  }

  onConnectionChange(fn) {
    this.connectionListeners.add(fn);
    return () => this.connectionListeners.delete(fn);
  }

  _setConnected(isConnected) {
    this.connected = isConnected;
    for (const fn of this.connectionListeners) fn(isConnected);
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);

      this.ws.onopen = () => {
        // wait for auth_required before sending auth
      };

      this.ws.onerror = (err) => {
        if (!this.connected) reject(err);
      };

      this.ws.onclose = () => {
        this._setConnected(false);
        this._scheduleReconnect();
      };

      this.ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);

        if (msg.type === "auth_required") {
          this.ws.send(JSON.stringify({ type: "auth", access_token: this.token }));
          return;
        }

        if (msg.type === "auth_ok") {
          this._setConnected(true);
          this._reconnectDelay = 1000;
          this._subscribeStateChanged();
          resolve();
          return;
        }

        if (msg.type === "auth_invalid") {
          this._setConnected(false);
          reject(new Error("HA auth failed: " + msg.message));
          return;
        }

        if (msg.type === "event" && msg.event?.event_type === "state_changed") {
          const { entity_id, new_state } = msg.event.data;
          for (const fn of this.stateListeners) fn(entity_id, new_state);
          return;
        }

        if (msg.type === "result" && this.pending.has(msg.id)) {
          const { resolve: res, reject: rej } = this.pending.get(msg.id);
          this.pending.delete(msg.id);
          if (msg.success) res(msg.result);
          else rej(new Error(msg.error?.message || "HA command failed"));
          return;
        }
      };
    });
  }

  _scheduleReconnect() {
    this._reconnectTimer = setTimeout(() => {
      this._reconnectTimer = null;
      this.connect().catch(() => {});
    }, this._reconnectDelay);
    this._reconnectDelay = Math.min(this._reconnectDelay * 2, 30000);
  }

  _send(payload) {
    return new Promise((resolve, reject) => {
      const id = this.msgId++;
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, ...payload }));
    });
  }

  _subscribeStateChanged() {
    this._send({ type: "subscribe_events", event_type: "state_changed" }).catch(() => {});
  }

  async getStates() {
    return this._send({ type: "get_states" });
  }

  async getAreaRegistry() {
    return this._send({ type: "config/area_registry/list" });
  }

  async getEntityRegistry() {
    return this._send({ type: "config/entity_registry/list" });
  }

  async callService(domain, service, entityId, serviceData = {}) {
    return this._send({
      type: "call_service",
      domain,
      service,
      target: { entity_id: entityId },
      service_data: serviceData,
    });
  }
}
