// Runtime config: HA URL + long-lived access token, entered once per
// device and stored in localStorage. No build-time secrets file, no
// token baked into any committed file — each device (iPad, phone) gets
// configured independently the first time it opens the app.

const HAConfig = {
  get() {
    return {
      url: localStorage.getItem("ha_url") || "",
      token: localStorage.getItem("ha_token") || "",
    };
  },
  set(url, token) {
    localStorage.setItem("ha_url", url);
    localStorage.setItem("ha_token", token);
  },
  isConfigured() {
    const { url, token } = this.get();
    return Boolean(url && token);
  },
};

function showOnboarding(onDone) {
  const overlay = document.createElement("div");
  overlay.style.cssText = `
    position:fixed; inset:0; background:#0A0A0C; color:#EDEDEF;
    display:flex; align-items:center; justify-content:center; z-index:9999;
    font-family:-apple-system,BlinkMacSystemFont,sans-serif;
  `;
  overlay.innerHTML = `
    <div style="width:min(420px,90vw);">
      <h2 style="font-size:20px;margin-bottom:4px;">Connect to Home Assistant</h2>
      <p style="opacity:0.6;font-size:13px;margin-bottom:20px;">
        One-time setup for this device. Get a long-lived access token from
        your HA profile → Security → Long-lived access tokens.
      </p>
      <input id="ha-url-input" placeholder="ws://homeassistant.local:8123/api/websocket"
        style="width:100%;padding:12px;margin-bottom:10px;background:#18181B;border:1px solid #2A2A2E;border-radius:8px;color:#EDEDEF;font-size:14px;" />
      <textarea id="ha-token-input" placeholder="Long-lived access token"
        style="width:100%;padding:12px;margin-bottom:16px;background:#18181B;border:1px solid #2A2A2E;border-radius:8px;color:#EDEDEF;font-size:14px;height:80px;resize:none;"></textarea>
      <button id="ha-connect-btn"
        style="width:100%;padding:14px;background:#3CCB7F;border:none;border-radius:8px;color:#0A0A0C;font-weight:600;font-size:15px;">
        Connect
      </button>
      <p id="ha-error" style="color:#FF6B6B;font-size:13px;margin-top:12px;"></p>
    </div>
  `;
  document.body.appendChild(overlay);

  document.getElementById("ha-connect-btn").addEventListener("click", async () => {
    const url = document.getElementById("ha-url-input").value.trim();
    const token = document.getElementById("ha-token-input").value.trim();
    const errorEl = document.getElementById("ha-error");
    if (!url || !token) {
      errorEl.textContent = "Both fields are required.";
      return;
    }
    HAConfig.set(url, token);
    overlay.remove();
    onDone();
  });
}
