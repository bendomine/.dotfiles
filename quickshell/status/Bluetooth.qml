import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: root 
    required property Item anchorPoint
    required property real iconSize
    property real xOffset: -iconSize / 2 + 10
    property real yOffset: -iconSize / 2
    property real dWidth: 200
    property real dHeight: 300
    property real animDuration: 300
    property real animProgress: displayHandler.hovered ? 1.0 : -0.1
    property bool displayWindow: animProgress > -0.1

    onDisplayWindowChanged: Bluetooth.defaultAdapter.discovering = displayWindow

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
	return false
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
	}
	clip: true
	implicitWidth: mix(iconSize, dWidth, animProgress, 0.4)
	implicitHeight: mix(iconSize, dHeight, animProgress - 0.4, 0.6)
	color: displayHandler.hovered ? "white" : "#50000000"
	radius: iconSize / 2

	Behavior on color { ColorAnimation { duration: animDuration * 0.67 } }

	ColumnLayout {
	    anchors.left: parent.left
	    anchors.right: parent.right
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
		    }
		}
		Text { text: "Bluetooth Settings" }
	    }

	    ColumnLayout {
		Layout.alignment: Qt.AlignHCenter
		Layout.maximumWidth: parent.width - 10
		Rectangle {
		    Layout.fillWidth: true
		    color: "lightgrey"
		    implicitHeight: 2
		}
		Text { text: "Known Devices" }
		Repeater {
		    model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
		    delegate: Device {
			device: modelData
			visible: modelData.trusted
		    }
		}
		Text { text: "Other Devices" }
		Repeater {
		    model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
		    delegate: Device {
			device: modelData
			visible: !modelData.trusted && !isNameless(modelData)
		    }
		}
	    }
	}
    }
}