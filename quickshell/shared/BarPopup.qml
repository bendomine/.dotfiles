import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import ".."

// BarPopup: themed drop-down panel attached to a bar item.
//
//   StatusBox {                       // the bar pill (anything with `hovered` + clicked(button))
//       id: pill
//       active: popup.open
//       BarPopup {
//           id: popup
//           anchorItem: pill
//           shortcutName: "toggle-audio"     // GlobalShortcut owned by Popups.qml
//           PopupHeader { icon: "…"; title: "Audio" }
//           MenuRow { icon: "…"; text: "Mute"; onActivated: … ; Toggle { … } }
//           Slider { value: …; onMoved: v => … }
//           overlay: ContextMenu { id: menu }  // optional inline menu
//       }
//   }
//
// Content: children are laid out in a ColumnLayout `contentWidth` wide (use
// Layout.fillWidth). Long lists go in a ScrollList.
//
// Opening: hover over anchorItem (if hoverToOpen; closes again when the pointer
// leaves anchor and panel), left click on anchorItem (if clickToToggle), the
// `quickshell:<shortcutName>` global shortcut, or show()/toggle(). Only one
// popup is open at a time (Popups.current).
// Hover-opened popups are passive: no focus grab, no keyboard focus. Opening via
// shortcut / click / toggle(), or clicking inside a hover-opened popup, pins it:
// it then holds a HyprlandFocusGrab (keyboard focus) and stays open until Escape,
// clicking elsewhere (grab cleared), the shortcut again, or close().
//
// Keyboard navigation: focusable entries are the visible+enabled descendants with
// `navigable: true` (MenuRow, Toggle, Slider, or any Item that declares it), in
// tree order; traversal does not descend into a navigable item. The focused entry
// gets `keyFocused = true` (if it has that property) and is scrolled into view.
//   j / n / Down / Tab      next (j/Down move a row when navColumns > 1)
//   k / p / Up / Shift+Tab  previous
//   h / Left, l / Right     navColumns > 1: move within the row; otherwise call
//                           focusItem.decrease()/increase() and emit navLeft/navRight
//   Space / Return          focusItem.activate(), then activated(item, index)
//   Shift+Return / o / m    focusItem.activateAlt(), then altActivated(item, index)
//   Escape                  close the open ContextMenu, else the popup
// spatialNav: true (opt-in, for mixed layouts such as lists + grids stacked
// vertically) replaces the navColumns logic: j/k/Up/Down focus the nearest entry
// geometrically below/above (nearest row first, then the closest horizontal
// center), h/l/Left/Right the nearest entry in the same row, falling back to
// decrease()/increase() + navLeft/navRight when there is none. Stops at the ends;
// entries scrolled out of a ScrollList still count. n/p/Tab stay linear.
// Every other key (and anything with Ctrl/Alt/Meta) is emitted via
// keyPressed(event) with event.accepted = false; set it to true if handled, e.g.
//   onKeyPressed: event => { if (event.key === Qt.Key_Comma) { …; event.accepted = true } }
PopupWindow {
	id: root

	// ── Configuration ────────────────────────────────────────────────────
	required property Item anchorItem
	property string shortcutName: ""
	property bool hoverToOpen: true
	property bool clickToToggle: true
	property int hoverOpenDelay: 120
	property int hoverCloseDelay: 350
	property real contentWidth: Theme.popupWidth
	property real padding: Theme.padding
	property int navColumns: 1
	property bool spatialNav: false
	// Prevent auto-closing (hover leave / grab cleared), e.g. while a platform menu is open.
	property bool keepOpen: false
	// Temporarily release the focus grab, e.g. while a QsMenuAnchor menu is open.
	property bool suspendGrab: false
	// Extra windows that should not clear the focus grab when clicked.
	property var extraGrabWindows: []
	default property alias content: layout.data
	property alias overlay: overlayLayer.data
	property alias spacing: layout.spacing

	// ── State (read-only by convention) ──────────────────────────────────
	property bool open: false
	property real progress: 0 // 0 closed … 1 open (animated)
	readonly property bool pinned: open && !d.hoverOpened
	readonly property bool hovered: panelHover.hovered
	property Item focusItem: null
	property int focusIdx: -1
	readonly property string screenName: {
		const win = anchorItem ? anchorItem.QsWindow.window : null;
		return win && win.screen ? win.screen.name : "";
	}

	signal activated(Item item, int index)
	signal altActivated(Item item, int index)
	signal navLeft(Item item, int index)
	signal navRight(Item item, int index)
	signal keyPressed(var event)

	// ── API ──────────────────────────────────────────────────────────────
	function show(byHover) {
		// Needs a visible anchor in a visible bar (e.g. not while toggle-bar hid it).
		const bar = anchorItem ? anchorItem.QsWindow.window : null;
		if (!anchorItem || !anchorItem.visible || !bar || !bar.visible)
			return;
		d.hoverOpened = byHover === true;
		open = true;
	}

	function close() {
		open = false;
	}

	// Closed → open pinned; hover-opened → pin (take focus); pinned → close.
	function toggle() {
		if (open && d.hoverOpened)
			d.hoverOpened = false;
		else if (open)
			close();
		else
			show(false);
	}

	// Focusable entries of the active navigation scope, in order.
	function navItems() {
		const out = [];
		const scope = d.navStack.length > 0 ? d.navStack[d.navStack.length - 1].scope.navRoot : layout;
		if (scope)
			d.collect(scope, out);
		return out;
	}

	function setFocusItem(item) {
		if (focusItem !== item) {
			if (focusItem && focusItem.keyFocused !== undefined)
				focusItem.keyFocused = false;
			d.settingFocus = true;
			focusItem = item;
			d.settingFocus = false;
			if (item && item.keyFocused !== undefined)
				item.keyFocused = true;
		}
		focusIdx = item ? navItems().indexOf(item) : -1;
		if (focusIdx >= 0)
			d.lastFocusIdx = focusIdx;
		if (item)
			d.ensureVisible(item);
	}

	function moveFocus(delta) {
		const items = navItems();
		const n = items.length;
		if (n === 0) {
			setFocusItem(null);
			return;
		}
		let i = items.indexOf(focusItem);
		if (i < 0) {
			i = delta > 0 ? 0 : n - 1;
		} else {
			const cols = root.navColumns;
			if (cols > 1 && Math.abs(delta) === cols) {
				// Vertical move in a grid: wrap within the same column.
				const col = i % cols;
				i += delta;
				if (i >= n)
					i = col;
				else if (i < 0) {
					i = Math.floor((n - 1) / cols) * cols + col;
					if (i >= n)
						i -= cols;
				}
			} else {
				i = ((i + delta) % n + n) % n;
			}
		}
		setFocusItem(items[i]);
	}

	// Used by ContextMenu: route navigation to `scope.navRoot` until popNavScope(scope).
	function pushNavScope(scope) {
		d.navStack = d.navStack.concat([{ scope: scope, focus: focusItem }]);
		setFocusItem(null);
	}

	function popNavScope(scope) {
		const idx = d.navStack.findIndex(e => e.scope === scope);
		if (idx < 0)
			return;
		const entry = d.navStack[idx];
		d.navStack = d.navStack.slice(0, idx);
		setFocusItem(entry.focus ?? null);
	}

	// ── Implementation ───────────────────────────────────────────────────
	QtObject {
		id: d
		property bool hoverOpened: false
		property var navStack: []
		property int lastFocusIdx: -1
		property real grabClearedAt: 0
		property bool settingFocus: false
		readonly property bool anyHovered: root.anchorHovered || panelHover.hovered

		function collect(item, out) {
			const kids = item.children;
			for (let i = 0; i < kids.length; i++) {
				const c = kids[i];
				if (!c || !c.visible || !c.enabled)
					continue;
				if (c.navigable === true)
					out.push(c);
				else
					collect(c, out);
			}
		}

		function ensureVisible(item) {
			for (let f = item.parent; f; f = f.parent) {
				if (f.contentY !== undefined && f.contentItem !== undefined && f.flicking !== undefined) {
					const p = item.mapToItem(f.contentItem, 0, 0);
					// ScrollList: measure against where it is heading and ease there.
					const top = f.targetY !== undefined ? f.targetY : f.contentY;
					let y = top;
					if (p.y < top)
						y = Math.max(0, p.y - 4);
					else if (p.y + item.height > top + f.height)
						y = Math.min(f.contentHeight - f.height, p.y + item.height - f.height + 4);
					if (y !== top) {
						if (f.scrollTo !== undefined)
							f.scrollTo(y, true);
						else
							f.contentY = y;
					}
					return;
				}
			}
		}

		function closeScopes() {
			for (let i = navStack.length - 1; i >= 0; i--)
				navStack[i].scope.close();
			navStack = [];
		}

		function callFocused(fn) {
			const it = root.focusItem;
			if (it && typeof it[fn] === "function")
				it[fn]();
			return it;
		}

		// Flickable ancestor of `item` below the content layout, or null.
		function flickableOf(item) {
			for (let p = item.parent; p && p !== layout; p = p.parent) {
				if (p.contentY !== undefined && p.contentItem !== undefined && p.flicking !== undefined)
					return p;
			}
			return null;
		}

		// Geometry of nav items in the content layout's space, with every Flickable
		// (ScrollList) expanded to its full content height, so scrolled-out items
		// keep their place and items below a list stay below all of its rows.
		function navGeometry(items) {
			const flicks = [];
			for (const it of items) {
				const f = flickableOf(it);
				if (f && !flicks.some(e => e.f === f)) {
					const p = f.mapToItem(layout, 0, 0);
					flicks.push({ f: f, x: p.x, top: p.y, bottom: p.y + f.height, extra: Math.max(0, f.contentHeight - f.height) });
				}
			}
			return items.map(it => {
				const f = flickableOf(it);
				const fe = f ? flicks.find(e => e.f === f) : null;
				let x, y;
				if (fe) {
					const q = it.mapToItem(f.contentItem, 0, 0);
					x = fe.x + q.x;
					y = fe.top + q.y;
				} else {
					const p = it.mapToItem(layout, 0, 0);
					x = p.x;
					y = p.y;
				}
				for (const e of flicks) {
					if (e !== fe && y >= e.bottom - 0.5)
						y += e.extra;
				}
				return { item: it, l: x, t: y, r: x + it.width, b: y + it.height, cx: x + it.width / 2, h: it.height };
			});
		}

		// Move focus to the nearest item in `dir` ("up"/"down"/"left"/"right").
		// Returns false (focus unchanged) when there is none.
		function moveSpatial(dir) {
			const items = root.navItems();
			if (items.length === 0)
				return false;
			const idx = items.indexOf(root.focusItem);
			if (idx < 0) {
				root.setFocusItem(dir === "up" || dir === "left" ? items[items.length - 1] : items[0]);
				return true;
			}
			const geo = navGeometry(items);
			const cur = geo[idx];
			const others = geo.filter((g, i) => i !== idx);
			let best = null;
			if (dir === "down" || dir === "up") {
				const down = dir === "down";
				const cands = others.filter(g => down ? g.t >= cur.b - 2 : g.b <= cur.t + 2);
				if (cands.length === 0)
					return false;
				// Nearest row, then the item in it closest horizontally.
				const edge = cands.reduce((a, g) => down ? (g.t < a.t ? g : a) : (g.b > a.b ? g : a));
				const row = cands.filter(g => down ? g.t < edge.t + edge.h / 2 : g.b > edge.b - edge.h / 2);
				best = row.reduce((a, g) => Math.abs(g.cx - cur.cx) < Math.abs(a.cx - cur.cx) - 0.5 ? g : a);
			} else {
				const left = dir === "left";
				const cands = others.filter(g => g.t < cur.b - 1 && g.b > cur.t + 1 && (left ? g.cx < cur.cx - 1 : g.cx > cur.cx + 1));
				if (cands.length === 0)
					return false;
				best = cands.reduce((a, g) => Math.abs(g.cx - cur.cx) < Math.abs(a.cx - cur.cx) ? g : a);
			}
			root.setFocusItem(best.item);
			return true;
		}

		function handleKey(event) {
			const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
			const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
			const cols = d.navStack.length > 0 ? 1 : Math.max(1, root.navColumns);
			let handled = true;
			if (mods) {
				handled = false;
			} else {
				switch (event.key) {
				case Qt.Key_Escape:
					if (navStack.length > 0)
						navStack[navStack.length - 1].scope.close();
					else
						root.close();
					break;
				case Qt.Key_J:
				case Qt.Key_Down:
					if (root.spatialNav)
						moveSpatial("down");
					else
						root.moveFocus(cols);
					break;
				case Qt.Key_K:
				case Qt.Key_Up:
					if (root.spatialNav)
						moveSpatial("up");
					else
						root.moveFocus(-cols);
					break;
				case Qt.Key_N:
				case Qt.Key_Tab:
					root.moveFocus(1);
					break;
				case Qt.Key_P:
				case Qt.Key_Backtab:
					root.moveFocus(-1);
					break;
				case Qt.Key_H:
				case Qt.Key_Left:
					if (root.spatialNav ? !moveSpatial("left") : cols <= 1)
						root.navLeft(callFocused("decrease"), root.focusIdx);
					else if (!root.spatialNav)
						root.moveFocus(-1);
					break;
				case Qt.Key_L:
				case Qt.Key_Right:
					if (root.spatialNav ? !moveSpatial("right") : cols <= 1)
						root.navRight(callFocused("increase"), root.focusIdx);
					else if (!root.spatialNav)
						root.moveFocus(1);
					break;
				case Qt.Key_Return:
				case Qt.Key_Enter:
				case Qt.Key_Space:
					if (shift && event.key !== Qt.Key_Space)
						activateFocused(true);
					else
						activateFocused(false);
					break;
				case Qt.Key_O:
				case Qt.Key_M:
					activateFocused(true);
					break;
				default:
					handled = false;
				}
			}
			if (handled) {
				event.accepted = true;
				hoverOpened = false; // keyboard use pins the popup
			} else {
				event.accepted = false;
				root.keyPressed(event);
			}
		}

		function activateFocused(alt) {
			const it = root.focusItem;
			if (!it)
				return;
			const idx = root.focusIdx;
			if (alt) {
				callFocused("activateAlt");
				root.altActivated(it, idx);
			} else {
				callFocused("activate");
				root.activated(it, idx);
			}
		}
	}

	readonly property bool anchorHovered: anchorItem !== null && anchorItem.hovered === true

	onOpenChanged: {
		if (open) {
			Popups.opening(root);
			closeAnim.stop();
			openAnim.start();
			setFocusItem(null);
			keyScope.forceActiveFocus();
		} else {
			hoverOpenTimer.stop();
			hoverCloseTimer.stop();
			d.closeScopes();
			setFocusItem(null);
			Popups.closing(root);
			openAnim.stop();
			closeAnim.start();
		}
	}

	// Restore keyboard focus by position when the focused entry is destroyed
	// (e.g. its model entry disappeared).
	onFocusItemChanged: {
		if (focusItem === null && !d.settingFocus && focusIdx >= 0 && open) {
			focusIdx = -1;
			Qt.callLater(() => {
				if (!root.open || root.focusItem !== null)
					return;
				const items = root.navItems();
				if (items.length > 0)
					root.setFocusItem(items[Math.min(d.lastFocusIdx, items.length - 1)]);
			});
		}
	}

	onAnchorHoveredChanged: {
		if (anchorHovered && hoverToOpen && !open)
			hoverOpenTimer.restart();
		else if (!anchorHovered)
			hoverOpenTimer.stop();
	}

	Connections {
		target: d
		function onAnyHoveredChanged() {
			if (d.anyHovered)
				hoverCloseTimer.stop();
			else if (root.open && d.hoverOpened)
				hoverCloseTimer.restart();
		}
	}

	onKeepOpenChanged: {
		if (!keepOpen && open && d.hoverOpened && !d.anyHovered)
			hoverCloseTimer.restart();
	}

	Timer {
		id: hoverOpenTimer
		interval: root.hoverOpenDelay
		onTriggered: {
			if (root.anchorHovered && !root.open)
				root.show(true);
		}
	}

	Timer {
		id: hoverCloseTimer
		interval: root.hoverCloseDelay
		onTriggered: {
			if (root.open && d.hoverOpened && !d.anyHovered && !root.keepOpen)
				root.close();
		}
	}

	Connections {
		target: root.anchorItem
		ignoreUnknownSignals: true
		function onClicked(button) {
			if (!root.clickToToggle || button !== Qt.LeftButton)
				return;
			// The press that cleared the grab (and closed us) must not reopen.
			if (Date.now() - d.grabClearedAt < 400)
				return;
			root.toggle();
		}
		function onVisibleChanged() {
			if (!root.anchorItem.visible)
				root.close();
		}
		function onXChanged() {
			if (root.visible)
				root.anchor.updateAnchor();
		}
		function onWidthChanged() {
			if (root.visible)
				root.anchor.updateAnchor();
		}
	}

	Connections {
		target: root.anchorItem ? root.anchorItem.parent : null
		function onXChanged() {
			if (root.visible)
				root.anchor.updateAnchor();
		}
	}

	Component.onCompleted: Popups.register(root)
	Component.onDestruction: Popups.unregister(root)

	NumberAnimation {
		id: openAnim
		target: root
		property: "progress"
		to: 1
		duration: Theme.animNormal
		easing.type: Easing.OutCubic
	}

	NumberAnimation {
		id: closeAnim
		target: root
		property: "progress"
		to: 0
		duration: Theme.animFast + 40
		easing.type: Easing.InCubic
	}

	HyprlandFocusGrab {
		id: grab
		windows: [root].concat(root.extraGrabWindows)
		// Pinned popups only (hover-opened ones must not steal keyboard focus), and
		// only once the popup surface exists; activating earlier never takes effect.
		active: root.open && root.pinned && root.backingWindowVisible && !root.suspendGrab
		onCleared: {
			d.grabClearedAt = Date.now();
			if (!root.keepOpen)
				root.close();
		}
	}

	// ── Window ───────────────────────────────────────────────────────────
	readonly property real shadowMargin: 18
	readonly property real panelWidth: contentWidth + 2 * padding
	readonly property real panelHeight: layout.implicitHeight + 2 * padding

	visible: progress > 0
	color: "transparent"
	implicitWidth: panelWidth + 2 * shadowMargin
	implicitHeight: panelHeight + 2 * shadowMargin
	// The mask must use an untransformed item: Region tracks geometry, not transforms, so masking
	// `frame` captured its open-animation scale (94% x 90%) and let the pointer fall through at
	// the sides and bottom, which then closed hover-opened popups.
	mask: Region { item: maskArea }

	anchor.item: anchorItem
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.adjustment: PopupAdjustment.Slide
	anchor.onAnchoring: {
		if (!anchorItem)
			return;
		// Drop below the bar (not just below the pill), minus the transparent shadow margin.
		const bar = anchorItem.QsWindow.contentItem;
		const pos = anchorItem.QsWindow.itemPosition(anchorItem);
		const below = (bar ? bar.height : anchorItem.height) - pos.y;
		anchor.rect.x = 0;
		anchor.rect.y = 0;
		anchor.rect.width = anchorItem.width;
		anchor.rect.height = Math.max(1, below + Theme.popupGap - shadowMargin);
	}

	Item {
		id: maskArea
		x: root.shadowMargin
		y: root.shadowMargin
		width: root.panelWidth
		height: root.panelHeight
	}

	Item {
		id: frame
		x: root.shadowMargin
		y: root.shadowMargin
		width: root.panelWidth
		height: root.panelHeight
		opacity: root.progress
		transform: [
			Scale {
				origin.x: frame.width / 2
				origin.y: 0
				xScale: 0.94 + 0.06 * root.progress
				yScale: 0.90 + 0.10 * root.progress
			},
			Translate {
				y: -10 * (1 - root.progress)
			}
		]

		RectangularShadow {
			anchors.fill: panel
			radius: panel.radius
			offset.y: 4
			blur: 16
			spread: 0
			color: Theme.alpha("#000000", Theme.dark ? 0.45 : 0.22)
		}

		Rectangle {
			id: panel
			// Marker used by Popups.owner() to find the popup from inside its content.
			readonly property var barPopup: root
			anchors.fill: parent
			radius: Theme.radius
			color: Theme.alpha(Theme.surface, Theme.panelOpacity)
			border.width: 1
			border.color: Theme.alpha(Theme.border, 0.9)

			FocusScope {
				id: keyScope
				anchors.fill: parent
				focus: true
				Keys.onPressed: event => d.handleKey(event)

				ColumnLayout {
					id: layout
					x: root.padding
					y: root.padding
					width: root.contentWidth
					spacing: Theme.spacingSmall
				}

				Item {
					id: overlayLayer
					anchors.fill: parent
				}
			}
		}

		HoverHandler {
			id: panelHover
		}

		// Passive: sees presses even when a child control takes the grab.
		// Clicking inside a hover-opened popup pins it (and takes keyboard focus).
		PointHandler {
			acceptedButtons: Qt.AllButtons
			onActiveChanged: {
				if (active)
					d.hoverOpened = false;
			}
		}
	}
}
