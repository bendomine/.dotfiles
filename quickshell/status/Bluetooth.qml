import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: root 
    required property Item anchorPoint
    required property real iconSize
    property real xOffset: -iconSize / 2 + 10
    property real yOffset: -iconSize / 2
    property real dWidth: 200
    property real dHeight: 300
    property real animProgress: displayHandler.hovered ? 1.0 : -0.1
    property bool displayWindow: animProgress > -0.1

    anchor.item: anchorPoint
    anchor.rect.x: xOffset
    anchor.rect.y: yOffset
    visible: true
    color: "transparent"

    implicitWidth: displayWindow ? dWidth : iconSize + 2
    implicitHeight: displayWindow ? dHeight : iconSize + 2

    function mix(x, y, a, b) {
	a /= b;
	a = Math.min(Math.max(a, 0.0), 1.0);
	return x * (1 - a) + y * a;
    }

    Behavior on animProgress { NumberAnimation {
	duration: 300
	easing.type: Easing.OutQuart
    } }

    HoverHandler {
	id: displayHandler
    }

    Rectangle {
	clip: true
	implicitWidth: mix(iconSize, dWidth, animProgress, 0.4)
	implicitHeight: mix(iconSize, dHeight, animProgress - 0.4, 0.6)
	color: "white"
	radius: iconSize / 2

	RowLayout {
	    Rectangle {
		color: "transparent"
		Layout.preferredWidth: iconSize
		Layout.preferredHeight: iconSize
		Text {
		    anchors.centerIn: parent
		    text: "󰂯"
		    font.pointSize: 12
		}
	    }
	    Text {
		text: "Bluetooth Settings"
	    }
	}
    }
}