import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Audio popup (quickshell:toggle-audio): output / input volume, mute and device
// selection for the Pipewire default sink and source.
//   Volume { id: volume; active: audioPopup.open; AudioPopup { id: audioPopup; anchorItem: volume } }
BarPopup {
	id: root
	shortcutName: "toggle-audio"
	contentWidth: 320

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var source: Pipewire.defaultAudioSource
	readonly property var sinkAudio: sink && sink.audio ? sink.audio : null
	readonly property var sourceAudio: source && source.audio ? source.audio : null
	readonly property var nodes: Pipewire.nodes.values
	readonly property var sinks: nodes.filter(n => n && n.audio && n.isSink && !n.isStream)
	readonly property var sources: nodes.filter(n => n && n.audio && !n.isSink && !n.isStream)

	function nodeName(node) {
		if (!node)
			return "None";
		return node.description || node.nickname || node.name || "Unknown device";
	}

	// Device rows: the short nickname, with the (often long, shared-prefix) description below.
	function rowName(node) {
		return node.nickname || node.description || node.name || "Unknown device";
	}

	function rowSubtext(node) {
		return node.description && node.description !== rowName(node) ? node.description : "";
	}

	function percent(audio) {
		return audio ? Math.round(audio.volume * 100) : 0;
	}

	function sinkIcon(audio) {
		if (!audio || audio.muted)
			return "󰝟";
		const v = percent(audio);
		return v === 0 ? "" : (v < 50 ? "󰖀" : "󰕾");
	}

	function sourceIcon(audio) {
		return !audio || audio.muted ? "󰍭" : "󰍬";
	}

	function setVolume(audio, v) {
		if (audio)
			audio.volume = Math.max(0, Math.min(1, v));
	}

	PwObjectTracker {
		objects: [root.sink, root.source].filter(n => n)
	}

	PopupHeader {
		icon: "󰓃"
		title: "Audio"
		subtitle: root.nodeName(root.sink)
	}

	// ── Output ───────────────────────────────────────────────────────────
	SectionLabel {
		text: "Output"
	}

	RowLayout {
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacing
		Layout.rightMargin: Theme.spacing
		spacing: Theme.spacing
		enabled: root.sinkAudio !== null

		Glyph {
			Layout.preferredWidth: 22
			text: root.sinkIcon(root.sinkAudio)
			color: root.sinkAudio && !root.sinkAudio.muted ? Theme.accent : Theme.foregroundMuted
		}
		Slider {
			value: root.sinkAudio ? root.sinkAudio.volume : 0
			accentColor: root.sinkAudio && root.sinkAudio.muted ? Theme.foregroundMuted : Theme.accent
			onMoved: v => root.setVolume(root.sinkAudio, v)
		}
		StyledText {
			Layout.preferredWidth: 38
			horizontalAlignment: Text.AlignRight
			text: root.sinkAudio ? root.percent(root.sinkAudio) + "%" : "--"
			color: Theme.foregroundMuted
		}
	}

	MenuRow {
		icon: root.sinkIcon(root.sinkAudio)
		text: "Mute output"
		compact: true
		enabled: root.sinkAudio !== null
		selected: root.sinkAudio !== null && root.sinkAudio.muted
		onActivated: root.sinkAudio.muted = !root.sinkAudio.muted
		Toggle {
			checked: root.sinkAudio !== null && root.sinkAudio.muted
			onToggled: value => {
				if (root.sinkAudio)
					root.sinkAudio.muted = value;
			}
		}
	}

	ScrollList {
		maxHeight: 160
		Repeater {
			model: ScriptModel { values: root.sinks }
			delegate: MenuRow {
				required property var modelData
				icon: "󰋋"
				text: root.rowName(modelData)
				subtext: root.rowSubtext(modelData)
				compact: subtext === ""
				selected: modelData === root.sink
				onActivated: Pipewire.preferredDefaultAudioSink = modelData
			}
		}
		StyledText {
			Layout.fillWidth: true
			Layout.margins: Theme.spacingSmall
			visible: root.sinks.length === 0
			text: "No output devices"
			color: Theme.foregroundMuted
			horizontalAlignment: Text.AlignHCenter
		}
	}

	Separator {}

	// ── Input ────────────────────────────────────────────────────────────
	SectionLabel {
		text: "Input"
	}

	RowLayout {
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacing
		Layout.rightMargin: Theme.spacing
		spacing: Theme.spacing
		enabled: root.sourceAudio !== null

		Glyph {
			Layout.preferredWidth: 22
			text: root.sourceIcon(root.sourceAudio)
			color: root.sourceAudio && !root.sourceAudio.muted ? Theme.accent : Theme.foregroundMuted
		}
		Slider {
			value: root.sourceAudio ? root.sourceAudio.volume : 0
			accentColor: root.sourceAudio && root.sourceAudio.muted ? Theme.foregroundMuted : Theme.accent
			onMoved: v => root.setVolume(root.sourceAudio, v)
		}
		StyledText {
			Layout.preferredWidth: 38
			horizontalAlignment: Text.AlignRight
			text: root.sourceAudio ? root.percent(root.sourceAudio) + "%" : "--"
			color: Theme.foregroundMuted
		}
	}

	MenuRow {
		icon: root.sourceIcon(root.sourceAudio)
		text: "Mute microphone"
		compact: true
		enabled: root.sourceAudio !== null
		selected: root.sourceAudio !== null && root.sourceAudio.muted
		onActivated: root.sourceAudio.muted = !root.sourceAudio.muted
		Toggle {
			checked: root.sourceAudio !== null && root.sourceAudio.muted
			onToggled: value => {
				if (root.sourceAudio)
					root.sourceAudio.muted = value;
			}
		}
	}

	ScrollList {
		maxHeight: 160
		Repeater {
			model: ScriptModel { values: root.sources }
			delegate: MenuRow {
				required property var modelData
				icon: "󰍬"
				text: root.rowName(modelData)
				subtext: root.rowSubtext(modelData)
				compact: subtext === ""
				selected: modelData === root.source
				onActivated: Pipewire.preferredDefaultAudioSource = modelData
			}
		}
		StyledText {
			Layout.fillWidth: true
			Layout.margins: Theme.spacingSmall
			visible: root.sources.length === 0
			text: "No input devices"
			color: Theme.foregroundMuted
			horizontalAlignment: Text.AlignHCenter
		}
	}
}
