"""
Homey local API client, exposed to QML as a QObject -- Python port of
pwa-app/homey-client.js. Same reasoning as the PWA: a second, direct
connection for the handful of real devices Home Assistant can't reach
(read-only sensor mirrors bridged via MQTT, or nothing at all), not a
general-purpose Homey SDK wrapper.

Unlike HAClient this is plain REST (Homey's local API), not a persistent
subscription -- polled on a timer, matching the PWA's pollDiningRoomAQ
pattern, since Homey's local API has no push/websocket path this app uses.
"""

import asyncio
import logging
import os

import aiohttp
import yaml
from PySide6.QtCore import QObject, Signal, Property, Slot, QTimer

log = logging.getLogger("homey_client")

POLL_INTERVAL_MS = 15_000


def load_config(path="config.yaml"):
    # Optional, unlike HA's load_config -- most areas don't need a second
    # connection at all. Returns None (skip starting HomeyClient entirely)
    # if the homey: block is missing or has no token, same "gracefully
    # absent" shape as the PWA's HomeyConfig.isConfigured() check.
    if not os.path.exists(path):
        return None
    with open(path) as f:
        cfg = yaml.safe_load(f)
    homey_cfg = cfg.get("homey") or {}
    token = os.environ.get("HOMEY_TOKEN") or homey_cfg.get("token")
    if not homey_cfg.get("url") or not token:
        return None
    return {
        "url": homey_cfg["url"],
        "token": token,
        "device_ids": homey_cfg.get("device_ids") or [],
    }


class HomeyClient(QObject):
    connectionChanged = Signal(bool)
    devicesChanged = Signal()

    def __init__(self, config, parent=None):
        super().__init__(parent)
        self._url = config["url"].rstrip("/")
        self._token = config["token"]
        self._device_ids = config["device_ids"]  # list of Homey device IDs to track
        self._connected = False
        self._devices = {}  # device_id -> raw Homey device dict
        self._session = None

        self._poll_timer = QTimer(self)
        self._poll_timer.timeout.connect(lambda: asyncio.ensure_future(self._poll_all()))

    # ---------- Qt-exposed properties ----------

    def _get_connected(self):
        return self._connected

    connected = Property(bool, _get_connected, notify=connectionChanged)

    def _get_devices(self):
        # Flat list, QML-friendly -- one dict per tracked device with just
        # what the UI needs (name, onoff state), not the full raw Homey
        # payload.
        result = []
        for device_id in self._device_ids:
            device = self._devices.get(device_id)
            if device is None:
                continue
            caps = device.get("capabilitiesObj") or {}
            onoff = caps.get("onoff")
            result.append({
                "id": device_id,
                "name": device.get("name", device_id),
                "on": bool(onoff["value"]) if onoff else False,
                "available": device.get("available", False),
            })
        return result

    devices = Property("QVariantList", _get_devices, notify=devicesChanged)

    # ---------- lifecycle ----------

    @Slot()
    def start(self):
        asyncio.ensure_future(self._poll_all())
        self._poll_timer.start(POLL_INTERVAL_MS)

    async def _get_session(self):
        if self._session is None:
            self._session = aiohttp.ClientSession(
                headers={"Authorization": f"Bearer {self._token}"},
                timeout=aiohttp.ClientTimeout(total=10),
            )
        return self._session

    async def _poll_all(self):
        session = await self._get_session()
        ok = True
        for device_id in self._device_ids:
            try:
                async with session.get(f"{self._url}/api/manager/devices/device/{device_id}") as resp:
                    resp.raise_for_status()
                    self._devices[device_id] = await resp.json()
            except Exception as exc:
                log.warning("Homey getDevice(%s) failed: %s", device_id, exc)
                ok = False
        self._set_connected(ok)
        self.devicesChanged.emit()

    def _set_connected(self, value):
        if value != self._connected:
            self._connected = value
            self.connectionChanged.emit(value)

    # ---------- write path ----------

    @Slot(str, bool)
    def setOnOff(self, device_id, value):
        asyncio.ensure_future(self._set_capability(device_id, "onoff", value))

    async def _set_capability(self, device_id, capability, value):
        session = await self._get_session()
        try:
            async with session.put(
                f"{self._url}/api/manager/devices/device/{device_id}/capability/{capability}",
                json={"value": value},
            ) as resp:
                resp.raise_for_status()
        except Exception as exc:
            log.warning("Homey setCapability(%s, %s) failed: %s", device_id, capability, exc)
            return
        # Same "verify against real state, don't trust the optimistic UI"
        # discipline as the PWA build -- re-poll this one device right
        # after the write instead of waiting for the next timer tick.
        await self._poll_all()
