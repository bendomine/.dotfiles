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
	    Workspaces {}
	}

	RowLayout {
	    anchors.horizontalCenter: parent.horizontalCenter
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10

	    Text { text: "thing 3" }
	    Text { text: "thing 4" }
	}

	RowLayout {
	    anchors.right: parent.right
	    anchors.verticalCenter: parent.verticalCenter
	    spacing: 10
	    anchors.rightMargin: 10

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
	    RoundButton {
		text: "󰂯"
		font.pointSize: 13
		implicitHeight: Math.max(implicitWidth, implicitHeight)
		/* contentItem: Text { */
		/*     text: "󰂯" */
		/*     horizontalAlignment: Text.AlignHCenter */
		/*     verticalAlignment: Text.AlignVCenter */
		/*     font.pointSize: 15 */
		/* } */
		/* background: Rectangle { */
		    
		/* } */
	    }
	    Tray {barWindow: root}
	}

    }

}