// Homey local API client for the PWA — plain REST/fetch, not a persistent
// socket like HAClient. Config-driven (see HomeyConfig in config.js), no
// token baked into this file. Deliberately minimal: only the handful of
// calls the app actually uses (read/set a device capability, list/trigger
// moods), not a general-purpose Homey SDK wrapper.

class HomeyClient {
  constructor(url, token) {
    this.url = url.replace(/\/$/, ""); // e.g. "http://192.168.3.159"
    this.token = token;
  }

  async _fetch(path, options = {}) {
    const res = await fetch(`${this.url}${path}`, {
      ...options,
      headers: {
        "Authorization": `Bearer ${this.token}`,
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`Homey ${res.status}: ${body || res.statusText}`);
    }
    return res.status === 204 ? null : res.json();
  }

  getDevice(deviceId) {
    return this._fetch(`/api/manager/devices/device/${deviceId}`);
  }

  setCapability(deviceId, capability, value) {
    return this._fetch(`/api/manager/devices/device/${deviceId}/capability/${capability}`, {
      method: "PUT",
      body: JSON.stringify({ value }),
    });
  }

  getMoods() {
    return this._fetch("/api/manager/moods/mood/");
  }

  triggerMood(moodId) {
    return this._fetch(`/api/manager/moods/mood/${moodId}/trigger`, { method: "POST" });
  }
}
