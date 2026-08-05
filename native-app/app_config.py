"""
App-level display config, exposed to QML separately from HAClient --
HAClient owns the HA connection, this owns rendering/display decisions
(currently just orientation, room to grow: zoom, theme variant, etc.).
"""

from PySide6.QtCore import QObject, Property


class AppConfig(QObject):
    def __init__(self, config, parent=None):
        super().__init__(parent)
        orientation = (config.get("orientation") or "portrait").lower()
        if orientation not in ("portrait", "landscape"):
            raise ValueError(f"display.orientation must be 'portrait' or 'landscape', got {orientation!r}")
        self._orientation = orientation

    def _get_orientation(self):
        return self._orientation

    orientation = Property(str, _get_orientation, constant=True)

    def _get_is_portrait(self):
        return self._orientation == "portrait"

    isPortrait = Property(bool, _get_is_portrait, constant=True)
