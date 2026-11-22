import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// One screen of the lock (created per screen by LockScreen's WlSessionLock),
// drawn by the shared AuthScene (also used by the login greeter). All state
// lives in `lock` (the LockScreen) so every screen shows the same field;
// whichever surface has keyboard focus edits it.
//   Enter  submit        Escape  clear
WlSessionLockSurface {
	id: surface
	required property var lock

	color: Theme.background

	AuthScene {
		anchors.fill: parent
		auth: surface.lock
		hint: "Enter to unlock · Esc to clear"
	}
}
