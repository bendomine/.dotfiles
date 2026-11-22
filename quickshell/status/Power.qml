import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../shared"
import "../lock"
import ".."

// Power pill + menu (quickshell:toggle-power). Log out, reboot and shut down need
// a second activation within 3 s. Each row also has a single-key shortcut (shown
// on the right); pressing it focuses and activates the row. Lock goes straight to
// the shell's own LockScreen; the other actions run `command` detached.
StatusBox {
	id: root

	readonly property var actions: [
		{ id: "lock", icon: "󰌾", text: "Lock", key: "x" },
		{ id: "logout", icon: "󰍃", text: "Log out", key: "e", confirm: true, command: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] },
		{ id: "suspend", icon: "󰤄", text: "Suspend", key: "s", command: ["systemctl", "suspend"] },
		{ id: "reboot", icon: "󰜉", text: "Reboot", key: "r", confirm: true, command: ["systemctl", "reboot"] },
		{ id: "poweroff", icon: "󰐥", text: "Shut down", key: "d", confirm: true, command: ["systemctl", "poweroff"] },
		{ id: "reload", icon: "󰑓", text: "Reload Hyprland", key: "c", command: ["hyprctl", "reload"] }
	]

	function trigger(action) {
		if (action.confirm && d.confirming !== action.id) {
			d.confirming = action.id;
			confirmTimer.restart();
			return;
		}
		d.confirming = "";
		confirmTimer.stop();
		popup.close();
		if (action.id === "lock") {
			LockState.lock();
			return;
		}
		runner.command = action.command;
		runner.startDetached();
	}

	QtObject {
		id: d
		property string confirming: "" // id of the action waiting for confirmation
	}

	Timer {
		id: confirmTimer
		interval: 3000
		onTriggered: d.confirming = ""
	}

	Process {
		id: runner
	}

	active: popup.open
	padding: 8

	Glyph {
		text: "󰐥"
		font.pixelSize: Theme.iconSize + 1
		color: !root.active && root.hovered ? Theme.urgent : root.fg
	}

	// Keyboard shortcut hint.
	component KeyHint: Rectangle {
		id: hint
		property string label: ""
		property color tint: Theme.foregroundMuted
		implicitWidth: Math.max(implicitHeight, hintText.implicitWidth + 10)
		implicitHeight: 20
		radius: 6
		color: "transparent"
		border.width: 1
		border.color: Theme.alpha(hint.tint, 0.6)
		StyledText {
			id: hintText
			anchors.centerIn: parent
			text: hint.label
			font.pixelSize: Theme.fontSizeSmall
			color: hint.tint
		}
	}

	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-power"
		contentWidth: 240

		onOpenChanged: {
			if (!open) {
				d.confirming = "";
				confirmTimer.stop();
			}
		}

		onKeyPressed: event => {
			const k = event.text.toLowerCase();
			const i = root.actions.findIndex(a => a.key === k);
			if (i < 0)
				return;
			event.accepted = true;
			const row = rows.itemAt(i);
			if (row)
				popup.setFocusItem(row);
			root.trigger(root.actions[i]);
		}

		PopupHeader {
			icon: "󰐥"
			title: "Power"
			subtitle: d.confirming !== "" ? "Press again to confirm" : (Quickshell.env("USER") ?? "")
		}

		Repeater {
			id: rows
			model: root.actions
			delegate: MenuRow {
				id: row
				required property var modelData
				readonly property bool confirming: d.confirming === modelData.id
				icon: modelData.icon
				text: confirming ? "Press again to confirm" : modelData.text
				textColor: confirming ? Theme.urgent : Theme.foreground
				iconColor: confirming || (modelData.confirm && highlighted) ? Theme.urgent : (highlighted ? Theme.foreground : Theme.foregroundMuted)
				color: confirming ? Theme.alpha(Theme.urgent, 0.14) : (highlighted ? Theme.surfaceVariant : "transparent")
				onActivated: root.trigger(modelData)

				KeyHint {
					label: row.modelData.key
					tint: row.confirming ? Theme.urgent : Theme.foregroundMuted
				}
			}
		}
	}
}
