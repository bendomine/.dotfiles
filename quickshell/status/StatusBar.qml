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
	// `melded` is settled before animating: it flips back and forth within an
	// event burst (a closed toplevel disappears at once, a new one is skipped
	// until its IPC object arrives, then refreshToplevels() updates the rest),
	// and each flip used to restart the animation mid-way. meldTarget only
	// follows once `melded` has been stable for meldSettle.interval and no
	// refresh is pending, so a transition is exactly one animation.
	property bool meldTarget: false
	onMeldedChanged: meldSettle.restart()
	Timer {
		id: meldSettle
		// Covers the IPC round trip of the refresh started by refreshTimer.
		interval: 50
		onTriggered: {
			// refreshTimer restarts us when it fires.
			if (!refreshTimer.running)
				bar.meldTarget = bar.melded;
		}
	}
	// 0 floating … 1 melded (animated). Same duration and curve as Hyprland's
	// `windows` animation in hyprland.lua (speed 2.59 = 259 ms, easeOutQuint),
	// so the bar settles together with the window that triggered the meld.
	property real meld: meldTarget ? 1 : 0
	Behavior on meld {
		NumberAnimation {
			duration: 259
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
		}
	}

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
		// Hyprland writes an event burst at once; this only has to coalesce it.
		// Kept short: it adds to the delay between the window and the bar moving.
		interval: 25
		onTriggered: {
			Hyprland.refreshToplevels();
			Hyprland.refreshMonitors();
			meldSettle.restart();
		}
	}
	Component.onCompleted: refreshTimer.restart()

	// ── Geometry ─────────────────────────────────────────────────────────
	// The layer surface and its exclusive zone are constant; melding is purely
	// visual (inside the transparent surface). Changing either used to make
	// Hyprland reconfigure the layer and relayout windows: the zone switched
	// ~50 ms after Hyprland had already applied the gapless workspace rule (the
	// bar only learns about it via IPC), retargeting the window's animation
	// mid-flight, and the surface resized again when the meld finished.
	// Floating: the zone leaves gaps_out (10) between the bar and windows.
	// Melded (gaps_out 0): the window starts right at the zone, so the strip
	// fills the whole surface height (barHeight + barMargin) to touch it.
	// Popups anchor below the surface (BarPopup), i.e. below the bar either way.
	anchors {
		left: true
		top: true
		right: true
	}
	implicitHeight: Theme.barHeight + Theme.barMargin
	exclusiveZone: Theme.barHeight + Theme.barMargin
	// The settled shape rather than the animated `background`: a Region follows
	// item geometry, so masking `background` re-sent the input region on every
	// animation frame.
	mask: Region { item: inputArea }
	color: "transparent"
	visible: ShellState.barVisible || shown > 0

	property real shown: ShellState.barVisible ? 1 : 0
	Behavior on shown { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

	readonly property real sideInset: Theme.barMargin + 2
	readonly property real topInset: Theme.barMargin * (1 - meld)
	// Pills keep their horizontal position while the background grows to the edges.
	readonly property real edgePadding: Theme.barPadding + sideInset * meld

	Item {
		id: inputArea
		x: bar.meldTarget ? 0 : bar.sideInset
		y: bar.meldTarget ? 0 : Theme.barMargin
		width: parent.width - 2 * x
		height: parent.height - y
	}

	Rectangle {
		id: background
		x: bar.sideInset * (1 - bar.meld)
		width: parent.width - 2 * x
		// Grows upward to the screen edge; the pills (vertically centered) move
		// only half the inset. Integer geometry at both ends of the animation.
		height: Theme.barHeight + Theme.barMargin * bar.meld
		y: bar.topInset - (1 - bar.shown) * (height + bar.topInset)
		opacity: bar.shown
		radius: Theme.radius * (1 - bar.meld)
		// Smooth sub-pixel edges while moving; crisp and flush once melded.
		antialiasing: bar.meld < 1
		color: Theme.alpha(Theme.background, Theme.barOpacity + (Theme.barOpacityMelded - Theme.barOpacity) * bar.meld)

		// Outline as a separate overlay that fades out: a Rectangle's own border
		// is painted instead of (not over) its fill, so a fading border left a
		// see-through 1px ring, below the hyprland.lua blur ignore_alpha too:
		// a wallpaper seam along the screen top while melded.
		Rectangle {
			anchors.fill: parent
			radius: parent.radius
			antialiasing: parent.antialiasing
			color: "transparent"
			border.width: 1
			border.color: Theme.alpha(Theme.border, 0.6)
			opacity: 1 - bar.meld
			visible: opacity > 0
		}

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
