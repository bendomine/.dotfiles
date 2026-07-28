import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Rectangle {
    id: root
    radius: 100
    property real margin: 5
    property color bgColor: "white"
    property color fontColor: "black"
    implicitHeight: workspaces.implicitHeight + margin * 2
    implicitWidth: workspaces.implicitWidth + margin * 2
    color: bgColor

    RowLayout {
	id: workspaces
	spacing: 5
	anchors.centerIn: parent
	Repeater {
	    model: Hyprland.workspaces
	    Rectangle {
		id: child
		implicitHeight: 12.5
		implicitWidth: 12.5
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
		    color: modelData.active ? "red" : root.fontColor
		}
	    }
	}
    }
}