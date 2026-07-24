import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

Text {
    text: "Battery: " + (UPower.displayDevice.percentage * 100).toFixed() + "%"
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