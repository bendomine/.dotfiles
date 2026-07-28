import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

Text {
    property real percentage: UPower.displayDevice.percentage
    property int state: UPower.displayDevice.state
    property string icon: {
        if (state == 1) return "󰂄"
        if (percentage >= 0.95) return "󰁹"
        if (percentage >= 0.90) return "󰂂"
        if (percentage >= 0.80) return "󰂁"
        if (percentage >= 0.70) return "󰂀"
        if (percentage >= 0.60) return "󰁿"
        if (percentage >= 0.50) return "󰁾"
        if (percentage >= 0.40) return "󰁽"
        if (percentage >= 0.30) return "󰁼"
        if (percentage >= 0.20) return "󰁻"
        if (percentage >= 0.10) return "󰁺"
        return "󰂎"
    }
    property color fontColor: "black"
    text: icon + " " + (percentage * 100).toFixed() + "%"
    color: fontColor
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    property bool notified15: false
    property bool notified5: false
    Connections {
	target: UPower.displayDevice
	function onPercentageChanged() {
	    // Charging: 1, discharging: 2
	    if (target.state == 2) {
		if (target.percentage <= 0.05 && !notified5) {
		    notified5 = true;
		    notify5.startDetached();
		}
		else if (target.percentage <= 0.15 && !notified15){
		    notified15 = true;
		    notify15.startDetached();
		}
	    }

	    else if (target.state.toString() == 1) {
		if (target.percentage > 0.05) notified5 = false;
		if (target.percentage > 0.15) notified15 = false;
	    }
	}
    }
    Process {
	id: notify15
	running: false
	command: [ "notify-send", "-u", "critical", "Battery Low", "Charge soon" ]
    }
    Process {
	id: notify5
	running: false
	command: [ "notify-send", "-u", "critical", "Battery Very Low", "Charge immediately" ]
    }
}