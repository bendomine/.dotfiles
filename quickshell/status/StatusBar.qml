import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import QtQuick.Controls
import "./.."
import "../shared"

PanelWindow {
    id: root
    anchors {
	left: true
	top: true
	right: true
    }
    implicitHeight: 40
    color: "#5AFFFFFF"

    Item {
	width: parent.width
	height: parent.height

	RowLayout {
	    anchors.left: parent.left
	    anchors.verticalCenter: parent.verticalCenter
	    Layout.margins: 500
	    spacing: 10
	    anchors.leftMargin: 10

	    Text {
		text: "󱄅"
		font.pointSize: 15
		color: "white"
	    }
	    Workspaces {id: workspaces}
	    Item {id: bluetoothAnchor}
	    Bluetooth {anchorPoint: bluetoothAnchor; iconSize: workspaces.height}
	}

	RowLayout {
	    anchors.horizontalCenter: parent.horizontalCenter
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10

	    Media {}
	}

	RowLayout {
	    anchors.right: parent.right
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10
	    anchors.rightMargin: 10

	    Volume {}
	    Battery {}
	    SystemClock {
		precision: SystemClock.Seconds
		id: clock
	    }
	    Text {
		text: Qt.formatDate(clock.date, "ddd d MMM")
	    }
	    Text {
		text: Qt.formatTime(clock.date, "h:mm AP")
	    }
	    Tray {barWindow: root}
	}

    }

}