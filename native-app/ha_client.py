"""
Home Assistant WebSocket client, exposed to QML as a QObject.

Config-driven and area-registry-driven on purpose (see docs/NATIVE_APP_SPEC.md
"Design principle: config-driven, not hardcoded to one home") -- this reads
whatever areas/entities actually exist in the connected HA instance rather
than assuming any particular home's room layout.

HA WebSocket API reference: https://developers.home-assistant.io/docs/api/websocket
"""

import asyncio
import json
import logging
import os

import websockets
import yaml
from PySide6.QtCore import QObject, Signal, Property, Slot, QTimer

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("ha_client")


def load_config(path="config.yaml"):
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"{path} not found -- copy config.example.yaml to {path} and fill in your HA URL/token."
        )
    with open(path) as f:
        cfg = yaml.safe_load(f)
    token = os.environ.get("HA_TOKEN") or cfg["home_assistant"].get("token")
    if not token:
        raise ValueError(
            "No Home Assistant token found. Set it in config.yaml or the HA_TOKEN environment variable."
        )
    display_cfg = cfg.get("display") or {}
    return {
        "url": cfg["home_assistant"]["url"],
        "token": token,
        "areas_filter": display_cfg.get("areas") or [],
        "orientation": display_cfg.get("orientation") or "portrait",
        "excluded_entities": set(display_cfg.get("excluded_entities") or []),
    }


