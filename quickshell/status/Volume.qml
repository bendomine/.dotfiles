import QtQuick
import Quickshell.Services.Pipewire
import "../shared"
import ".."

// Volume pill: scroll to change volume, left click toggles mute.
StatusBox {
	id: root
	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var audio: sink && sink.audio ? sink.audio : null
	property real volume: audio ? Math.round(audio.volume * 100) : 0
	property bool muted: audio ? audio.muted : false
	property string icon: muted ? "󰝟" : (volume == 0 ? "" : (volume < 50 ? "󰖀" : "󰕾"))

	PwObjectTracker {
		objects: root.sink ? [root.sink] : []
	}

	onClicked: button => {
		if (button === Qt.LeftButton && audio)
			audio.muted = !audio.muted;
	}
	onScrolled: steps => {
		if (audio)
			audio.volume = Math.max(0, Math.min(1, audio.volume + steps * 0.05));
	}

	Glyph {
		text: root.icon
		color: root.muted && !root.active ? root.fgMuted : root.fg
	}
	StyledText {
		text: root.audio ? root.volume + "%" : "--"
		color: root.muted && !root.active ? root.fgMuted : root.fg
	}
}
