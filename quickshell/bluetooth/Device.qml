import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    property var device
    property string deviceName: device ? device.name : ""
    property string iconName: device ? device.icon : ""
    property bool isConnected: device ? device.connected : false
    property bool isTrusted: device ? device.trusted : false

    implicitWidth: main.implicitWidth + 20
    implicitHeight: main.implicitHeight + 12
    radius: 6

    // Aesthetic background states
    color: isConnected ? (hoverHandler.hovered ? "#3d3d3d" : "#2d2d2d") 
                       : (hoverHandler.hovered ? "#1affffff" : "transparent")

    border.color: isConnected ? theme.highlight : "transparent"
    border.width: 1

    RowLayout {
	id: main
	anchors.fill: parent
	anchors.leftMargin: 12
	anchors.rightMargin: 12
	spacing: 12

	Text {
	    font.pixelSize: 18
	    color: isConnected ? theme.highlight : theme.highlight
	    opacity: isConnected ? 1.0 : 0.7
	    text: {
		if (iconName.includes("headset") || iconName.includes("headphones")) return "󰋋"
		if (iconName.includes("audio-card") || iconName.includes("audio-speakers")) return "󰓃"
		if (iconName.includes("input-keyboard")) return "󰌌"
		if (iconName.includes("input-mouse")) return "󰍽"
		if (iconName.includes("input-gaming")) return "󰊴"
		if (iconName.includes("phone")) return "󰏲"
		if (iconName.includes("computer")) return "󰟀"
		if (iconName.includes("video-display")) return "󰍹"
		return "󰂯"
	    }
	}

	Text {
	    Layout.fillWidth: true
	    text: deviceName
	    color: theme.highlight
	    font.bold: isConnected
	    font.pixelSize: 14
	    elide: Text.ElideRight
	    opacity: isConnected ? 1.0 : 0.9
	}

	// Untrust Action
	Text {
	    id: untrustIcon
	    visible: isTrusted && hoverHandler.hovered
	    text: "󱙃"
	    color: theme.highlight
	    font.pixelSize: 16
	    opacity: untrustTap.pressed ? 1.0 : 0.6

	    TapHandler {
		id: untrustTap
		onTapped: if (device) device.trusted = false
	    }

	    HoverHandler {
		cursorShape: Qt.PointingHandCursor
	    }
	}

	// Connection Indicator
	Text {
	    visible: isConnected
	    text: "󰄬"
	    color: theme.highlight
	    font.pixelSize: 12
	    opacity: 0.8
	}
    }

    TapHandler {
	onTapped: {
	    if (!device) return;
	    if (isConnected) {
		device.disconnect();
	    } else {
		if (!isTrusted) device.trusted = true;
		device.connect();
	    }
	}
    }

    HoverHandler {
	id: hoverHandler
	cursorShape: Qt.PointingHandCursor
    }
}