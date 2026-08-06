import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property BluetoothDevice device
    property string name: device ? device.name : ""
    property real margin: 5
    property color fontColor: "black"

    /* required property int selfIndex */
    /* required property int activeIndex */
    property bool active: false
    signal updateIndex()

    implicitWidth: content.implicitWidth + margin * 2
    implicitHeight: content.implicitHeight + margin * 2
    Layout.fillWidth: true

    color: active ? "#45000000" : "transparent"
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

    HoverHandler {
	cursorShape: Qt.PointingHandCursor
	onHoveredChanged: {
	    if (hovered) root.updateIndex()
	}
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
	Text {
	    text: "󰇘"
	    visible: device.trusted
	    color: active ? "black" : "grey"
	    Behavior on color { ColorAnimation { duration: 150 } }
	    Layout.alignment: Qt.AlignRight
	    Layout.leftMargin: 5
	}
    }
}