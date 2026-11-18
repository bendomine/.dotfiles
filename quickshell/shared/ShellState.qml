pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "."

// ShellState: shell-wide UI state shared by every screen's bar.
Singleton {
	id: root

	// Bar visibility, toggled by the `quickshell:toggle-bar` global shortcut.
	property bool barVisible: true

	onBarVisibleChanged: {
		if (!barVisible)
			Popups.closeAll();
	}

	GlobalShortcut {
		name: "toggle-bar"
		description: "Show or hide the status bar"
		onPressed: root.barVisible = !root.barVisible
	}
}
