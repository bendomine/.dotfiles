import Quickshell
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Calendar popup for the clock pill (quickshell:toggle-calendar):
//   CalendarPopup { anchorItem: clockPill }
// The 42 day cells are the navigation entries (navColumns 7), so the keyboard
// cursor moves by day (h/l, Left/Right, n/p) and week (j/k, Up/Down); moving past
// the shown month switches month. Other keys:
//   [ / ] , PageUp / PageDown, < / >   previous / next month
//   { / }                              previous / next year
//   t / g / Home, Space / Return       back to today
BarPopup {
	id: popup
	shortcutName: "toggle-calendar"
	navColumns: 7

	readonly property int weekStart: 1 // first column: 1 = Monday (0 = Sunday)
	readonly property var today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
	property int year: today.getFullYear()
	property int month: today.getMonth() // 0-based
	property var cursor: null // Date of the keyboard cursor

	// First date shown: the week start strictly before the 1st, so the grid always
	// has days of the neighbouring months on both ends (6 weeks = 42 cells).
	readonly property var gridStart: {
		const first = new Date(year, month, 1);
		const offset = (first.getDay() - weekStart + 7) % 7 || 7;
		return new Date(year, month, 1 - offset);
	}

	function cellDate(i) {
		return new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i);
	}

	function cellIndex(date) {
		return Math.round((date.getTime() - gridStart.getTime()) / 86400000);
	}

	function sameDay(a, b) {
		return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
	}

	// Put the cursor on `date`, switching month if needed.
	function moveCursorTo(date) {
		const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
		cursor = target;
		if (target.getFullYear() !== year || target.getMonth() !== month) {
			year = target.getFullYear();
			month = target.getMonth();
		}
		const cell = cells.itemAt(cellIndex(target));
		if (cell && focusItem !== cell) {
			d.syncing = true;
			setFocusItem(cell);
			d.syncing = false;
		}
	}

	function goToday() {
		moveCursorTo(today);
	}

	function shiftMonth(delta) {
		const c = cursor ?? today;
		const first = new Date(c.getFullYear(), c.getMonth() + delta, 1);
		const days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
		moveCursorTo(new Date(first.getFullYear(), first.getMonth(), Math.min(c.getDate(), days)));
	}

	QtObject {
		id: d
		property bool syncing: false
		property Item lastFocus: null
	}

	SystemClock {
		id: clock
		precision: popup.open ? SystemClock.Seconds : SystemClock.Minutes
	}

	onOpenChanged: {
		if (open)
			Qt.callLater(goToday);
	}

	// BarPopup moves focus by index (and wraps at the grid edges); translate every
	// move between cells into a date step so the cursor can leave the month.
	onFocusItemChanged: {
		const prev = d.lastFocus;
		const to = focusItem;
		d.lastFocus = to;
		if (d.syncing || !to || to.cellIndex === undefined)
			return;
		let target;
		if (!cursor || !prev || prev.cellIndex === undefined) {
			target = cursor ?? to.date; // coming from outside the grid: restore the cursor
		} else {
			const delta = to.cellIndex - prev.cellIndex;
			let step;
			if (delta === 1 || delta === -1 || delta === 7 || delta === -7)
				step = delta;
			else if (delta % 7 === 0)
				step = delta > 0 ? -7 : 7; // wrapped vertically
			else
				step = delta > 0 ? -1 : 1; // wrapped horizontally
			target = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + step);
		}
		if (sameDay(target, to.date) && to.date.getMonth() === month)
			cursor = target;
		else
			Qt.callLater(() => popup.moveCursorTo(target)); // not from inside setFocusItem()
	}

	onKeyPressed: event => {
		switch (event.key) {
		case Qt.Key_T:
		case Qt.Key_G:
		case Qt.Key_Home:
			goToday();
			break;
		case Qt.Key_BracketLeft:
		case Qt.Key_PageUp:
		case Qt.Key_Comma:
		case Qt.Key_Less:
			shiftMonth(-1);
			break;
		case Qt.Key_BracketRight:
		case Qt.Key_PageDown:
		case Qt.Key_Period:
		case Qt.Key_Greater:
			shiftMonth(1);
			break;
		case Qt.Key_BraceLeft:
			shiftMonth(-12);
			break;
		case Qt.Key_BraceRight:
			shiftMonth(12);
			break;
		default:
			return;
		}
		event.accepted = true;
	}

	// ── Header: time and full date ──────────────────────────────────────
	RowLayout {
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacingSmall
		spacing: Theme.spacingSmall

		StyledText {
			text: Qt.formatTime(clock.date, "h:mm")
			font.pixelSize: 38
			font.weight: Font.Bold
		}
		ColumnLayout {
			Layout.alignment: Qt.AlignBottom
			Layout.bottomMargin: 6
			spacing: -2
			StyledText {
				text: Qt.formatTime(clock.date, "AP")
				font.pixelSize: Theme.fontSizeSmall
				font.weight: Font.DemiBold
				color: Theme.accent
			}
			StyledText {
				text: Qt.formatTime(clock.date, "ss")
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
			}
		}
		Item {
			Layout.fillWidth: true
		}
	}
	StyledText {
		Layout.fillWidth: true
		Layout.leftMargin: Theme.spacingSmall
		Layout.bottomMargin: Theme.spacingSmall
		text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
		color: Theme.foregroundMuted
		elide: Text.ElideRight
	}

	Separator {}

	// ── Month switcher (mouse; keyboard uses [ ] / PageUp PageDown) ────
	RowLayout {
		Layout.fillWidth: true
		spacing: Theme.spacingSmall

		MenuRow {
			navigable: false
			compact: true
			Layout.fillWidth: false
			Layout.preferredWidth: 36
			icon: "󰅁"
			onActivated: popup.shiftMonth(-1)
		}
		StyledText {
			Layout.fillWidth: true
			horizontalAlignment: Text.AlignHCenter
			text: Qt.formatDate(new Date(popup.year, popup.month, 1), "MMMM yyyy")
			font.pixelSize: Theme.fontSizeLarge
			font.weight: Font.Bold
		}
		MenuRow {
			navigable: false
			compact: true
			Layout.fillWidth: false
			Layout.preferredWidth: 36
			visible: popup.year !== popup.today.getFullYear() || popup.month !== popup.today.getMonth()
			icon: "󰃶"
			onActivated: popup.goToday()
		}
		MenuRow {
			navigable: false
			compact: true
			Layout.fillWidth: false
			Layout.preferredWidth: 36
			icon: "󰅂"
			onActivated: popup.shiftMonth(1)
		}
	}

	// ── Month grid ──────────────────────────────────────────────────────
	GridLayout {
		Layout.fillWidth: true
		columns: 7
		rowSpacing: 2
		columnSpacing: 2

		Repeater {
			model: 7
			StyledText {
				required property int index
				readonly property int weekday: (popup.weekStart + index) % 7 // 0 = Sunday
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				Layout.preferredHeight: 24
				horizontalAlignment: Text.AlignHCenter
				text: Qt.locale().dayName(weekday, Locale.ShortFormat).slice(0, 2)
				font.pixelSize: Theme.fontSizeSmall
				font.weight: Font.DemiBold
				color: weekday === 0 || weekday === 6 ? Theme.accentAlt : Theme.foregroundMuted
			}
		}

		Repeater {
			id: cells
			model: 42
			delegate: Rectangle {
				id: cell
				required property int index
				readonly property int cellIndex: index
				readonly property var date: popup.cellDate(index)
				readonly property bool inMonth: date.getMonth() === popup.month
				readonly property bool isToday: popup.sameDay(date, popup.today)
				property bool navigable: true
				property bool keyFocused: false
				function activate() {
					popup.goToday();
				}

				Layout.fillWidth: true
				Layout.preferredWidth: 1
				Layout.preferredHeight: 34
				radius: Theme.radiusSmall
				color: isToday ? Theme.accent : (cellHover.hovered ? Theme.surfaceVariant : (keyFocused ? Theme.alpha(Theme.accent, 0.12) : "transparent"))
				border.width: keyFocused ? 2 : 0
				border.color: isToday ? Theme.foreground : Theme.accent
				Behavior on color { ColorAnimation { duration: Theme.animFast } }

				StyledText {
					anchors.centerIn: parent
					text: cell.date.getDate()
					font.weight: cell.isToday || cell.keyFocused ? Font.Bold : Font.Normal
					color: cell.isToday ? Theme.onAccent : (cell.inMonth ? Theme.foreground : Theme.alpha(Theme.foregroundMuted, 0.55))
				}

				HoverHandler {
					id: cellHover
					cursorShape: Qt.PointingHandCursor
				}
				TapHandler {
					onTapped: popup.moveCursorTo(cell.date)
				}
			}
		}
	}

	StyledText {
		Layout.fillWidth: true
		Layout.topMargin: Theme.spacingSmall
		horizontalAlignment: Text.AlignHCenter
		text: "hjkl move · [ ] month · { } year · t today"
		font.pixelSize: Theme.fontSizeSmall
		color: Theme.alpha(Theme.foregroundMuted, 0.7)
	}
}
