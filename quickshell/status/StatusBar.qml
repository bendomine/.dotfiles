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
    property color elementBackgroundColor: "white"
    property color elementFontColor: "black"

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
	    Workspaces {id: workspaces; bgColor: root.elementBackgroundColor; fontColor: root.elementFontColor}
	    Item {
		id: bluetoothAnchor
		implicitWidth: 22.5
		implicitHeight: 22.5
	    }
	    Bluetooth {anchorPoint: bluetoothAnchor; iconSize: workspaces.height; bgColor: root.elementBackgroundColor; fontColor: root.elementFontColor}
	}

	RowLayout {
	    anchors.horizontalCenter: parent.horizontalCenter
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10

	    StatusBox {
		bgColor: root.elementBackgroundColor
		Media { fontColor: root.elementFontColor }
	    }
	}

	RowLayout {
	    anchors.right: parent.right
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10
	    anchors.rightMargin: 10

	    StatusBox { bgColor: root.elementBackgroundColor; Volume { fontColor: root.elementFontColor } }
	    StatusBox { bgColor: root.elementBackgroundColor; Battery { fontColor: root.elementFontColor } }
	    SystemClock {
		precision: SystemClock.Seconds
		id: clock
	    }
	    StatusBox {
		bgColor: root.elementBackgroundColor
		Text {
		    text: Qt.formatDate(clock.date, "ddd d MMM")
		    color: root.elementFontColor
		    verticalAlignment: Text.AlignVCenter
		}
		Text {
		    text: Qt.formatTime(clock.date, "h:mm AP")
		    color: root.elementFontColor
		    verticalAlignment: Text.AlignVCenter
		}
	    }
	    /* Item { id: trayAnchor } */
	    Rectangle {
		id: trayAnchor
		implicitWidth: 22.5
		implicitHeight: 22.5
		color: "transparent"
	    }
	    Tray { anchorPoint: trayAnchor; iconSize: workspaces.height; }
	}

    }

}