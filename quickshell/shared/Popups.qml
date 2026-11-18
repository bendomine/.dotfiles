pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Popups: global popup coordination.
// - Every BarPopup registers itself here; at most one popup is open at a time
//   (`current`); opening one closes the other.
// - Owns the popup GlobalShortcuts (names must be unique per process, so they can
//   not live in per-screen bars). Pressing `quickshell:<name>` toggles the BarPopup
//   whose `shortcutName` is <name> on the focused monitor.
Singleton {
	id: root

	property var current: null
	readonly property bool anyOpen: current !== null
	property var registry: []

	readonly property var shortcuts: [
		{ name: "toggle-bluetooth", description: "Toggle the bluetooth popup" },
		{ name: "toggle-tray", description: "Toggle the system tray popup" },
		{ name: "toggle-audio", description: "Toggle the audio popup" },
		{ name: "toggle-network", description: "Toggle the network popup" },
		{ name: "toggle-media", description: "Toggle the media popup" },
		{ name: "toggle-calendar", description: "Toggle the calendar popup" },
		{ name: "toggle-system", description: "Toggle the system popup" },
		{ name: "toggle-power", description: "Toggle the power menu" },
		{ name: "toggle-launcher", description: "Toggle the launcher / keybinding help menu" }
	]

	function register(popup) {
		if (!registry.includes(popup))
			registry = registry.concat([popup]);
	}

	function unregister(popup) {
		registry = registry.filter(p => p !== popup);
		if (current === popup)
			current = null;
	}

	// Called by BarPopup when it opens / closes.
	function opening(popup) {
		if (current && current !== popup)
			current.close();
		current = popup;
	}

	function closing(popup) {
		if (current === popup)
			current = null;
	}

	function closeAll() {
		if (current)
			current.close();
	}

	// The popup registered for `name` on the focused monitor (or any screen).
	function find(name) {
		const candidates = registry.filter(p => p.shortcutName === name);
		if (candidates.length === 0)
			return null;
		const monitor = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
		return candidates.find(p => p.screenName === monitor) ?? candidates[0];
	}

	function toggle(name) {
		const popup = find(name);
		if (popup)
			popup.toggle();
	}

	// The BarPopup that contains `item`, or null.
	function owner(item) {
		for (let p = item; p; p = p.parent) {
			if (p.barPopup !== undefined)
				return p.barPopup;
		}
		return null;
	}

	Variants {
		model: root.shortcuts
		GlobalShortcut {
			required property var modelData
			name: modelData.name
			description: modelData.description
			onPressed: root.toggle(modelData.name)
		}
	}
}
