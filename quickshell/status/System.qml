import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// System pill (CPU / memory usage) + popup (quickshell:toggle-system) with battery,
// brightness (brightnessctl; h/l = ∓5%), CPU history, memory, CPU temperature and
// uptime. Pill values refresh every 3 s; while the popup is open everything
// refreshes every 2 s.
StatusBox {
	id: root

	// ── Stats ────────────────────────────────────────────────────────────
	property real cpu: 0 // 0..1
	property var cpuHistory: [] // last `historySize` cpu samples
	readonly property int historySize: 40
	property real memTotal: 0 // kB
	property real memUsed: 0 // kB
	readonly property real memFraction: memTotal > 0 ? memUsed / memTotal : 0
	property string tempPath: "" // sysfs file in millidegrees C, "" if none found
	property real temperature: -1 // °C
	property real uptime: 0 // seconds
	property bool hasBrightness: false
	property real brightness: 0 // 0..1

	readonly property var battery: UPower.displayDevice
	readonly property bool hasBattery: battery !== null && (battery.isLaptopBattery || (battery.isPresent && battery.type === UPowerDeviceType.Battery))
	readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
	readonly property bool batteryLow: hasBattery && battery.state === UPowerDeviceState.Discharging && battery.percentage <= 0.15

	function formatDuration(seconds) {
		const m = Math.floor(seconds / 60);
		const days = Math.floor(m / 1440);
		const h = Math.floor(m % 1440 / 60);
		if (days > 0)
			return days + "d " + h + "h";
		if (h > 0)
			return h + "h " + (m % 60) + "m";
		return (m % 60) + "m";
	}

	function formatGiB(kb) {
		return (kb / 1048576).toFixed(1);
	}

	function batteryIcon() {
		const p = battery.percentage;
		if (charging)
			return "󰂄";
		if (p >= 0.95)
			return "󰁹";
		if (p >= 0.75)
			return "󰂁";
		if (p >= 0.55)
			return "󰁿";
		if (p >= 0.35)
			return "󰁽";
		if (p >= 0.15)
			return "󰁻";
		return "󰂎";
	}

	function batteryStatus() {
		switch (battery.state) {
		case UPowerDeviceState.Charging:
			return battery.timeToFull > 0 ? "Charging · " + formatDuration(battery.timeToFull) + " to full" : "Charging";
		case UPowerDeviceState.Discharging:
			return battery.timeToEmpty > 0 ? "On battery · " + formatDuration(battery.timeToEmpty) + " left" : "On battery";
		case UPowerDeviceState.FullyCharged:
			return "Fully charged";
		case UPowerDeviceState.PendingCharge:
			return "Plugged in, not charging";
		case UPowerDeviceState.PendingDischarge:
			return "Waiting to discharge";
		case UPowerDeviceState.Empty:
			return "Empty";
		}
		return "Unknown state";
	}

	function parseStat(text) {
		const m = text.match(/^cpu\s+(.*)$/m);
		if (!m)
			return;
		const v = m[1].trim().split(/\s+/).map(Number);
		const idle = v[3] + (v[4] || 0); // idle + iowait
		const total = v.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
		if (d.lastTotal > 0 && total > d.lastTotal) {
			cpu = Math.max(0, Math.min(1, 1 - (idle - d.lastIdle) / (total - d.lastTotal)));
			cpuHistory = cpuHistory.concat([cpu]).slice(-historySize);
		}
		d.lastTotal = total;
		d.lastIdle = idle;
	}

	function parseMeminfo(text) {
		const total = text.match(/^MemTotal:\s+(\d+)/m);
		const avail = text.match(/^MemAvailable:\s+(\d+)/m);
		if (!total || !avail)
			return;
		memTotal = Number(total[1]);
		memUsed = memTotal - Number(avail[1]);
	}

	// `brightnessctl -m` line: device,class,current,percent,max
	function parseBrightness(text, fromQuery) {
		const line = text.split("\n").find(l => l.split(",").length >= 5);
		if (!line) {
			if (fromQuery)
				hasBrightness = false;
			return;
		}
		const f = line.split(",");
		const cur = Number(f[2]);
		const max = Number(f[4]);
		if (max > 0 && !isNaN(cur)) {
			brightness = cur / max;
			hasBrightness = true;
		}
	}

	function setBrightness(value) {
		const pct = Math.max(1, Math.min(100, Math.round(value * 100)));
		brightness = pct / 100;
		if (brightnessSet.running) {
			d.pendingBrightness = pct;
		} else {
			brightnessSet.command = ["brightnessctl", "-m", "-n2", "set", pct + "%"];
			brightnessSet.running = true;
		}
	}

	function poll() {
		statFile.reload();
		memFile.reload();
		if (!popup.open)
			return;
		uptimeFile.reload();
		if (tempPath !== "")
			tempFile.reload();
		if (!brightnessSet.running && d.pendingBrightness < 0)
			brightnessQuery.running = true;
	}

	QtObject {
		id: d
		property real lastTotal: 0
		property real lastIdle: 0
		property int pendingBrightness: -1
	}

	Timer {
		interval: popup.open ? 2000 : 3000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.poll()
	}

	FileView {
		id: statFile
		path: "/proc/stat"
		onLoaded: root.parseStat(text())
	}
	FileView {
		id: memFile
		path: "/proc/meminfo"
		onLoaded: root.parseMeminfo(text())
	}
	FileView {
		id: uptimeFile
		path: "/proc/uptime"
		onLoaded: root.uptime = parseFloat(text())
	}
	FileView {
		id: tempFile
		path: root.tempPath
		printErrors: false
		onLoaded: {
			const v = parseInt(text());
			root.temperature = isNaN(v) ? -1 : v / 1000;
		}
	}

	// Find a CPU temperature sensor once: package/CPU thermal zones, then
	// coretemp/k10temp hwmon, then the ACPI zone.
	Process {
		running: true
		command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do case \"$(cat \"$z/type\" 2>/dev/null)\" in x86_pkg_temp|TCPU|cpu*|CPU*|soc_thermal) echo \"$z/temp\"; exit 0;; esac; done; " + "for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in coretemp|k10temp|zenpower|cpu_thermal) [ -r \"$h/temp1_input\" ] && echo \"$h/temp1_input\" && exit 0;; esac; done; " + "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat \"$z/type\" 2>/dev/null)\" = acpitz ] && echo \"$z/temp\" && exit 0; done; exit 0"]
		stdout: StdioCollector {
			onStreamFinished: root.tempPath = text.trim()
		}
	}

	Process {
		id: brightnessQuery
		running: true
		command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m"]
		stdout: StdioCollector {
			onStreamFinished: root.parseBrightness(text, true)
		}
	}

	Process {
		id: brightnessSet
		stdout: StdioCollector {
			onStreamFinished: {
				if (d.pendingBrightness < 0)
					root.parseBrightness(text, false);
			}
		}
		onExited: {
			if (d.pendingBrightness >= 0) {
				const pct = d.pendingBrightness;
				d.pendingBrightness = -1;
				root.setBrightness(pct / 100);
			}
		}
	}

	// ── Pill ─────────────────────────────────────────────────────────────
	active: popup.open
	spacing: Theme.spacingSmall

	// Fixed-width percentages so the pill does not resize every refresh.
	TextMetrics {
		id: pctMetrics
		font.family: Theme.fontFamily
		font.pixelSize: Theme.fontSize
		text: "00%"
	}

	Glyph {
		text: "󰘚"
		color: root.cpu >= 0.9 && !root.active ? Theme.urgent : root.fg
	}
	StyledText {
		Layout.minimumWidth: pctMetrics.advanceWidth
		horizontalAlignment: Text.AlignRight
		text: Math.round(root.cpu * 100) + "%"
		color: root.cpu >= 0.9 && !root.active ? Theme.urgent : root.fg
	}
	Glyph {
		Layout.leftMargin: Theme.spacingSmall
		text: "󰍛"
		color: root.memFraction >= 0.9 && !root.active ? Theme.urgent : root.fgMuted
	}
	StyledText {
		Layout.minimumWidth: pctMetrics.advanceWidth
		horizontalAlignment: Text.AlignRight
		text: Math.round(root.memFraction * 100) + "%"
		color: root.memFraction >= 0.9 && !root.active ? Theme.urgent : root.fg
	}

	// ── Popup building blocks ────────────────────────────────────────────
	// Icon, label and right-aligned value.
	component StatLine: RowLayout {
		id: line
		property string icon: ""
		property string label: ""
		property string value: ""
		property color valueColor: Theme.foreground
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacing
		Layout.rightMargin: Theme.spacing
		spacing: Theme.spacing
		Glyph {
			Layout.preferredWidth: 22
			text: line.icon
			color: Theme.foregroundMuted
		}
		StyledText {
			Layout.fillWidth: true
			text: line.label
			elide: Text.ElideRight
		}
		StyledText {
			text: line.value
			font.weight: Font.DemiBold
			color: line.valueColor
		}
	}

	// Horizontal fill bar.
	component Meter: Rectangle {
		id: meter
		property real fraction: 0
		property color barColor: Theme.accent
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacing + 22 + Theme.spacing
		Layout.rightMargin: Theme.spacing
		implicitHeight: 6
		radius: 3
		color: Theme.surfaceVariant
		Rectangle {
			width: parent.width * Math.max(0, Math.min(1, meter.fraction))
			height: parent.height
			radius: parent.radius
			color: meter.barColor
			Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}
	}

	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-system"
		contentWidth: 300

		onOpenChanged: {
			if (open)
				root.poll();
		}

		PopupHeader {
			icon: "󰘚"
			title: "System"
			subtitle: root.uptime > 0 ? "Up " + root.formatDuration(root.uptime) : ""
		}

		// ── Battery ──
		SectionLabel {
			visible: root.hasBattery
			text: "Battery"
		}
		RowLayout {
			visible: root.hasBattery
			Layout.fillWidth: true
			Layout.leftMargin: Theme.spacing
			Layout.rightMargin: Theme.spacing
			spacing: Theme.spacing
			Glyph {
				Layout.preferredWidth: 22
				text: root.hasBattery ? root.batteryIcon() : ""
				font.pixelSize: Theme.iconSizeLarge
				color: root.batteryLow ? Theme.urgent : (root.charging ? Theme.success : Theme.foreground)
			}
			ColumnLayout {
				Layout.fillWidth: true
				spacing: 0
				StyledText {
					text: root.hasBattery ? Math.round(root.battery.percentage * 100) + "%" : ""
					font.pixelSize: Theme.fontSizeLarge
					font.weight: Font.Bold
					color: root.batteryLow ? Theme.urgent : Theme.foreground
				}
				StyledText {
					Layout.fillWidth: true
					text: root.hasBattery ? root.batteryStatus() : ""
					font.pixelSize: Theme.fontSizeSmall
					color: Theme.foregroundMuted
					elide: Text.ElideRight
				}
			}
			RowLayout {
				visible: root.hasBattery && Math.abs(root.battery.changeRate) >= 0.05
				spacing: 2
				Glyph {
					text: "󱐋"
					font.pixelSize: Theme.fontSizeSmall + 2
					color: root.charging ? Theme.success : Theme.foregroundMuted
				}
				StyledText {
					text: root.hasBattery ? Math.abs(root.battery.changeRate).toFixed(1) + " W" : ""
					font.weight: Font.DemiBold
				}
			}
		}
		Meter {
			visible: root.hasBattery
			Layout.bottomMargin: Theme.spacingSmall
			fraction: root.hasBattery ? root.battery.percentage : 0
			barColor: root.batteryLow ? Theme.urgent : (root.charging ? Theme.success : Theme.accent)
		}

		// ── Brightness ──
		SectionLabel {
			visible: root.hasBrightness
			text: "Brightness"
		}
		RowLayout {
			visible: root.hasBrightness
			Layout.fillWidth: true
			Layout.leftMargin: Theme.spacing
			Layout.rightMargin: Theme.spacing
			Layout.preferredHeight: Theme.rowHeightCompact
			spacing: Theme.spacing
			Glyph {
				Layout.preferredWidth: 22
				text: "󰃟"
				color: brightnessSlider.keyFocused ? Theme.accent : Theme.foregroundMuted
			}
			Slider {
				id: brightnessSlider
				value: root.brightness
				from: 0.01
				to: 1
				stepSize: 0.05
				onMoved: v => root.setBrightness(v)
			}
			StyledText {
				Layout.preferredWidth: 38
				horizontalAlignment: Text.AlignRight
				text: Math.round(brightnessSlider.visualValue * 100) + "%"
			}
		}

		// ── Performance ──
		SectionLabel {
			text: "Performance"
		}
		StatLine {
			icon: "󰘚"
			label: "CPU"
			value: Math.round(root.cpu * 100) + "%"
			valueColor: root.cpu >= 0.9 ? Theme.urgent : Theme.foreground
		}
		Rectangle {
			Layout.fillWidth: true
			Layout.leftMargin: Theme.spacing + 22 + Theme.spacing
			Layout.rightMargin: Theme.spacing
			implicitHeight: 34
			radius: 6
			color: Theme.alpha(Theme.surfaceVariant, 0.5)
			clip: true

			Canvas {
				id: spark
				anchors.fill: parent
				anchors.margins: 1
				property var values: root.cpuHistory
				property color lineColor: root.cpu >= 0.9 ? Theme.urgent : Theme.accent
				onValuesChanged: requestPaint()
				onLineColorChanged: requestPaint()
				onWidthChanged: requestPaint()
				onHeightChanged: requestPaint()
				onPaint: {
					const ctx = getContext("2d");
					ctx.reset();
					const vals = values;
					if (vals.length < 2 || width <= 0)
						return;
					const step = width / (root.historySize - 1);
					const x0 = width - (vals.length - 1) * step;
					const yOf = v => height - 1.5 - v * (height - 3);
					ctx.beginPath();
					ctx.moveTo(x0, yOf(vals[0]));
					for (let i = 1; i < vals.length; i++)
						ctx.lineTo(x0 + i * step, yOf(vals[i]));
					ctx.lineWidth = 1.5;
					ctx.lineJoin = "round";
					ctx.strokeStyle = lineColor;
					ctx.stroke();
					ctx.lineTo(width, height);
					ctx.lineTo(x0, height);
					ctx.closePath();
					ctx.fillStyle = Theme.alpha(lineColor, 0.2);
					ctx.fill();
				}
			}
		}
		StatLine {
			Layout.topMargin: Theme.spacingSmall
			icon: "󰍛"
			label: "Memory"
			value: root.formatGiB(root.memUsed) + " / " + root.formatGiB(root.memTotal) + " GiB"
			valueColor: root.memFraction >= 0.9 ? Theme.urgent : Theme.foreground
		}
		Meter {
			fraction: root.memFraction
			barColor: root.memFraction >= 0.9 ? Theme.urgent : Theme.accentAlt
		}
		StatLine {
			Layout.topMargin: Theme.spacingSmall
			visible: root.tempPath !== "" && root.temperature >= 0
			icon: "󰔏"
			label: "CPU temperature"
			value: Math.round(root.temperature) + " °C"
			valueColor: root.temperature >= 85 ? Theme.urgent : Theme.foreground
		}
		StatLine {
			icon: "󰔛"
			label: "Uptime"
			value: root.formatDuration(root.uptime)
		}
	}
}
