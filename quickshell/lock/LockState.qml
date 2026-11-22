pragma Singleton
import QtQuick
import Quickshell

// LockState: in-process route to lock the session, e.g. from the power menu:
//   LockState.lock()
// LockScreen (instantiated once in shell.qml) owns the actual WlSessionLock and
// listens for `requested`. External callers use `qs ipc call lock lock` or the
// `quickshell:lock` global shortcut instead.
Singleton {
	signal requested()

	function lock() {
		requested();
	}
}
