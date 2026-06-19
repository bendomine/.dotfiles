import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./.."
import "../shared"

FloatingWindow {
    id: root
    width: 350
    height: 500

    ColumnLayout {
	anchors.fill: parent
	anchors.margins: 20
	spacing: 15

	RowLayout {
	    Layout.fillWidth: true
	    Text {
		text: "Bluetooth"
		color: theme.highlight
		font.pixelSize: 22
		font.bold: true
		Layout.fillWidth: true
	    }
	    Toggle {
		id: powerToggle
		checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

		onToggled: {
		    if (Bluetooth.defaultAdapter) {
			Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
		    }
		}
	    }
	}

	Toggle {
	    id: discoveryToggle
	    checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
	    onToggled: {
		if (Bluetooth.defaultAdapter) {
		    Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
		}
	    }
	    text: "Toggle discovery"
	    visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
	}

	ScrollView {
	    Layout.fillWidth: true
	    Layout.fillHeight: true
	    visible: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
	    clip: true

	    ColumnLayout {
		width: parent.width
		spacing: 20

		// Connected Section
		ColumnLayout {
		    Layout.fillWidth: true
		    spacing: 8
		    visible: root.hasDevices("connected")
		    Text {
			text: "Connected"
			color: theme.highlight
			font.pixelSize: 14
			font.bold: true
			opacity: 0.7
		    }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    visible: modelData.connected && !root.isNameless(modelData)
			    device: visible ? modelData : null
			    Layout.fillWidth: true
			    Layout.preferredHeight: visible ? implicitHeight : 0
			}
		    }
		}

		// Trusted Section
		ColumnLayout {
		    Layout.fillWidth: true
		    spacing: 8
		    visible: root.hasDevices("trusted")
		    Text {
			text: "Trusted"
			color: theme.highlight
			font.pixelSize: 14
			font.bold: true
			opacity: 0.7
		    }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    visible: modelData.trusted && !modelData.connected && !root.isNameless(modelData)
			    device: visible ? modelData : null
			    Layout.fillWidth: true
			    Layout.preferredHeight: visible ? implicitHeight : 0
			}
		    }
		}

		// Found Section
		ColumnLayout {
		    Layout.fillWidth: true
		    spacing: 8
		    visible: root.hasDevices("found")
		    Text {
			text: "Found"
			color: theme.highlight
			font.pixelSize: 14
			font.bold: true
			opacity: 0.7
		    }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    visible: !modelData.trusted && !modelData.connected && !root.isNameless(modelData)
			    device: visible ? modelData : null
			    Layout.fillWidth: true
			    Layout.preferredHeight: visible ? implicitHeight : 0
			}
		    }
		}
	    }
	}

	Text {
	    text: "Bluetooth is disabled"
	    color: theme.highlight
	    opacity: 0.5
	    font.pixelSize: 16
	    visible: !Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled
	    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
	    Layout.fillHeight: true
	}
    }

    function isNameless(device) {
	if (!device || !device.name) return true;
	const macAddressRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i;
	return device.name.trim() === "" || macAddressRegex.test(device.name);
    }

    function hasDevices(type) {
	const adapter = Bluetooth.defaultAdapter;
	if (!adapter || !adapter.devices) return false;
	
	for (let i = 0; i < adapter.devices.length; i++) {
	    const d = adapter.devices[i];
	    if (isNameless(d)) continue;
	    
	    if (type === "connected" && d.connected) return true;
	    if (type === "trusted" && d.trusted && !d.connected) return true;
	    if (type === "found" && !d.trusted && !d.connected) return true;
	}
	return false;
    }
}
