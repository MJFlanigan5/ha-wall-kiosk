"""
Entry point: wires the HA WebSocket client into a QML engine, running the
asyncio event loop (for the websocket client) and Qt's event loop (for the
UI) on the same thread via qasync -- avoids manual cross-thread signal
marshaling between the async I/O and the QML UI.
"""

import sys
import asyncio

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import qasync

from ha_client import HAClient, load_config
from app_config import AppConfig


def main():
    app = QGuiApplication(sys.argv)

    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    config = load_config()
    ha_client = HAClient(config)
    app_config = AppConfig(config)

    engine = QQmlApplicationEngine()
    engine.addImportPath("qml")
    engine.rootContext().setContextProperty("haClient", ha_client)
    engine.rootContext().setContextProperty("appConfig", app_config)
    engine.load("qml/Overview.qml")

    if not engine.rootObjects():
        print("Failed to load QML -- see errors above.", file=sys.stderr)
        sys.exit(1)

    ha_client.start()

    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()
