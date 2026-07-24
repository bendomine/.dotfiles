import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property BluetoothDevice device
    property string name: device ? device.name : ""
    property real margin: 5

    implicitWidth: content.implicitWidth + margin * 2
    implicitHeight: content.implicitHeight + margin * 2
    Layout.fillWidth: true

    color: hover.hovered ? "#8F666666" : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }
    radius: 5

    HoverHandler {
	id: hover
	cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
	onTapped: {
	    if (!device) return;

	    if (device.connected) device.disconnect();
	    
	    else {
		device.trusted = true;
		device.connect();
	    }
	}
    }
    
    RowLayout {
	id: content

	anchors.left: parent.left
	anchors.top: parent.top
	anchors.bottom: parent.bottom
	anchors.margins: margin
	Rectangle {
	    implicitWidth: 17
	    implicitHeight: 17
	    radius: 20
	    color: "transparent"
	    Text {
		id: deviceIcon
		anchors.centerIn: parent
		text: {
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
	    }
	}
	Text {
	    text: device.name
	}
    }
}