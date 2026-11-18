import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Bluetooth pill + popup (quickshell:toggle-bluetooth).
StatusBox {
	id: root
	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool powered: adapter ? adapter.enabled : false
	readonly property var devices: adapter ? adapter.devices.values : []
	readonly property var connectedDevices: devices.filter(device => device.connected)
	readonly property var knownDevices: devices.filter(device => device.trusted && !device.connected)
	readonly property var otherDevices: devices.filter(device => !device.trusted && !isNameless(device) && !device.connected)

	function isNameless(device) {
		if (!device || !device.name) return true;
		const macAddressRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i;
		return device.name.trim() === "" || macAddressRegex.test(device.name);
	}

	function deviceActions(device) {
		return [
			{
				text: device.connected ? "Disconnect" : "Connect",
				icon: device.connected ? "󰌸" : "󰌷",
				action: () => {
					if (device.connected) {
						device.disconnect();
					} else {
						device.trusted = true;
						device.connect();
					}
				}
			},
			{
				text: device.trusted ? "Untrust" : "Trust",
				icon: device.trusted ? "󰦞" : "󰕥",
				action: () => device.trusted = !device.trusted
			},
			{
				text: "Forget",
				icon: "󰧧",
				danger: true,
				action: () => device.forget()
			}
		];
	}

	active: popup.open
	spacing: Theme.spacingSmall

	Glyph {
		text: !root.powered ? "󰂲" : (root.connectedDevices.length > 0 ? "󰂱" : "󰂯")
		color: root.active ? root.fg : (!root.powered ? root.fgMuted : (root.connectedDevices.length > 0 ? Theme.accent : root.fg))
	}
	StyledText {
		visible: root.connectedDevices.length > 0
		Layout.maximumWidth: 110
		text: root.connectedDevices.length === 1 ? root.connectedDevices[0].name : root.connectedDevices.length
		elide: Text.ElideRight
		color: root.fg
	}

	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-bluetooth"
		contentWidth: 300

		// Scan for devices while the panel is open.
		onOpenChanged: {
			if (root.adapter && root.adapter.enabled)
				root.adapter.discovering = open;
		}

		PopupHeader {
			icon: "󰂯"
			title: "Bluetooth"
			subtitle: !root.adapter ? "No adapter" : (!root.powered ? "Off" : (root.adapter.discovering ? "Scanning for devices…" : root.adapter.name))
		}

		MenuRow {
			icon: root.powered ? "󰂯" : "󰂲"
			text: "Power"
			selected: root.powered
			enabled: root.adapter !== null
			onActivated: root.adapter.enabled = !root.adapter.enabled
			Toggle {
				checked: root.powered
				onToggled: value => {
					if (root.adapter)
						root.adapter.enabled = value;
				}
			}
		}

		Separator {
			visible: root.powered
		}

		ScrollList {
			visible: root.powered
			maxHeight: 340

			SectionLabel {
				text: "Connected"
				visible: connectedRepeater.count > 0
			}
			Repeater {
				id: connectedRepeater
				model: ScriptModel { values: root.connectedDevices }
				delegate: Device {
					id: connectedDevice
					required property var modelData
					device: modelData
					onMenuRequested: deviceMenu.show(connectedDevice, root.deviceActions(device))
				}
			}

			SectionLabel {
				text: "Known Devices"
				visible: knownRepeater.count > 0
			}
			Repeater {
				id: knownRepeater
				model: ScriptModel { values: root.knownDevices }
				delegate: Device {
					id: knownDevice
					required property var modelData
					device: modelData
					onMenuRequested: deviceMenu.show(knownDevice, root.deviceActions(device))
				}
			}

			SectionLabel {
				text: "Other Devices"
				visible: otherRepeater.count > 0
			}
			Repeater {
				id: otherRepeater
				model: ScriptModel { values: root.otherDevices }
				delegate: Device {
					id: otherDevice
					required property var modelData
					device: modelData
					onMenuRequested: deviceMenu.show(otherDevice, root.deviceActions(device))
				}
			}

			StyledText {
				Layout.fillWidth: true
				Layout.margins: Theme.spacing
				visible: connectedRepeater.count + knownRepeater.count + otherRepeater.count === 0
				text: root.adapter && root.adapter.discovering ? "Searching for devices…" : "No devices"
				color: Theme.foregroundMuted
				horizontalAlignment: Text.AlignHCenter
			}
		}

		overlay: ContextMenu {
			id: deviceMenu
		}
	}
}
