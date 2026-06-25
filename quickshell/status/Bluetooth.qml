import Quickshell
import QtQuick

PopupWindow {
    id: root
    required property Item anchorPoint
    property real xOffset: -icon.implicitWidth / 2 + margin * 2 + 7
    property real yOffset: -icon.implicitHeight / 2
    property real margin: 1
    property bool displayed
    property real dWidth: 100
    property real dHeight: 300
    
    anchor.item: anchorPoint
    anchor.rect.x: xOffset
    anchor.rect.y: yOffset
    /* implicitWidth: displayHandler.hovered ? 100 : icon.implicitWidth */
    /* implicitHeight: displayHandler.hovered ? 300 : icon.implicitHeight */
    color: "white"
    visible: true
    
    HoverHandler {
	id: displayHandler
    }

    Rectangle {
        id: icon
	anchors.left: parent.left
	anchors.top: parent.top
	color: "#50000000"
	property real dimension: Math.max(iconText.implicitWidth, iconText.implicitHeight)
	implicitWidth: dimension + margin * 2
	implicitHeight: dimension + margin * 2
	radius: dimension + margin

	state: displayHandler.hovered ? "DISPLAYED" : "COLLAPSED"
	states: [
	    State {
		name: "DISPLAYED"
		PropertyChanges {
		    root {
			implicitWidth: dWidth
			implicitHeight: dHeight
		    }
		}
	    },
	    State {
		name: "COLLAPSED"
		PropertyChanges {
		    root {
			implicitWidth: icon.implicitWidth
			implicitHeight: icon.implicitHeight
		    }
		}
	    }
	]

	transitions: [
	    Transition {
		to: "DISPLAYED"
		SequentialAnimation {
		    NumberAnimation {
			target: root
			property: "implicitWidth"
			duration: dWidth * 5
		    }
		    NumberAnimation {
			target: root
			property: "implicitHeight"
			duration: dHeight * 5
		    }
		}
	    },
	    Transition {
		from: "DISPLAYED"
		SequentialAnimation {
		    NumberAnimation {
			target: root
			property: "implicitHeight"
			duration: dHeight * 5
		    }
		    NumberAnimation {
			target: root
			property: "implicitWidth"
			duration: dWidth * 5
		    }
		}
	    }
	]
	
	Text {
	    anchors.margins: margin
	    anchors.centerIn: parent
	    id: iconText
	    text: "󰂯"
	    font.pointSize: 13.5
	}
    }
}
