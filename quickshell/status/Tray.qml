import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    required property var barWindow
    property real margin: 5
    property real animationLength: 200
    property bool showTray: trayHover.hovered || menuAnchor.visible

    id: root
    radius: 100
    implicitHeight: tray.implicitHeight + margin
    implicitWidth: (showTray ? tray.implicitWidth : 20) + margin * 2
    Behavior on implicitWidth { PropertyAnimation { duration: animationLength } }
    color: "#50000000"

    HoverHandler {
	id: trayHover
	cursorShape: Qt.PointingHandCursor
    }

    RowLayout {
	id: tray
	/* spacing: 5 */
	spacing: 0
	anchors.centerIn: parent
	QsMenuAnchor {
	    id: menuAnchor
	    anchor.window: barWindow
	    anchor.rect.x: child.x
	    anchor.rect.y: child.y
	    anchor.rect.width: child.width
	    anchor.rect.height: child.height
	}
	Repeater {
	    model: SystemTray.items
	    Rectangle {
		id: child
		/* implicitHeight: showTray ? trayItem.implicitWidth + margin : 0 */
		implicitHeight: trayItem.implicitHeight + margin
		implicitWidth: showTray ? trayItem.implicitWidth + margin : 0

		Behavior on implicitWidth { PropertyAnimation { duration: animationLength } }
		
		color: "transparent"
		MouseArea {
		    anchors.fill: parent
		    cursorShape: Qt.PointingHandCursor
		    onClicked: (mouse) => {
			var mapped = child.mapToItem(null, mouse.x, mouse.y)
			menuAnchor.anchor.rect.x = mapped.x
			menuAnchor.anchor.rect.y = mapped.y
			menuAnchor.menu = modelData.menu
			if (modelData.hasMenu) menuAnchor.open()
			else modelData.activate()
		    }
		}
		IconImage {
		    id: trayItem
		    source: modelData.icon 
		    implicitSize: 20
		    anchors.centerIn: parent
		}
	    }
	}
    }
}