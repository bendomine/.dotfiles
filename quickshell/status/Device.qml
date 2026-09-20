import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Rectangle {
    id: root
    property BluetoothDevice device
    property string name: device ? device.name : ""
    property real margin: 5
    property color fontColor: "black"

    property bool active: false
    property bool hovered: hover.hovered && !optionsHover.hovered
    signal updateIndex()
    signal resetIndex()
    signal popupMenu()

    implicitWidth: content.implicitWidth + margin * 2
    implicitHeight: content.implicitHeight + margin * 2
    Layout.fillWidth: true

    color: active ? "#40000000" : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }
    radius: 5

    function action() {
	if (!device) return;

	if (device.connected) device.disconnect();
	
	else {
	    device.trusted = true;
	    device.connect();
	}
    }
    onHoveredChanged: {
	if (hovered && !optionsHover.hovered) root.updateIndex()
	else root.resetIndex()
    }

    HoverHandler {
	id: hover
	cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
	onTapped: action()
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
		color: fontColor
	    }
	}
	Text {
	    text: device.name
	    color: fontColor
	}
	Rectangle {
	    id: options
	    implicitWidth: 15
	    implicitHeight: 15
	    radius: 15
	    color: optionsHover.hovered ? "#40000000" : "transparent"
	    Behavior on color { ColorAnimation { duration: 150 } }

	    HoverHandler {
		id: optionsHover
		cursorShape: Qt.PointingHandCursor
	    }

	    TapHandler {
		onTapped: popupMenu()
	    }

	    Text {
		anchors.centerIn: parent
		text: " 󰇘 "
		visible: device.trusted
		color: active ? "black" : "grey"
		Behavior on color { ColorAnimation { duration: 150 } }
		Layout.alignment: Qt.AlignRight
		Layout.leftMargin: 5
	    }
	}
    }
}