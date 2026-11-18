import Quickshell.Services.UPower
import QtQuick
import "../shared"
import ".."

// Battery pill. Low-battery notifications live in shared/BatteryNotifier.qml
// (instantiated once in shell.qml, not per screen).
StatusBox {
	id: root
	property real percentage: UPower.displayDevice.percentage
	property int batteryState: UPower.displayDevice.state
	readonly property bool charging: batteryState === UPowerDeviceState.Charging
	readonly property bool low: batteryState === UPowerDeviceState.Discharging && percentage <= 0.15
	property string icon: {
		if (charging) return "󰂄"
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
	readonly property color stateColor: active ? fg : (low ? Theme.urgent : (charging ? Theme.success : fg))

	interactive: false
	color: low && !active ? Theme.alpha(Theme.urgent, 0.18) : (active ? Theme.accent : Theme.alpha(Theme.surface, 0.85))

	Glyph {
		text: root.icon
		color: root.stateColor
	}
	StyledText {
		text: (root.percentage * 100).toFixed() + "%"
		color: root.stateColor
	}
}
