import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Rectangle {
    id: root
    radius: 100
    property real margin: 5
    implicitHeight: workspaces.implicitHeight + margin * 2
    implicitWidth: workspaces.implicitWidth + margin * 2
    color: "#50000000"

    RowLayout {
	id: workspaces
	spacing: 5
	anchors.centerIn: parent
	Repeater {
	    model: Hyprland.workspaces
	    Rectangle {
		id: child
		implicitHeight: workspaceLabel.implicitWidth + margin
		implicitWidth: workspaceLabel.implicitWidth + margin
		color: "transparent"
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
		    color: modelData.active ? "red" : "black"
		}
	    }
	}
    }
}