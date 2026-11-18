import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Low-battery notifications (once per discharge at 15% and 5%).
// Instantiate exactly once (shell.qml), not per screen.
Scope {
	id: root
	property bool notified15: false
	property bool notified5: false

	function check() {
		const dev = UPower.displayDevice;
		if (dev.state === UPowerDeviceState.Discharging) {
			if (dev.percentage <= 0.05 && !notified5) {
				notified5 = true;
				Quickshell.execDetached(["notify-send", "-u", "critical", "Battery Very Low", "Charge immediately"]);
			} else if (dev.percentage <= 0.15 && !notified15) {
				notified15 = true;
				Quickshell.execDetached(["notify-send", "-u", "critical", "Battery Low", "Charge soon"]);
			}
		} else if (dev.state === UPowerDeviceState.Charging) {
			if (dev.percentage > 0.05)
				notified5 = false;
			if (dev.percentage > 0.15)
				notified15 = false;
		}
	}

	Connections {
		target: UPower.displayDevice
		function onPercentageChanged() {
			root.check();
		}
		function onStateChanged() {
			root.check();
		}
	}
}
