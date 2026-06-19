import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Rectangle {
    radius: 100
    property real margin: 5
    implicitHeight: workspaces.implicitHeight + margin * 2
    implicitWidth: workspaces.implicitWidth + margin * 2

    /* RowLayout { */
    /* 	id: workspaces */
    /* 	spacing: 5 */
    /* 	anchors.centerIn: parent */
    /* 	Text{ */
    /* 	    text:"󱄅" */
    /* 	    font.pointSize: 14 */
    /* 	} */
    /* 	Text { */
    /* 	    text: "thing 2" */
    /* 	} */
    /* } */
    RowLayout {
	id: workspaces
	spacing: 5
	anchors.centerIn: parent
	Repeater {
	    model: Hyprland.workspaces
	    Rectangle {
		id: child
		radius: 100 
		color: modelData.focused ? "green" : "red"
		implicitHeight: workspaceLabel.implicitWidth + margin * 2
		implicitWidth: workspaceLabel.implicitWidth + margin * 2
		MouseArea {
		    anchors.fill: parent
		    cursorShape: Qt.PointingHandCursor

		    onClicked: {
			modelData.activate()
		    }
		}
		Text {
		    anchors.centerIn: parent
		    id: workspaceLabel
		    text: modelData.id
		}
	    }
	}
    }
}