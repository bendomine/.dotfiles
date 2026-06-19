import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
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

	    Workspaces {}
	    /* Text { text: "thing 2" } */
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

	    Text { text: "thing 5" }
	    Text { text: "thing 6" }
	}

    }

}