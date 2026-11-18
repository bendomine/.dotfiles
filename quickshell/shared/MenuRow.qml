import QtQuick
import QtQuick.Layouts
import ".."

// List row for BarPopup content: icon, label, sublabel and trailing widgets
// (default property). Highlighted while hovered or keyboard-focused.
//   MenuRow {
//       icon: "…"; text: "Bluetooth"; subtext: "On"; selected: adapter.enabled
//       onActivated: adapter.enabled = !adapter.enabled   // click, Space/Return
//       onAltActivated: menu.show(this, actions)           // right click, Shift+Return, o, m
//       Toggle { checked: adapter.enabled; onToggled: v => adapter.enabled = v }
//   }
// Implements the BarPopup nav protocol (navigable, keyFocused, activate(),
// activateAlt(), decrease(), increase()).
Rectangle {
	id: root
	property string icon: ""
	property string text: ""
	property string subtext: ""
	property bool selected: false // e.g. connected / current: accent icon
	property bool compact: false
	property color textColor: Theme.foreground
	property color iconColor: selected ? Theme.accent : (highlighted ? Theme.foreground : Theme.foregroundMuted)
	property bool navigable: true
	property bool keyFocused: false
	readonly property bool hovered: hover.hovered
	readonly property bool highlighted: keyFocused || hovered
	default property alias trailing: trailingRow.data

	signal activated()
	signal altActivated()
	signal decreased()
	signal increased()

	function activate() {
		activated();
	}
	function activateAlt() {
		altActivated();
	}
	function decrease() {
		decreased();
	}
	function increase() {
		increased();
	}

	Layout.fillWidth: true
	implicitWidth: content.implicitWidth + 2 * Theme.spacing
	implicitHeight: compact ? Theme.rowHeightCompact : Math.max(Theme.rowHeight, content.implicitHeight + 8)
	radius: Theme.radiusSmall
	color: highlighted ? Theme.surfaceVariant : (selected ? Theme.alpha(Theme.accent, 0.08) : "transparent")
	opacity: enabled ? 1 : 0.45
	Behavior on color { ColorAnimation { duration: Theme.animFast } }

	// Keyboard focus marker
	Rectangle {
		anchors.left: parent.left
		anchors.verticalCenter: parent.verticalCenter
		width: 3
		height: root.keyFocused ? parent.height * 0.5 : 0
		radius: 1.5
		color: Theme.accent
		Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
	}

	HoverHandler {
		id: hover
		cursorShape: Qt.PointingHandCursor
		onHoveredChanged: {
			const popup = Popups.owner(root);
			if (!popup)
				return;
			if (hovered)
				popup.setFocusItem(root);
			else if (popup.focusItem === root)
				popup.setFocusItem(null);
		}
	}

	TapHandler {
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onTapped: (eventPoint, button) => {
			if (button === Qt.RightButton)
				root.activateAlt();
			else
				root.activate();
		}
	}

	RowLayout {
		id: content
		anchors.fill: parent
		anchors.leftMargin: Theme.spacing
		anchors.rightMargin: Theme.spacing
		spacing: Theme.spacing

		Glyph {
			visible: root.icon !== ""
			Layout.preferredWidth: 22
			text: root.icon
			color: root.iconColor
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 0
			StyledText {
				Layout.fillWidth: true
				text: root.text
				color: root.textColor
				elide: Text.ElideRight
			}
			StyledText {
				Layout.fillWidth: true
				visible: root.subtext !== ""
				text: root.subtext
				font.pixelSize: Theme.fontSizeSmall
				color: Theme.foregroundMuted
				elide: Text.ElideRight
			}
		}

		RowLayout {
			id: trailingRow
			spacing: Theme.spacingSmall
		}
	}
}
