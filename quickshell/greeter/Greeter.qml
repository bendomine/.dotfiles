import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "../shared"
import "../lock"
import "../status"
import ".."

// Greeter: the greetd login screen, run by configuration.nix under cage as the
// `greeter` user (see greeter.qml). Same look as the lock screen: this Scope is
// the AuthScene `auth` object (see lock/AuthScene.qml) and the window shows the
// scene plus a session line and reboot / shut-down pills.
// Flow: Enter → Greetd.createSession(user) → the first secret prompt is answered
// with the typed password → readyToLaunch → fade out → Greetd.launch(), after
// which Quickshell quits, cage exits and greetd starts the session on this VT.
// Theme colors and the wallpaper come from /var/lib/greeter-theme (written by
// wallpaper.py), linked at the greeter's ~/.cache/wallpaper so Theme.qml reads
// theme.json from the same relative path as in the desktop shell.
Scope {
	id: root

	// ── AuthScene interface ──────────────────────────────────────────────
	property string password: ""
	property bool busy: false // greetd is checking a response
	property string status: "" // PAM message or failure reason
	property bool statusIsError: false
	property bool capsLock: false
	property int failures: 0 // bumped on every failed attempt (drives the shake)

	readonly property string user: "ben"
	// ~/.face is unreadable for the greeter (home is mode 700): account glyph.
	readonly property string facePath: ""
	readonly property string wallpaperPath: {
		const cache = Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache");
		return cache + "/wallpaper/current.jpg";
	}
	readonly property date now: clock.date

	// ── Session ──────────────────────────────────────────────────────────
	readonly property string sessionName: "Hyprland"
	// greetd joins the argv with spaces into `sh -c "exec …"` (after sourcing
	// /etc/profile), so this is shell code. Going through the user's login shell
	// applies its profile (home-manager session variables live in ~/.zshenv),
	// like typing start-hyprland after a tty login.
	readonly property var sessionCommand: ['"$SHELL"', "-l", "-c", "start-hyprland"]
	// Passed to PAM before the session opens, so logind registers a Wayland session.
	readonly property var sessionEnv: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"]
	// Authenticated: the scene fades out, then launch() starts the session.
	property bool launching: false

	readonly property var powerActions: [
		{ id: "reboot", icon: "󰜉", text: "Reboot", command: ["systemctl", "reboot"] },
		{ id: "poweroff", icon: "󰐥", text: "Shut down", command: ["systemctl", "poweroff"] }
	]

	// ── API (AuthScene) ──────────────────────────────────────────────────
	// Submit the typed password (Enter). Answers a pending prompt, or starts a
	// new conversation whose first prompt is answered with the password.
	function submit() {
		if (busy || launching || password === "")
			return;
		if (!Greetd.available) {
			fail("greetd is not running");
			return;
		}
		status = "";
		statusIsError = false;
		busy = true;
		if (d.responseRequired) {
			d.responseRequired = false;
			Greetd.respond(password);
			return;
		}
		// Always start from a fresh conversation.
		if (Greetd.state !== GreetdState.Inactive)
			Greetd.cancelSession();
		d.pending = true;
		Greetd.createSession(user);
	}

	// Escape: clear the field (and any error).
	function clear() {
		password = "";
		if (!busy && !d.responseRequired) {
			status = "";
			statusIsError = false;
		}
	}

	// Caps-lock state from the keyboard LEDs (world-readable; no compositor IPC
	// under cage). Typed letters keep it current in between (AuthScene).
	function probeCaps() {
		capsProbe.running = true;
	}

	function fail(reason) {
		d.pending = false;
		d.responseRequired = false;
		Greetd.cancelSession(); // no-op when greetd already ended the conversation
		launching = false;
		busy = false;
		password = "";
		status = reason;
		statusIsError = true;
		failures++;
	}

	function launch() {
		Greetd.launch(sessionCommand, sessionEnv);
	}

	// Reboot / shut down need a second click within 3 s.
	function power(action) {
		if (d.confirming !== action.id) {
			d.confirming = action.id;
			confirmTimer.restart();
			return;
		}
		d.confirming = "";
		confirmTimer.stop();
		runner.command = action.command;
		runner.startDetached();
	}

	// ── Implementation ───────────────────────────────────────────────────
	QtObject {
		id: d
		property bool pending: false // answer the next prompt with `password`
		property bool responseRequired: false // a later prompt waits for the user
		property string confirming: "" // id of the power action awaiting confirmation
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	Connections {
		target: Greetd

		function onAuthMessage(message, error, responseRequired, echoResponse) {
			if (responseRequired) {
				if (d.pending) {
					d.pending = false;
					Greetd.respond(root.password);
				} else {
					// A further prompt (e.g. a second factor): wait for the user.
					d.responseRequired = true;
					root.busy = false;
					root.password = "";
					root.status = message;
					root.statusIsError = false;
				}
			} else if (message !== "") {
				root.status = message;
				root.statusIsError = error;
			}
		}

		function onAuthFailure(message) {
			console.info("Greeter: authentication failed:", message);
			root.fail("Wrong password");
		}

		function onError(error) {
			root.fail("Login error: " + error);
		}

		function onReadyToLaunch() {
			d.pending = false;
			root.busy = false;
			root.password = "";
			root.status = "Starting " + root.sessionName + "…";
			root.statusIsError = false;
			root.launching = true;
		}
	}

	Process {
		id: capsProbe
		command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
		stdout: StdioCollector {
			onStreamFinished: root.capsLock = text.split("\n").some(l => l.trim() !== "" && l.trim() !== "0")
		}
	}

	Process {
		id: runner
	}

	Timer {
		id: confirmTimer
		interval: 3000
		onTriggered: d.confirming = ""
	}

	Component.onCompleted: probeCaps()

	// cage shows its single toplevel fullscreen on one output (no layer-shell);
	// the implicit size only matters when previewing in a normal session.
	FloatingWindow {
		title: "Login"
		color: Theme.background
		implicitWidth: 1280
		implicitHeight: 800

		Item {
			id: content
			anchors.fill: parent

			Connections {
				target: root
				function onLaunchingChanged() {
					if (root.launching) {
						fadeOut.start();
					} else {
						fadeOut.stop();
						content.opacity = 1;
					}
				}
			}

			NumberAnimation {
				id: fadeOut
				target: content
				property: "opacity"
				to: 0
				duration: Theme.animSlow
				easing.type: Easing.InCubic
				onFinished: {
					if (root.launching)
						root.launch();
				}
			}

			AuthScene {
				id: scene
				anchors.fill: parent
				auth: root
				hint: "Enter to log in · Esc to clear"

				// ── Session line ─────────────────────────────────────────
				RowLayout {
					anchors.horizontalCenter: parent.horizontalCenter
					anchors.top: scene.card.bottom
					anchors.topMargin: Theme.spacingLarge
					spacing: Theme.spacingSmall + 2

					Glyph {
						text: ""
						color: Theme.foregroundMuted
					}
					StyledText {
						text: root.sessionName
						color: Theme.foregroundMuted
					}
				}

				// ── Power pills, styled like the bar ─────────────────────
				Rectangle {
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					anchors.margins: Theme.spacingLarge * 2
					implicitWidth: powerRow.implicitWidth + Theme.barPadding * 2
					implicitHeight: Theme.barHeight
					radius: Theme.radius
					color: Theme.alpha(Theme.background, Theme.barOpacity)
					border.width: 1
					border.color: Theme.alpha(Theme.border, 0.6)

					RowLayout {
						id: powerRow
						anchors.centerIn: parent
						spacing: Theme.barPadding

						Repeater {
							model: root.powerActions

							StatusBox {
								id: pill
								required property var modelData
								readonly property bool confirming: d.confirming === modelData.id
								active: confirming
								padding: confirming ? Theme.pillPadding : 8
								onClicked: root.power(modelData)

								Glyph {
									text: pill.modelData.icon
									font.pixelSize: Theme.iconSize + 1
									color: !pill.active && pill.hovered ? (pill.modelData.id === "poweroff" ? Theme.urgent : Theme.accent) : pill.fg
								}
								StyledText {
									visible: pill.confirming
									text: pill.modelData.text + "?"
									color: pill.fg
								}
							}
						}
					}
				}
			}
		}
	}
}