class HAClient(QObject):
    connectionChanged = Signal(bool)
    areasChanged = Signal()

    def __init__(self, config, parent=None):
        super().__init__(parent)
        self._config = config
        self._connected = False
        self._msg_id = 0
        self._ws = None
        self._areas = {}       # area_id -> {"id", "name", "entities": {entity_id: {...}}}
        self._device_area = {} # device_id -> area_id
        self._entity_area = {} # entity_id -> area_id (direct or via device)

        # Debounces areasChanged so a burst of unrelated state_changed
        # events (common in a real house) collapses into one QML rebuild
        # instead of one per event -- see _request_areas_update.
        self._areas_update_timer = QTimer(self)
        self._areas_update_timer.setSingleShot(True)
        self._areas_update_timer.timeout.connect(self.areasChanged.emit)

    # ---------- Qt-exposed properties ----------

    def _get_connected(self):
        return self._connected

    connected = Property(bool, _get_connected, notify=connectionChanged)

    def _get_areas(self):
        areas_filter = self._config["areas_filter"]
        result = []
        for area in self._areas.values():
            if areas_filter and area["name"] not in areas_filter:
                continue
            entities = list(area["entities"].values())
            # Real, recurring problem in this instance (and flagged in
            # NATIVE_APP_SPEC.md as expected, not a one-off): area
            # registries carry stale/duplicate entities left behind by
            # integration re-adds. "unavailable" is the cheap, reliable
            # signal that a given entity is one of those, not the live
            # one -- same defense already proven in the PWA's Admin Mode.
            excluded = self._config["excluded_entities"]
            lights = [
                e for e in entities
                if e["domain"] == "light" and e["state"] != "unavailable" and e["entity_id"] not in excluded
            ]
            result.append({
                "id": area["id"],
                "name": area["name"],
                "entities": entities,
                "lightEntityIds": [e["entity_id"] for e in lights],
                "lightsOn": sum(1 for e in lights if e["state"] == "on"),
                "lightsTotal": len(lights),
            })
        result.sort(key=lambda a: a["name"])
        return result

    areas = Property("QVariantList", _get_areas, notify=areasChanged)

    # ---------- connection lifecycle ----------

    @Slot()
    def start(self):
        asyncio.ensure_future(self._run_forever())

    @Slot(str, str, list)
    def callService(self, domain, service, entity_ids):
        # Fire-and-forget from QML's perspective -- the UI doesn't wait on
        # this call's response, it waits on the state_changed event that
        # follows over the existing subscription (same "don't trust the
        # optimistic UI, verify the real state" discipline the PWA build
        # settled on). No-op if the connection isn't up yet.
        if self._ws is None or not self._connected:
            log.warning("callService(%s.%s) dropped -- not connected", domain, service)
            return
        asyncio.ensure_future(self._call_service(domain, service, entity_ids))

    async def _call_service(self, domain, service, entity_ids):
        msg_id = self._next_id()
        await self._ws.send(json.dumps({
            "id": msg_id,
            "type": "call_service",
            "domain": domain,
            "service": service,
            "target": {"entity_id": entity_ids},
        }))

    async def _run_forever(self):
        backoff = 1
        while True:
            try:
                await self._connect_and_listen()
            except Exception as exc:
                log.warning("HA connection lost/failed: %s -- retrying in %ss", exc, backoff)
            self._set_connected(False)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 30)

    def _set_connected(self, value):
        if value != self._connected:
            self._connected = value
            self.connectionChanged.emit(value)

    def _next_id(self):
        self._msg_id += 1
        return self._msg_id

    async def _connect_and_listen(self):
        log.info("Connecting to %s", self._config["url"])
        # max_size=None: this instance's registry/state dumps exceed the
        # websockets library's 1MiB default frame limit (hundreds of
        # entities across many integrations) — confirmed via a real
        # connection attempt (2026-08-06), not a hypothetical.
        async with websockets.connect(self._config["url"], max_size=None) as ws:
            self._ws = ws

            hello = json.loads(await ws.recv())
            if hello.get("type") != "auth_required":
                raise RuntimeError(f"Unexpected handshake message: {hello}")

            await ws.send(json.dumps({"type": "auth", "access_token": self._config["token"]}))
            auth_result = json.loads(await ws.recv())
            if auth_result.get("type") != "auth_ok":
                raise RuntimeError(f"Home Assistant auth failed: {auth_result}")

            log.info("Authenticated (HA %s)", auth_result.get("ha_version", "?"))
            self._set_connected(True)

            await self._load_registries(ws)
            await self._subscribe_state_changed(ws)

            async for raw in ws:
                await self._handle_message(json.loads(raw))

    async def _send_command(self, ws, msg_type, **kwargs):
        msg_id = self._next_id()
        await ws.send(json.dumps({"id": msg_id, "type": msg_type, **kwargs}))
        while True:
            raw = json.loads(await ws.recv())
            if raw.get("id") == msg_id:
                return raw
            # a subscription event or another command's response arrived
            # out of order -- hand it to the general dispatcher instead
            # of dropping it.
            await self._handle_message(raw)

    async def _load_registries(self, ws):
        areas_resp = await self._send_command(ws, "config/area_registry/list")
        for area in areas_resp["result"]:
            self._areas[area["area_id"]] = {"id": area["area_id"], "name": area["name"], "entities": {}}

        devices_resp = await self._send_command(ws, "config/device_registry/list")
        for device in devices_resp["result"]:
            if device.get("area_id"):
                self._device_area[device["id"]] = device["area_id"]

        entities_resp = await self._send_command(ws, "config/entity_registry/list")
        for entity in entities_resp["result"]:
            area_id = entity.get("area_id") or self._device_area.get(entity.get("device_id"))
            if area_id:
                self._entity_area[entity["entity_id"]] = area_id

        states_resp = await self._send_command(ws, "get_states")
        for state in states_resp["result"]:
            self._apply_state(state)

        self.areasChanged.emit()

    async def _subscribe_state_changed(self, ws):
        await self._send_command(ws, "subscribe_events", event_type="state_changed")

    async def _handle_message(self, msg):
        if msg.get("type") != "event":
            return
        event = msg.get("event", {})
        if event.get("event_type") != "state_changed":
            return
        new_state = event.get("data", {}).get("new_state")
        if new_state is None:
            return
        # Real HA instances push state_changed for every entity in the
        # house continuously (sensors, integration polling, etc.), most of
        # which aren't even shown here. Emitting areasChanged unconditionally
        # rebuilt the whole QML grid on every single one of those, not just
        # ones that actually touch a displayed area -- confirmed as the
        # cause of visible UI slowness against a live 600+ entity instance
        # (2026-08-06). Only emit (debounced) when something actually
        # tracked changed.
        if self._apply_state(new_state):
            self._request_areas_update()

    def _request_areas_update(self):
        self._areas_update_timer.start(150)

    def _apply_state(self, state):
        entity_id = state["entity_id"]
        area_id = self._entity_area.get(entity_id)
        if area_id is None or area_id not in self._areas:
            return False  # entity not assigned to any known area -- not shown on Overview
        domain = entity_id.split(".", 1)[0]
        self._areas[area_id]["entities"][entity_id] = {
            "entity_id": entity_id,
            "domain": domain,
            "name": state.get("attributes", {}).get("friendly_name", entity_id),
            "state": state.get("state", "unknown"),
        }
        return True
