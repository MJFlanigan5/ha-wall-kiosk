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

  // Logic variables (Homey's boolean/number/text globals) — used to read a
  // toggle-style flow's current state (e.g. Vacation Mode) so a Foyer button
  // can illuminate correctly instead of guessing. Same map-not-array shape
  // as listDevices/listZones/listFlows.
  async getLogicVariables() {
    const map = await this._fetch("/api/manager/logic/variable/");
    return Object.values(map || {});
  }

  // Starts an Advanced Flow's "start" node — the same mechanism the Homey
  // app's own flow "play" button uses. Only works on flows built with a
  // start node (no regular trigger card); Homey returns an error otherwise,
  // which callers should surface rather than swallow.
  triggerAdvancedFlow(flowId) {
    return this._fetch(`/api/manager/flow/advancedflow/${flowId}/trigger`, { method: "POST" });
  }

  // Both return an { id: {...} } map, not an array — Homey's own API shape
  // when no specific ID is given. Used by device discovery (Admin Mode's
  // Climate picker), not by any always-on polling path.
  async listDevices() {
    const map = await this._fetch("/api/manager/devices/device/");
    return Object.values(map || {});
  }

  async listZones() {
    const map = await this._fetch("/api/manager/zones/zone/");
    return Object.values(map || {});
  }

  // Used by the Health check (broken flows) — same map-not-array shape as
  // listDevices/listZones above.
  async listFlows() {
    const map = await this._fetch("/api/manager/flow/flow/");
    return Object.values(map || {});
  }
}

// Capability introspection is generic on purpose: it keys off Homey's own
// standard capability-id vocabulary (target_temperature[.sub], measure_*,
// setable enum ids containing "mode") rather than any one vendor's device,
// so any Homey thermostat-class device works here, not just the Nest this
// was built against (see homeyThermostatCapabilities usage in index.html).
//
// Requires BOTH Homey's own semantic device.class ("thermostat" -- Homey's
// standard taxonomy, the same field every Homey app sets regardless of
// vendor) AND the capability check, not capability alone (found 2026-08-07:
// other device types, e.g. some water heater apps, also expose a
// target_temperature-shaped setpoint capability, which capability-matching
// alone would misclassify as a thermostat).
function isHomeyThermostat(device) {
  return device.class === "thermostat" && (device.capabilities || []).some(c => c.startsWith("target_temperature"));
}

function homeyThermostatCapabilities(device) {
  const caps = device.capabilitiesObj || {};
  const all = Object.values(caps);
  return {
    measureTemp: caps["measure_temperature"] || null,
    measureHumidity: caps["measure_humidity"] || null,
    targets: all.filter(c => c.setable && c.id.startsWith("target_temperature")),
    modeCap: all.find(c => c.setable && c.type === "enum" && /mode/i.test(c.id)) || null,
    activityCap: all.find(c => !c.setable && c.type === "enum" && /(hvac|activity)/i.test(c.id)) || null,
  };
}
