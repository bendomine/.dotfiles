import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "./.."
import "../shared"

// Top bar, one per screen (see shell.qml). Hidden/shown with the
// `quickshell:toggle-bar` global shortcut (ShellState.barVisible).
//
// Floats with margins, rounded corners and a border, except when the screen's
// visible workspace is gapless per the hyprland.lua workspace rules (`w[tv1]`:
// exactly one tiled, visible window; `f[1]`: a maximized window). Then it melds
// into a flat full-width strip at the screen top that the window touches.
PanelWindow {
	id: bar
	required property var modelData
	screen: modelData

	// ── Meld detection ───────────────────────────────────────────────────
	readonly property var monitor: Hyprland.monitorFor(screen)
	// Name of the workspace shown on this monitor: the open special workspace
	// (only known from the monitor's IPC object; Quickshell does not track
	// activespecial) or else the regular active workspace.
	readonly property string workspaceName: {
		const special = monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
		return special !== "" ? special : (monitor?.activeWorkspace?.name ?? "");
	}
	// Mirrors `w[tv1]` / `f[1]`. Toplevel flags come from lastIpcObject, which is
	// only refreshed by Hyprland.refreshToplevels(); toplevels not fetched yet
	// (empty object) are skipped until the next refresh.
	readonly property bool melded: {
		if (workspaceName === "")
			return false;
		let tiled = 0;
		for (const t of Hyprland.toplevels.values) {
			const o = t.lastIpcObject;
			if (!o || !o.workspace)
				continue;
			if ((t.workspace?.name ?? o.workspace.name) !== workspaceName)
				continue;
			if (o.fullscreen === 1)
				return true;
			if (!o.floating && o.mapped && !o.hidden)
				tiled++;
		}
		return tiled === 1;
	}
	// 0 floating … 1 melded (animated).
	property real meld: melded ? 1 : 0
	Behavior on meld { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

	readonly property var refreshEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspace", "workspacev2", "focusedmon", "focusedmonv2", "activespecial", "activespecialv2", "moveworkspace", "moveworkspacev2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "togglegroup", "moveintogroup", "moveoutofgroup"]
	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (bar.refreshEvents.includes(event.name))
				refreshTimer.restart();
		}
	}
	Timer {
		id: refreshTimer
		interval: 50
		onTriggered: {
			Hyprland.refreshToplevels();
			Hyprland.refreshMonitors();
		}
	}
	Component.onCompleted: refreshTimer.restart()

	// ── Geometry ─────────────────────────────────────────────────────────
	// The surface spans the full width with no layer margins; the floating
	// inset is drawn inside it (transparent around `background`, input masked
	// to it), so melding never moves the layer surface itself. The exclusive
	// zone switches as soon as `melded` flips, so Hyprland relayouts windows
	// once, alongside the bar's animation. The surface keeps the floating
	// height until a meld finishes so the animating bar is never clipped.
	anchors {
		left: true
		top: true
		right: true
	}
	implicitHeight: melded && meld >= 1 ? Theme.barHeight : Theme.barHeight + Theme.barMargin
	exclusiveZone: melded ? Theme.barHeight : Theme.barHeight + Theme.barMargin
	mask: Region { item: background }
	color: "transparent"
	visible: ShellState.barVisible || shown > 0

	property real shown: ShellState.barVisible ? 1 : 0
	Behavior on shown { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

	readonly property real sideInset: Theme.barMargin + 2
	readonly property real topInset: Theme.barMargin * (1 - meld)
	// Pills keep their horizontal position while the background grows to the edges.
	readonly property real edgePadding: Theme.barPadding + sideInset * meld

	Rectangle {
		id: background
		x: bar.sideInset * (1 - bar.meld)
		width: parent.width - 2 * x
		height: Theme.barHeight
		y: bar.topInset - (1 - bar.shown) * (height + bar.topInset)
		opacity: bar.shown
		radius: Theme.radius * (1 - bar.meld)
		color: Theme.alpha(Theme.background, Theme.barOpacity + (Theme.barOpacityMelded - Theme.barOpacity) * bar.meld)
		border.width: 1
		border.color: Theme.alpha(Theme.border, 0.6 * (1 - bar.meld))

		// Bottom separator against the window below while melded.
		Rectangle {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			height: 1
			color: Theme.alpha(Theme.border, 0.6)
			opacity: bar.meld
			visible: opacity > 0
		}

		// ── Left ─────────────────────────────────────────────────────────
		RowLayout {
			id: leftRow
			anchors.left: parent.left
			anchors.leftMargin: bar.edgePadding
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.spacingSmall + 2

			Launcher {}
			Workspaces { screen: bar.screen }
			Bluetooth {}
		}

		// ── Center ───────────────────────────────────────────────────────
		RowLayout {
			id: centerRow
			// Free space between the side sections, with a 16px gap on each side.
			readonly property real gapStart: leftRow.x + leftRow.width + 16
			readonly property real gapEnd: rightRow.x - 16
			// True center when it fits, otherwise slide within the free space.
			x: Math.max(gapStart, Math.min(gapEnd - width, (parent.width - width) / 2))
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.spacingSmall + 2

			Media {
				id: media
				active: mediaPopup.open
				// Shrink the title to the free space (40 ≈ glyph + pill padding).
				maxTextWidth: Math.max(0, Math.min(320, centerRow.gapEnd - centerRow.gapStart - 40))
			}
			MediaPopup { id: mediaPopup; anchorItem: media }
		}

		// ── Right ────────────────────────────────────────────────────────
		RowLayout {
			id: rightRow
			anchors.right: parent.right
			anchors.rightMargin: bar.edgePadding
			anchors.verticalCenter: parent.verticalCenter
			spacing: Theme.spacingSmall + 2

			Network {}
			System {}

			Volume {
				id: volume
				active: audioPopup.open
			}
			AudioPopup { id: audioPopup; anchorItem: volume }
			Battery {}
			StatusBox {
				id: clockPill
				interactive: true
				active: calendarPopup.open
				StyledText {
					text: Qt.formatDate(clock.date, "ddd d MMM")
					color: clockPill.fgMuted
				}
				StyledText {
					text: Qt.formatTime(clock.date, "h:mm AP")
					font.weight: Font.Bold
					color: clockPill.fg
				}
			}
			CalendarPopup { id: calendarPopup; anchorItem: clockPill }
			Tray {}
			Power {}
		}
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}
}
