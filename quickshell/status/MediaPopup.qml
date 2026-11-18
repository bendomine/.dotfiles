import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Media popup (quickshell:toggle-media): MPRIS player selector, album art, track
// info, seek bar and transport / shuffle / loop controls.
//   Media { id: media; active: mediaPopup.open; MediaPopup { id: mediaPopup; anchorItem: media } }
// Keys (besides the BarPopup defaults): `,` previous track, `.` next track; on the
// player selector and the button rows h/l move sideways.
BarPopup {
	id: root
	shortcutName: "toggle-media"
	// A click on the Media pill toggles play/pause; the popup opens on hover / shortcut.
	clickToToggle: false
	contentWidth: 320

	readonly property var players: Mpris.players.values
	// Explicit choice from the selector; falls back to a playing player, else the first.
	property var selectedPlayer: null
	readonly property var player: {
		if (selectedPlayer && players.includes(selectedPlayer))
			return selectedPlayer;
		return players.find(p => p.isPlaying) ?? players[0] ?? null;
	}
	readonly property bool playing: player !== null && player.isPlaying
	readonly property bool canSeek: player !== null && player.canSeek && player.positionSupported && player.lengthSupported && player.length > 0

	function cyclePlayer(delta) {
		const n = players.length;
		if (n < 2)
			return;
		const i = Math.max(0, players.indexOf(player));
		selectedPlayer = players[((i + delta) % n + n) % n];
	}

	function previous() {
		if (player && player.canGoPrevious)
			player.previous();
	}

	function next() {
		if (player && player.canGoNext)
			player.next();
	}

	function togglePlaying() {
		if (player && player.canTogglePlaying)
			player.togglePlaying();
	}

	function cycleLoop() {
		if (!player || !player.loopSupported)
			return;
		switch (player.loopState) {
		case MprisLoopState.None:
			player.loopState = MprisLoopState.Playlist;
			break;
		case MprisLoopState.Playlist:
			player.loopState = MprisLoopState.Track;
			break;
		default:
			player.loopState = MprisLoopState.None;
		}
	}

	function formatTime(seconds) {
		const s = Math.max(0, Math.floor(seconds || 0));
		const h = Math.floor(s / 3600);
		const m = Math.floor(s / 60) % 60;
		const sec = String(s % 60).padStart(2, "0");
		return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
	}

	onKeyPressed: event => {
		if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
			return;
		if (event.key === Qt.Key_Comma) {
			root.previous();
			event.accepted = true;
		} else if (event.key === Qt.Key_Period) {
			root.next();
			event.accepted = true;
		}
	}

	// MPRIS does not push position updates; poll while visible and playing.
	Timer {
		running: root.visible && root.playing && root.player.positionSupported
		interval: 1000
		repeat: true
		onTriggered: root.player.positionChanged()
	}

	// Round icon button implementing the BarPopup nav protocol; h/l move within its row.
	component IconButton: Rectangle {
		id: btn
		property string icon: ""
		property bool checked: false // toggle state (shuffle / loop): accent tint
		property bool primary: false // play/pause: filled accent
		property bool navigable: true
		property bool keyFocused: false
		readonly property bool highlighted: keyFocused || btnHover.hovered
		signal activated()

		function activate() {
			activated();
		}
		// Inline components cannot see outer ids; reach the popup via Popups.owner().
		function focusSibling(delta) {
			const popup = Popups.owner(btn);
			if (!popup)
				return;
			const items = popup.navItems();
			const target = items[items.indexOf(btn) + delta];
			if (target && target.parent === btn.parent)
				popup.setFocusItem(target);
		}
		function decrease() {
			focusSibling(-1);
		}
		function increase() {
			focusSibling(1);
		}

		implicitWidth: primary ? 46 : 36
		implicitHeight: implicitWidth
		radius: width / 2
		opacity: enabled ? 1 : 0.4
		color: primary ? (highlighted ? Theme.mix(Theme.accent, Theme.foreground, 0.15) : Theme.accent)
			: (highlighted ? Theme.surfaceVariant : (checked ? Theme.alpha(Theme.accent, 0.18) : "transparent"))
		border.width: keyFocused ? 2 : 0
		border.color: primary ? Theme.foreground : Theme.accent
		scale: btnTap.pressed ? 0.9 : 1
		Behavior on color { ColorAnimation { duration: Theme.animFast } }
		Behavior on scale { NumberAnimation { duration: Theme.animFast } }

		Glyph {
			anchors.centerIn: parent
			text: btn.icon
			font.pixelSize: btn.primary ? Theme.iconSizeLarge + 2 : Theme.iconSize + 2
			color: btn.primary ? Theme.onAccent : (btn.checked ? Theme.accent : Theme.foreground)
		}

		HoverHandler {
			id: btnHover
			cursorShape: Qt.PointingHandCursor
			onHoveredChanged: {
				const popup = Popups.owner(btn);
				if (!popup)
					return;
				if (hovered)
					popup.setFocusItem(btn);
				else if (popup.focusItem === btn)
					popup.setFocusItem(null);
			}
		}

		TapHandler {
			id: btnTap
			onTapped: btn.activate()
		}
	}

	PopupHeader {
		icon: "󰝚"
		title: "Media"
		subtitle: root.player ? (root.player.identity || "Player") + (root.playing ? " · Playing" : " · Paused") : "No player"
	}

	// ── Player selector ──────────────────────────────────────────────────
	MenuRow {
		visible: root.players.length > 1
		compact: true
		icon: "󰎇"
		text: root.player ? (root.player.identity || "Player") : ""
		subtext: (root.players.indexOf(root.player) + 1) + " / " + root.players.length + "  ·  h / l to switch"
		onActivated: root.cyclePlayer(1)
		onDecreased: root.cyclePlayer(-1)
		onIncreased: root.cyclePlayer(1)
		Glyph {
			text: "‹"
			color: Theme.foregroundMuted
		}
		Glyph {
			text: "›"
			color: Theme.foregroundMuted
		}
	}

	StyledText {
		Layout.fillWidth: true
		Layout.margins: Theme.spacingLarge
		visible: root.player === null
		text: "Nothing is playing"
		color: Theme.foregroundMuted
		horizontalAlignment: Text.AlignHCenter
	}

	// ── Track info ───────────────────────────────────────────────────────
	RowLayout {
		Layout.fillWidth: true
		Layout.topMargin: Theme.spacingSmall
		visible: root.player !== null
		spacing: Theme.spacingLarge

		ClippingRectangle {
			implicitWidth: 84
			implicitHeight: 84
			radius: Theme.radiusSmall
			color: Theme.surfaceVariant

			Glyph {
				anchors.centerIn: parent
				visible: art.status !== Image.Ready
				text: "󰝚"
				font.pixelSize: 36
				color: Theme.foregroundMuted
			}

			Image {
				id: art
				anchors.fill: parent
				source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
				sourceSize.width: 168
				sourceSize.height: 168
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				cache: true
				opacity: status === Image.Ready ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignVCenter
			spacing: 2
			StyledText {
				Layout.fillWidth: true
				text: root.player ? (root.player.trackTitle || "Unknown title") : ""
				font.pixelSize: Theme.fontSizeLarge
				font.weight: Font.Bold
				wrapMode: Text.Wrap
				maximumLineCount: 2
				elide: Text.ElideRight
			}
			StyledText {
				Layout.fillWidth: true
				visible: text !== ""
				text: root.player ? root.player.trackArtist : ""
				color: Theme.foreground
				elide: Text.ElideRight
			}
			StyledText {
				Layout.fillWidth: true
				visible: text !== ""
				text: root.player ? root.player.trackAlbum : ""
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
				elide: Text.ElideRight
			}
		}
	}

	// ── Progress ─────────────────────────────────────────────────────────
	ColumnLayout {
		Layout.fillWidth: true
		Layout.topMargin: Theme.spacing
		Layout.leftMargin: Theme.spacingSmall
		Layout.rightMargin: Theme.spacingSmall
		visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
		spacing: 2

		Slider {
			enabled: root.canSeek
			from: 0
			to: root.player ? root.player.length : 1
			value: root.player ? root.player.position : 0
			stepSize: 5 // seconds per h / l
			onMoved: v => {
				if (root.canSeek)
					root.player.position = v;
			}
		}
		RowLayout {
			Layout.fillWidth: true
			StyledText {
				text: root.player ? root.formatTime(root.player.position) : ""
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
			}
			Item {
				Layout.fillWidth: true
			}
			StyledText {
				text: root.player ? root.formatTime(root.player.length) : ""
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
			}
		}
	}

	// ── Controls ─────────────────────────────────────────────────────────
	RowLayout {
		Layout.alignment: Qt.AlignHCenter
		Layout.topMargin: Theme.spacingSmall
		Layout.bottomMargin: Theme.spacingSmall
		visible: root.player !== null
		spacing: Theme.spacing

		IconButton {
			visible: root.player !== null && root.player.shuffleSupported
			icon: root.player && root.player.shuffle ? "󰒝" : "󰒞"
			checked: root.player !== null && root.player.shuffle
			onActivated: root.player.shuffle = !root.player.shuffle
		}
		IconButton {
			icon: "󰒮"
			enabled: root.player !== null && root.player.canGoPrevious
			onActivated: root.previous()
		}
		IconButton {
			primary: true
			icon: root.playing ? "󰏤" : "󰐊"
			enabled: root.player !== null && root.player.canTogglePlaying
			onActivated: root.togglePlaying()
		}
		IconButton {
			icon: "󰒭"
			enabled: root.player !== null && root.player.canGoNext
			onActivated: root.next()
		}
		IconButton {
			visible: root.player !== null && root.player.loopSupported
			icon: !root.player || root.player.loopState === MprisLoopState.None ? "󰑗" : (root.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖")
			checked: root.player !== null && root.player.loopState !== MprisLoopState.None
			onActivated: root.cycleLoop()
		}
	}
}
