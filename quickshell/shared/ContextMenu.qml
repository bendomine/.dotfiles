import QtQuick
import QtQuick.Layouts
import ".."

// Inline context menu drawn inside a BarPopup (put it in the popup's `overlay`).
// While open it captures the popup's keyboard navigation (j/k/Return/Escape) and
// a click outside it closes it.
//   overlay: ContextMenu { id: menu }
//   menu.show(rowItem, [
//       { text: "Connect", icon: "…", action: () => device.connect() },
//       { text: "Forget", icon: "…", danger: true, enabled: device.paired, action: () => device.forget() }
//   ])
Item {
	id: root
	property real menuWidth: 180
	property var actions: []
	readonly property bool isOpen: d.open
	readonly property Item navRoot: column // BarPopup navigates rows under this item

	signal closed()

	function show(target, actionList) {
		const popup = Popups.owner(root);
		actions = actionList;
		const below = target.mapToItem(root, target.width, target.height);
		const above = target.mapToItem(root, target.width, 0);
		d.anchorX = below.x;
		d.anchorBelow = below.y + 2;
		d.anchorAbove = above.y - 2;
		if (!d.open) {
			d.open = true;
			if (popup)
				popup.pushNavScope(root);
		}
		// Delegates for the new actions settle after this call returns.
		Qt.callLater(() => {
			if (!d.open || !popup)
				return;
			const rows = popup.navItems();
			popup.setFocusItem(rows.length > 0 ? rows[0] : null);
		});
	}

	function close() {
		if (!d.open)
			return;
		d.open = false;
		const popup = Popups.owner(root);
		if (popup)
			popup.popNavScope(root);
		closed();
	}

	function trigger(entry) {
		close();
		if (entry && typeof entry.action === "function")
			entry.action();
	}

	anchors.fill: parent
	visible: d.open || box.opacity > 0
	z: 100

	QtObject {
		id: d
		property bool open: false
		property real anchorX: 0
		property real anchorBelow: 0
		property real anchorAbove: 0
	}

	// Click-away catcher
	MouseArea {
		anchors.fill: parent
		enabled: d.open
		acceptedButtons: Qt.AllButtons
		onClicked: root.close()
	}

	Rectangle {
		id: box
		width: root.menuWidth
		height: column.implicitHeight + 2 * Theme.spacingSmall
		x: Math.max(Theme.spacingSmall, Math.min(root.width - width - Theme.spacingSmall, d.anchorX - width))
		y: {
			const fitsBelow = d.anchorBelow + height <= root.height - Theme.spacingSmall;
			const y = fitsBelow ? d.anchorBelow : d.anchorAbove - height;
			return Math.max(Theme.spacingSmall, Math.min(root.height - height - Theme.spacingSmall, y));
		}
		radius: Theme.radiusSmall
		color: Theme.mix(Theme.surface, Theme.surfaceVariant, 0.5)
		border.width: 1
		border.color: Theme.border
		opacity: d.open ? 1 : 0
		scale: d.open ? 1 : 0.94
		transformOrigin: Item.TopRight
		Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
		Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

		ColumnLayout {
			id: column
			x: Theme.spacingSmall
			y: Theme.spacingSmall
			width: parent.width - 2 * Theme.spacingSmall
			spacing: 1

			Repeater {
				model: root.actions
				MenuRow {
					required property var modelData
					compact: true
					icon: modelData.icon ?? ""
					text: modelData.text ?? ""
					enabled: modelData.enabled !== false
					textColor: modelData.danger ? Theme.urgent : Theme.foreground
					iconColor: modelData.danger ? Theme.urgent : (highlighted ? Theme.foreground : Theme.foregroundMuted)
					onActivated: root.trigger(modelData)
					onAltActivated: root.trigger(modelData)
				}
			}
		}
	}
}
