import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: root 
    required property Item anchorPoint
    required property real iconSize
    /* property real xOffset: -iconSize / 2 + 10 */
    /* property real yOffset: -iconSize / 2 */
    property real xOffset: 0
    property real yOffset: 0
    property real dWidth: 200
    property real dHeight: 300
    property real animDuration: 500
    property real animProgress: windowActive ? 1.0 : -0.1
    property bool displayWindow: animProgress > -0.1
    property bool windowActive
    property color bgColor: "white"
    property color fontColor: "black"

    onDisplayWindowChanged: Bluetooth.defaultAdapter.discovering = displayWindow

    Connections {
	target: anchorPoint
	function onXChanged() {
	    if (!root.displayWindow) {
		root.visible = false
		Qt.callLater(() => root.visible = true)
	    }
	}
    }
    anchor.item: anchorPoint
    anchor.rect.x: xOffset
    anchor.rect.y: yOffset
    visible: true
    color: "transparent"

    implicitWidth: displayWindow ? dWidth : iconSize + 2
    implicitHeight: displayWindow ? dHeight : iconSize + 2

    function mix(x, y, a, b) {
	a /= b;
	a = Math.min(Math.max(a, 0.0), 1.0);
	return x * (1 - a) + y * a;
    }

    function isNameless(device) {
	if (!device || !device.name) return true;
	const macAddressRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i;
	return device.name.trim() === "" || macAddressRegex.test(device.name);
    }

    Behavior on animProgress { NumberAnimation {
	duration: animDuration
	easing.type: Easing.OutQuart
    } }

    Rectangle {
	HoverHandler {
	    id: displayHandler
	    onHoveredChanged: {
		if (hovered) windowActive = true;
		else windowActive = false;
	    }
	}
	clip: true
	implicitWidth: mix(iconSize, dWidth, animProgress, 0.4)
	implicitHeight: mix(iconSize, dHeight, animProgress - 0.4, 0.6)
	color: bgColor
	/* color: "#FFFFFFFE" */
	radius: iconSize / 2
	/* border.color: windowActive ? "#AAAAA0" : "transparent" */
	/* border.width: 1 */

	Behavior on color { ColorAnimation { duration: animDuration * 0.67 } }
	/* Behavior on border.color {ColorAnimation {duration: animDuration * 10.67}} */

	ColumnLayout {
	    anchors.fill: parent
	    spacing: 1
	    RowLayout {
		Rectangle {
		    color: "transparent"
		    Layout.preferredWidth: iconSize
		    Layout.preferredHeight: iconSize
		    Text {
			anchors.centerIn: parent
			text: "󰂯"
			font.pointSize: 12
			color: root.fontColor
		    }
		}
		Text { text: "Bluetooth Settings"; color: root.fontColor }
	    }

	    Rectangle {
		Layout.alignment: Qt.AlignHCenter
		Layout.maximumWidth: parent.width - 10
		Layout.fillWidth: true
		color: "lightgrey"
		implicitHeight: 2
	    }

	    ScrollView {
		id: scrollView
		Layout.fillWidth: true
		Layout.fillHeight: true
		Layout.alignment: Qt.AlignHCenter
		Layout.maximumWidth: parent.width - 10
		clip: true
		ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

		ColumnLayout {
		    id: devicesContainer
		    
		    width: scrollView.availableWidth

		    property int focusIdx: -1
		    
		    Text {
			text: "Connected"
			Layout.topMargin: 5
			visible: connectedDevices.count > 0
			color: root.fontColor
		    }
		    Repeater {
			id: connectedDevices
			model: (Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []).values.filter((device) =>
			    {return device.connected})
			delegate: Device {
			    device: modelData
			    active: index == devicesContainer.focusIdx
			    fontColor: root.fontColor
			}
		    }
		    Text {
			text: "Known Devices"
			Layout.topMargin: 5
			color: root.fontColor
		    }
		    Repeater {
			id: knownDevices
			model: (Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []).values.filter((device) =>
			    {return device.trusted && !device.connected})
			delegate: Device {
			    device: modelData
			    active: connectedDevices.count + index == devicesContainer.focusIdx
			    fontColor: root.fontColor
			}
		    }
		    Text { text: "Other Devices"; color: root.fontColor }
		    Repeater {
			id: otherDevices
			model: (Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []).values.filter((device) =>
			    {return !device.trusted && !isNameless(device) && !device.connected})
			delegate: Device {
			    device: modelData
			    active: connectedDevices.count + knownDevices.count + index == devicesContainer.focusIdx
			    fontColor: root.fontColor
			}
		    }
		}
	    }
	}
    }
    GlobalShortcut {
	description: "Toggles the bluetooth menu"
	name: "toggle-bluetooth"
	onPressed: windowActive = !windowActive;
    }
    Shortcut {
	sequence: "j"
	onActivated: {
	    devicesContainer.focusIdx ++;
	    if (devicesContainer.focusIdx >= connectedDevices.count + knownDevices.count + otherDevices.count)
		devicesContainer.focusIdx = 0;
	}
    }
    Shortcut {
	sequence: "k"
	onActivated: {
	    devicesContainer.focusIdx --;
	    if (devicesContainer.focusIdx < 0)
		devicesContainer.focusIdx = connectedDevices.count + knownDevices.count + otherDevices.count - 1
	}
    }
    Shortcut {
	sequences: ["Space", "Return"]
	onActivated: {
	    if (devicesContainer.focusIdx < 0) return;
	    if (devicesContainer.focusIdx < connectedDevices.count)
		connectedDevices.itemAt(devicesContainer.focusIdx).action();
	    else if (devicesContainer.focusIdx < knownDevices.count + connectedDevices.count)
		knownDevices.itemAt(devicesContainer.focusIdx - connectedDevices.count).action();
	    else otherDevices.itemAt(devicesContainer.focusIdx - connectedDevices.count - knownDevices.count).action();
	}
    }
    onWindowActiveChanged: {
	grab.active = windowActive;
	devicesContainer.focusIdx = -1;
    }
    HyprlandFocusGrab {
	id: grab
	windows: [ root ]
	active: false
    }
}