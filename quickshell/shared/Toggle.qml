// Toggle.qml
import QtQuick
import QtQuick.Controls

Switch {
    id: control

    // 1. Override the indicator (The track and the knob)
    indicator: Rectangle {
        implicitWidth: 24
        implicitHeight: 14
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 14
        
        // Change color based on the Switch's built-in state
        color: control.checked ? theme.highlight : "#CCCCCC"
	Behavior on color { ColorAnimation { duration: 100 } }
        /* border.color: control.checked ? "#4CAF50" : "#999999" */

        // The knob (The little circle that moves)
        Rectangle {
            x: control.checked ? parent.width - width - 2 : 2
	    Behavior on x { PropertyAnimation { duration: 100 } }
            width: 10
            height: 10
            radius: 10
            color: "black"
	    anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 2. Override the contentItem (The text next to the switch)
    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        /* color: control.down ? "#17a81a" : "#21be2b" */
        verticalAlignment: Text.AlignVCenter
        
        leftPadding: control.indicator.width + control.spacing
    }
}