import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
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
    property real animDuration: 500
    property real animProgress: displayHandler.hovered ? 1.0 : -0.1
    property bool displayWindow: animProgress > -0.1

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
	}
	clip: true
	implicitWidth: mix(iconSize, dWidth, animProgress, 0.4)
	implicitHeight: mix(iconSize, dHeight, animProgress - 0.4, 0.6)
	color: displayHandler.hovered ? "white" : "#50000000"
	/* color: "#FFFFFFFE" */
	radius: iconSize / 2
	border.color: displayHandler.hovered ? "#AAAAA0" : "transparent"
	border.width: 1

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
		    }
		}
		Text { text: "Bluetooth Settings" }
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
		    property int connectedDevices: 0

		    width: scrollView.availableWidth
		    Text {
			text: "Connected"
			Layout.topMargin: 5
			/* visible: parent.connectedDevices > 0 */
		    }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    device: modelData
			    visible: modelData.connected

			    onVisibleChanged: {
				if (visible) parent.connectedDevices ++;
				else parent.connectedDevices --;
			    }

			    Component.onCompleted: {
				if (visible) parent.connectedDevices ++;
			    }

			    Component.onDestruction: {
				if (visible) parent.connectedDevices --;
			    }
			}
		    }
		    Text {
			text: "Known Devices"
			Layout.topMargin: 5
		    }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    device: modelData
			    visible: modelData.trusted && !modelData.connected
			}
		    }
		    Text { text: "Other Devices" }
		    Repeater {
			model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : []
			delegate: Device {
			    device: modelData
			    visible: !modelData.trusted && !isNameless(modelData)
			                                && !modelData.connected
			}
		    }
		}
	    }
	}
    }
}