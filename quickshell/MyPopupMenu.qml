import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    required property Item item
    required property bool show
    required property list<string> names
    required property list<var> functions

    property color backgroundColor: "white"
    property color hoverColor: "#40000000"
    property color textColor: "black"
    property int width: 200

    anchor.item: item
    implicitHeight: names.length * 25 + 15
    implicitWidth: width
    visible: show
    color: "transparent"

    Rectangle {
	anchors.fill: parent
	color: backgroundColor
	radius: 10
	ColumnLayout {
	    id: options
	    anchors.left: parent.left
	    anchors.right: parent.right
	    anchors.top: parent.top
	    anchors.margins: 10
	    Repeater {
		model: names.length
		Rectangle {
		    radius: 5
		    Layout.fillWidth: true
		    implicitHeight: 20
		    color: hover.hovered ? hoverColor : "transparent"

		    Behavior on color { ColorAnimation { duration: 150 } }
		    
		    Text {
			anchors.verticalCenter: parent.verticalCenter
			anchors.left: parent.left
			text: names[index]
			anchors.leftMargin: 5
			width: parent.width - 10
			elide: Text.ElideRight
		    }

		    TapHandler {
			onTapped: functions[index]()
		    }

		    HoverHandler {
			id: hover
			cursorShape: Qt.PointingHandCursor
		    }
		}
	    }
	}
    }
}