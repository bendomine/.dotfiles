import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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
    implicitWidth: Math.max(tray.implicitWidth, 20) + margin * 2
    color: "#50000000"

    HoverHandler {
	id: trayHover
	cursorShape: Qt.PointingHandCursor
    }

    RowLayout {
	id: tray
	spacing: 0
	anchors.right: parent.right
	anchors.rightMargin: margin
	anchors.verticalCenter: parent.verticalCenter
	QsMenuAnchor {
	    id: menuAnchor
	    anchor.window: barWindow
	}
	Repeater {
	    model: SystemTray.items
	    Rectangle {
		id: child
		implicitHeight: trayItem.implicitHeight + margin
		implicitWidth: showTray ? trayItem.implicitWidth + margin : 0
		clip: true

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
		    opacity: showTray ? 1 : 0
		    Behavior on opacity { PropertyAnimation { duration: animationLength } }
		}
	    }
	}
	Rectangle {
	    implicitWidth: 20
	    implicitHeight: 20
	    color: "transparent"
	    IconImage {
		id: trayArrow
		source: Quickshell.iconPath("pan-down")
		anchors.fill: parent
		visible: false
	    }
	    MultiEffect {
		source: trayArrow
		anchors.fill: trayArrow
		colorizationColor: "white"
		colorization: 1
		brightness: 1
	    }
	    transform: Rotation {
		origin.x: 10
		origin.y: 10
		angle: showTray ? 90 : 0
		Behavior on angle { PropertyAnimation { duration: animationLength } }
	    }
	}
    }
}