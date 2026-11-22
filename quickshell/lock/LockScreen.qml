import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../shared"
import "."

// LockScreen: the session lock (ext-session-lock via WlSessionLock), themed like
// the bar. Instantiate once (shell.qml); it creates a LockSurface per screen.
// Ways to lock:
//   quickshell:lock global shortcut (Super+Escape)
//   qs ipc call lock lock            (hypridle, scripts)
//   LockState.lock()                 (in-process, e.g. the power menu)
// The typed password, status line and caps-lock hint are shared by every screen;
// the surface on the focused monitor gets keyboard focus. Only a successful PAM
// conversation (PamContext, /etc/pam.d/quickshell) unlocks; nothing else sets
// `locked = false`. If quickshell dies while locked the compositor keeps the
// session locked (misc.allow_session_lock_restore lets a new instance re-lock).
Scope {
	id: root

	// ── Shared state (read by every LockSurface) ─────────────────────────
	property string password: ""
	property bool busy: false // PAM is checking a response
	property string status: "" // PAM message or failure reason
	property bool statusIsError: false
	property bool capsLock: false
	property int failures: 0 // bumped on every failed attempt (drives the shake)

	readonly property string user: Quickshell.env("USER") ?? ""
	readonly property string wallpaperPath: {
		const cache = Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache");
		return cache + "/wallpaper/current.png";
	}
	readonly property string facePath: Quickshell.env("HOME") + "/.face"
	readonly property date now: clock.date

	// ── API ──────────────────────────────────────────────────────────────
	function lock() {
		if (sessionLock.locked)
			return;
		Popups.closeAll();
		reset();
		probeCaps();
		sessionLock.locked = true;
	}

	// Submit the typed password (Enter). Answers a pending PAM prompt, or starts a
	// new conversation whose first prompt is answered with the password.
	function submit() {
		if (busy || password === "")
			return;
		status = "";
		statusIsError = false;
		busy = true;
		if (pam.responseRequired) {
			pam.respond(password);
			return;
		}
		d.pending = true;
		d.pamError = "";
		if (!pam.active && !pam.start()) {
			d.pending = false;
			fail("Could not start authentication");
		}
	}

	// Escape: clear the field (and any error).
	function clear() {
		password = "";
		if (!busy && !pam.responseRequired) {
			status = "";
			statusIsError = false;
		}
	}

	function probeCaps() {
		capsProbe.running = true;
	}

	function reset() {
		if (pam.active)
			pam.abort();
		d.pending = false;
		d.pamError = "";
		password = "";
		busy = false;
		status = "";
		statusIsError = false;
	}

	function fail(reason) {
		busy = false;
		password = "";
		status = reason;
		statusIsError = true;
		failures++;
	}

	// ── Implementation ───────────────────────────────────────────────────
	QtObject {
		id: d
		property bool pending: false // answer the next PAM prompt with `password`
		property string pamError: ""
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	// Use the dedicated PAM service once it exists (configuration.nix); fall back
	// to "login" so locking never strands the session before a rebuild.
	FileView {
		id: pamService
		path: "/etc/pam.d/quickshell"
		printErrors: false
	}

	PamContext {
		id: pam
		config: pamService.loaded ? "quickshell" : "login"

		onPamMessage: {
			if (responseRequired) {
				if (d.pending) {
					d.pending = false;
					respond(root.password);
				} else {
					// A further prompt (e.g. a second factor): wait for the user.
					root.busy = false;
					root.password = "";
					root.status = message;
					root.statusIsError = false;
				}
			} else if (message !== "") {
				root.status = message;
				root.statusIsError = messageIsError;
			}
		}

		onError: error => d.pamError = PamError.toString(error)

		onCompleted: result => {
			d.pending = false;
			if (result === PamResult.Success) {
				root.reset();
				sessionLock.locked = false;
			} else if (result === PamResult.MaxTries) {
				root.fail("Too many attempts");
			} else if (result === PamResult.Error) {
				root.fail(d.pamError !== "" ? "Authentication error: " + d.pamError : "Authentication error");
			} else {
				root.fail("Wrong password");
			}
		}
	}

	// Initial caps-lock state; key events keep it current afterwards.
	Process {
		id: capsProbe
		command: ["hyprctl", "devices", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const keyboards = JSON.parse(text).keyboards ?? [];
					const main = keyboards.find(k => k.main);
					root.capsLock = main ? main.capsLock === true : keyboards.some(k => k.capsLock === true);
				} catch (e) {
					root.capsLock = false;
				}
			}
		}
	}

	WlSessionLock {
		id: sessionLock

		// `locked` notifies via lockStateChanged.
		onLockStateChanged: {
			if (!locked)
				root.reset();
		}

		LockSurface {
			lock: root
		}
	}

	Connections {
		target: LockState
		function onRequested() {
			root.lock();
		}
	}

	GlobalShortcut {
		name: "lock"
		description: "Lock the screen"
		onPressed: root.lock()
	}

	IpcHandler {
		target: "lock"

		function lock(): void {
			root.lock();
		}
	}
}
