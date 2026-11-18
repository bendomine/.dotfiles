import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../shared"
import ".."

// Now-playing pill: hidden without an MPRIS player; click toggles play/pause.
StatusBox {
	id: root
	// Prefer a playing player, else the first one.
	readonly property var player: {
		const players = Mpris.players.values;
		return players.find(p => p.isPlaying) ?? players[0] ?? null;
	}
	readonly property bool playing: player !== null && player.isPlaying
	readonly property string label: {
		if (!player)
			return "";
		const parts = [player.trackTitle, player.trackArtist].filter(s => s && s.length > 0);
		return parts.length > 0 ? parts.join(" — ") : player.identity;
	}
	property real maxTextWidth: 320

	visible: player !== null

	onClicked: button => {
		if (button === Qt.LeftButton && player && player.canTogglePlaying)
			player.togglePlaying();
	}

	Glyph {
		text: root.playing ? "󰝚" : "󰏤"
		color: root.active ? root.fg : (root.playing ? Theme.accent : root.fgMuted)
	}
	StyledText {
		Layout.maximumWidth: root.maxTextWidth
		text: root.label
		elide: Text.ElideRight
		color: root.playing ? root.fg : root.fgMuted
	}
}
