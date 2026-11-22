import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Bluetooth device row. Activate (click / Space / Return) connects or disconnects;
// the options button, right click, Shift+Return, `o` or `m` request the context menu.
MenuRow {
	id: root
	property BluetoothDevice device
	signal menuRequested()

	function action() {
		if (!device) return;

		if (device.connected) device.disconnect();
		
		else {
			device.trusted = true;
			device.connect();
		}
	}

	onActivated: action()
	onAltActivated: menuRequested()

	selected: device ? device.connected : false
	text: device ? device.name : ""
	subtext: {
		if (!device)
			return "";
		switch (device.state) {
		case BluetoothDeviceState.Connecting:
			return "Connecting…";
		case BluetoothDeviceState.Disconnecting:
			return "Disconnecting…";
		case BluetoothDeviceState.Connected:
			return device.batteryAvailable ? `Connected · ${Math.round(device.battery * 100)}%` : "Connected";
		}
		if (device.pairing)
			return "Pairing…";
		return device.paired ? "Paired" : "";
	}
	icon: {
		let name = device ? device.icon : ""
		if (name.includes("headset") || name.includes("headphones")) return "󰋋"
		if (name.includes("audio-card") || name.includes("audio-speakers")) return "󰓃"
		if (name.includes("input-keyboard")) return "󰌌"
		if (name.includes("input-mouse")) return "󰍽"
		if (name.includes("input-gaming")) return "󰊴"
		if (name.includes("phone")) return "󰏲"
		if (name.includes("computer")) return "󰟀"
		if (name.includes("video-display")) return "󰍹"
		return "󰂯"
	}

	// Options button
	Rectangle {
		id: options
		implicitWidth: 26
		implicitHeight: 26
		radius: 13
		color: Theme.alpha(Theme.foreground, optionsMouse.containsMouse ? 0.12 : 0)
		Behavior on color { ColorAnimation { duration: Theme.animFast } }

		Glyph {
			anchors.centerIn: parent
			text: "󰇘"
			color: root.highlighted ? Theme.foreground : Theme.foregroundMuted
		}

		MouseArea {
			id: optionsMouse
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.menuRequested()
		}
	}
}
