import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../shared"
import ".."

// On-screen display for volume (default sink volume / mute) and screen brightness.
// One instance in shell.qml; shows on the focused monitor for `timeout` ms after a
// change. Click-through, never takes keyboard focus. Initial values are ignored.
PanelWindow {
	id: root

	property int timeout: 1500
	property real bottomOffset: 80

	// What is currently displayed.
	property string kind: "volume" // "volume" | "brightness"
	property real level: 0 // 0..1
	property bool muted: false
	readonly property string icon: {
		if (kind === "brightness")
			return level < 0.34 ? "󰃞" : (level < 0.67 ? "󰃟" : "󰃠");
		if (muted)
			return "󰝟";
		const v = Math.round(level * 100);
		return v === 0 ? "" : (v < 50 ? "󰖀" : "󰕾");
	}

	property bool shown: false
	property real progress: shown ? 1 : 0
	Behavior on progress { NumberAnimation { duration: root.shown ? Theme.animNormal : Theme.animSlow; easing.type: root.shown ? Easing.OutCubic : Easing.InCubic } }

	function flash(kind, level, muted) {
		if (!shown && progress === 0) {
			const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
			const target = Quickshell.screens.find(s => s.name === name);
			if (target && target !== root.screen)
				root.screen = target;
		}
		root.kind = kind;
		root.level = Math.max(0, level);
		root.muted = muted;
		root.shown = true;
		hideTimer.restart();
	}

	visible: progress > 0
	color: "transparent"
	anchors.bottom: true
	margins.bottom: bottomOffset
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-osd"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	// Empty region: fully click-through.
	mask: Region {}
	implicitWidth: pill.width + 2 * shadowMargin
	implicitHeight: pill.height + 2 * shadowMargin

	readonly property real shadowMargin: 18

	Timer {
		id: hideTimer
		interval: root.timeout
		onTriggered: root.shown = false
	}

	// ── Volume ───────────────────────────────────────────────────────────
	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var sinkAudio: sink && sink.audio ? sink.audio : null

	PwObjectTracker {
		objects: root.sink ? [root.sink] : []
	}

	// Pipewire fills in audio props asynchronously after the sink is bound; only
	// react to changes once the current sink has settled.
	property bool volumeArmed: false
	onSinkChanged: {
		volumeArmed = false;
		armTimer.restart();
	}
	Timer {
		id: armTimer
		interval: 800
		running: true
		onTriggered: root.volumeArmed = root.sink !== null && root.sink.ready
	}
	Connections {
		target: root.sink
		ignoreUnknownSignals: true
		function onReadyChanged() {
			if (root.sink.ready)
				armTimer.restart();
		}
	}
	Connections {
		target: root.sinkAudio
		ignoreUnknownSignals: true
		function onVolumeChanged() {
			root.volumeEvent();
		}
		function onMutedChanged() {
			root.volumeEvent();
		}
	}
	function volumeEvent() {
		if (volumeArmed && sinkAudio)
			flash("volume", sinkAudio.volume, sinkAudio.muted);
	}

	// ── Brightness ───────────────────────────────────────────────────────
	// sysfs attributes emit no inotify events, so poll the (tiny) brightness file.
	property string backlightDir: ""
	property real maxBrightness: 0
	property real brightness: -1

	Process {
		running: true
		command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && { echo \"$d\"; break; }; done"]
		stdout: StdioCollector {
			onStreamFinished: root.backlightDir = text.trim()
		}
	}

	FileView {
		id: maxFile
		path: root.backlightDir !== "" ? root.backlightDir + "/max_brightness" : ""
		printErrors: false
		onLoaded: root.maxBrightness = parseInt(text()) || 0
	}

	FileView {
		id: brightnessFile
		path: root.maxBrightness > 0 ? root.backlightDir + "/brightness" : ""
		printErrors: false
		onLoaded: {
			const v = parseInt(text());
			if (isNaN(v))
				return;
			const first = root.brightness < 0;
			if (v === root.brightness)
				return;
			root.brightness = v;
			if (!first)
				root.flash("brightness", v / root.maxBrightness, false);
		}
	}

	Timer {
		interval: 250
		repeat: true
		running: root.maxBrightness > 0
		onTriggered: brightnessFile.reload()
	}

	// ── Visual ───────────────────────────────────────────────────────────
	Item {
		anchors.fill: parent
		opacity: root.progress
		transform: Translate {
			y: 16 * (1 - root.progress)
		}

		RectangularShadow {
			anchors.fill: pill
			radius: pill.radius
			offset.y: 4
			blur: 16
			spread: 0
			color: Theme.alpha("#000000", Theme.dark ? 0.45 : 0.22)
		}

		Rectangle {
			id: pill
			x: root.shadowMargin
			y: root.shadowMargin
			width: 260
			height: 48
			radius: height / 2
			color: Theme.alpha(Theme.surface, Theme.panelOpacity)
			border.width: 1
			border.color: Theme.alpha(Theme.border, 0.9)

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: Theme.spacingLarge + 2
				anchors.rightMargin: Theme.spacingLarge + 2
				spacing: Theme.spacingLarge

				Glyph {
					Layout.preferredWidth: 24
					text: root.icon
					font.pixelSize: Theme.iconSizeLarge
					color: root.muted ? Theme.foregroundMuted : Theme.accent
				}

				Rectangle {
					Layout.fillWidth: true
					implicitHeight: 6
					radius: height / 2
					color: Theme.surfaceVariant

					Rectangle {
						height: parent.height
						radius: parent.radius
						width: parent.width * Math.min(1, root.level)
						color: root.muted ? Theme.foregroundMuted : Theme.accent
						Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
						Behavior on color { ColorAnimation { duration: Theme.animFast } }
					}
				}

				StyledText {
					Layout.preferredWidth: 40
					horizontalAlignment: Text.AlignRight
					text: root.muted ? "Mute" : Math.round(root.level * 100) + "%"
					font.weight: Font.DemiBold
					color: root.muted ? Theme.foregroundMuted : Theme.foreground
				}
			}
		}
	}
}
