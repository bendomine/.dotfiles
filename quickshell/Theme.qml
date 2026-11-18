pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme: colors generated from the wallpaper plus shared design tokens.
// Colors are read from $XDG_CACHE_HOME/wallpaper/theme.json (written atomically by
// wallpaper/wallpaper.py); property names match the JSON keys. Missing or invalid
// files fall back to the dark defaults below. Every color change animates.
Singleton {
	id: root

	// ── Colors (theme.json keys) ─────────────────────────────────────────
	property color background: defaults.background
	property color surface: defaults.surface
	property color surfaceVariant: defaults.surfaceVariant
	property color foreground: defaults.foreground
	property color foregroundMuted: defaults.foregroundMuted
	property color accent: defaults.accent
	// `onAccent: …` / `Behavior on onAccent` would parse as signal handlers (for
	// `accent`), so onAccent is bound via Binding to an animated internal property.
	property color onAccent
	property color onAccentAnimated: defaults.onAccent
	Binding {
		target: root
		property: "onAccent"
		value: root.onAccentAnimated
	}
	property color accentAlt: defaults.accentAlt
	property color border: defaults.border
	property color urgent: defaults.urgent
	property color success: defaults.success
	property var palette: defaults.palette
	property string mode: defaults.mode
	readonly property bool dark: mode !== "light"
	// True once theme.json has been parsed successfully.
	property bool loaded: false

	Behavior on background { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on surface { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on surfaceVariant { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on foreground { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on foregroundMuted { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on accent { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on onAccentAnimated { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on accentAlt { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on border { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on urgent { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }
	Behavior on success { ColorAnimation { duration: root.colorTransition; easing.type: Easing.InOutQuad } }

	// ── Typography ───────────────────────────────────────────────────────
	readonly property string fontFamily: "JetBrainsMono Nerd Font Propo"
	readonly property string iconFontFamily: "JetBrainsMono Nerd Font Propo"
	readonly property int fontSize: 13 // pixel sizes
	readonly property int fontSizeSmall: 11
	readonly property int fontSizeLarge: 15
	readonly property int iconSize: 16
	readonly property int iconSizeLarge: 20

	// ── Geometry ─────────────────────────────────────────────────────────
	readonly property int barHeight: 38 // height of the floating bar
	readonly property int barMargin: 8 // gap between the bar and the screen edges
	readonly property int barPadding: 5 // gap between the bar edge and its pills
	readonly property int pillHeight: barHeight - barPadding * 2
	readonly property int pillPadding: 10 // horizontal padding inside a pill
	readonly property int popupGap: 6 // gap between the bar and a popup
	readonly property int popupWidth: 300
	readonly property int radius: 16 // bar and popup panels
	readonly property int radiusSmall: 10 // rows, buttons
	readonly property int radiusPill: pillHeight / 2
	readonly property int spacing: 8
	readonly property int spacingSmall: 4
	readonly property int spacingLarge: 12
	readonly property int padding: 10 // inner padding of popup panels
	readonly property int rowHeight: 38
	readonly property int rowHeightCompact: 30

	// ── Opacity ──────────────────────────────────────────────────────────
	readonly property real barOpacity: 0.80
	readonly property real barOpacityMelded: 0.95 // bar flush with a single gapless window
	readonly property real panelOpacity: 0.95

	// ── Animation durations (ms) ─────────────────────────────────────────
	readonly property int animFast: 120
	readonly property int animNormal: 220
	readonly property int animSlow: 380
	readonly property int colorTransition: 700

	// ── Helpers ──────────────────────────────────────────────────────────
	// Same color with alpha `a` (0..1). Accepts colors or color strings.
	function alpha(c, a) {
		const k = Qt.tint(c, "transparent");
		return Qt.rgba(k.r, k.g, k.b, a);
	}
	// Linear blend between two colors, t in 0..1.
	function mix(a, b, t) {
		const x = Qt.tint(a, "transparent");
		const y = Qt.tint(b, "transparent");
		return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
	}

	readonly property string themePath: {
		const cache = Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache");
		return cache + "/wallpaper/theme.json";
	}

	readonly property var defaults: ({
		mode: "dark",
		background: "#13151c",
		surface: "#1d2029",
		surfaceVariant: "#2a2e3b",
		foreground: "#e6e8f0",
		foregroundMuted: "#9aa1b5",
		accent: "#89a8ff",
		onAccent: "#0f1424",
		accentAlt: "#c59cff",
		border: "#353a4a",
		urgent: "#ff6e6e",
		success: "#7fd890",
		palette: ["#1d2029", "#2a2e3b", "#89a8ff", "#c59cff"]
	})
	readonly property var colorKeys: ["background", "surface", "surfaceVariant", "foreground", "foregroundMuted", "accent", "onAccent", "accentAlt", "border", "urgent", "success"]

	function isColor(v) {
		return typeof v === "string" && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v);
	}

	function apply(data) {
		const d = data ?? {};
		for (const key of colorKeys)
			root[key === "onAccent" ? "onAccentAnimated" : key] = isColor(d[key]) ? d[key] : defaults[key];
		root.palette = Array.isArray(d.palette) && d.palette.length > 0 && d.palette.every(isColor) ? d.palette : defaults.palette;
		root.mode = d.mode === "light" ? "light" : "dark";
	}

	function load(text) {
		try {
			apply(JSON.parse(text));
			loaded = true;
		} catch (e) {
			console.warn("Theme: invalid", themePath, "-", e);
			apply(null);
			loaded = false;
		}
	}

	FileView {
		id: file
		path: root.themePath
		watchChanges: true
		printErrors: false
		// fileChanged also fires when the file is replaced via rename.
		onFileChanged: reload()
		onLoaded: root.load(text())
		onLoadFailed: {
			root.apply(null);
			root.loaded = false;
		}
	}

	// The watch can only be established once the cache directory exists; until the
	// file has been read once, retry periodically.
	Timer {
		interval: 3000
		repeat: true
		running: !file.loaded
		onTriggered: file.reload()
	}
}
