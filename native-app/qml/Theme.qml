pragma Singleton
import QtQuick

// Design tokens ported directly from the HTML mockup's :root CSS custom
// properties (~/Desktop/savant-dashboard-mockup/index.html). Keep these in
// sync if the mockup's palette changes -- this is the single source of
// truth for color/type/spacing in the native app, same role the CSS
// block plays for the web mockup.
QtObject {
    readonly property color base: "#0A0A0C"
    readonly property color baseRaised: "#161618"
    readonly property color hairline: "#232326"
    readonly property color hairlineSoft: "#1C1C1E"
    readonly property color text: "#F5F5F7"
    readonly property color textDim: "#8E8E93"
    readonly property color textFaint: "#545456"
    readonly property color accent: "#FFFFFF"
    readonly property color accentDim: Qt.rgba(1, 1, 1, 0.10)
    readonly property color on: "#34C759"
    readonly property color onDim: Qt.rgba(52 / 255, 199 / 255, 89 / 255, 0.16)

    // QML's default font handling doesn't have a CSS-style stacked
    // fallback list -- font.family takes one name and Qt falls back to
    // the platform default if it's unavailable. San Francisco isn't
    // available on Linux/Pi, so this deliberately targets Inter as the
    // primary (matching the mockup's real fallback for non-Apple
    // platforms), not -apple-system.
    readonly property string fontHead: "Inter"
    readonly property string fontBody: "Inter"
    readonly property string fontMono: "JetBrains Mono"

    readonly property int railWidth: 84

    // Spacing/radius scale -- not literal CSS variables in the mockup
    // (those use ad-hoc px values per component), but consistent values
    // pulled from the mockup's actual card/rail measurements so native
    // screens match without guessing.
    readonly property int radiusCard: 16
    readonly property int radiusChip: 10
    readonly property int spacingUnit: 8
}
