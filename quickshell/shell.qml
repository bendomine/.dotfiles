//@ pragma UseQApplication
//@ pragma IconTheme Papirus
import Quickshell
import QtQuick
import "."
import "./shared"
import "./status"

ShellRoot {
	id: root

	// One bar per screen. Global shortcuts live in the Popups / ShellState
	// singletons so they are registered once, not per screen.
	Variants {
		model: Quickshell.screens
		StatusBar {}
	}

	BatteryNotifier {}
	Osd {}
}
