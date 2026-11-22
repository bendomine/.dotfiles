import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// System tray pill + popup (quickshell:toggle-tray).
// Grid navigation: h/j/k/l or arrows; Return/Space activates (or opens the menu for
// menu-only items and `menuIds`); Shift+Return / m / right click opens the item menu.
StatusBox {
	id: root
	property list<string> menuIds: [
		"Antigravity_status_icon_1",
		"spotify-client",
		"steam"
	]
	readonly property int columns: 5
	readonly property int cellSize: 44

	active: popup.open

	function openMenu(cell, item) {
		if (!item.hasMenu)
			return;
		const pos = cell.mapToItem(null, cell.width / 2, cell.height);
		menuAnchor.anchor.rect.x = pos.x;
		menuAnchor.anchor.rect.y = pos.y;
		menuAnchor.menu = item.menu;
		menuAnchor.open();
	}

	Glyph {
		text: "󱊖"
		color: root.fg
	}

	QsMenuAnchor {
		id: menuAnchor
		anchor.window: popup
	}

	BarPopup {
		id: popup
		anchorItem: root
		shortcutName: "toggle-tray"
		navColumns: root.columns
		contentWidth: root.columns * root.cellSize + (root.columns - 1) * grid.columnSpacing
		// Keep the popup open (and release the focus grab) while an item menu is shown.
		keepOpen: menuAnchor.visible
		suspendGrab: menuAnchor.visible

		PopupHeader {
			icon: "󱊖"
			title: "System Tray"
			subtitle: {
				const item = popup.focusItem;
				if (item && item.trayItem)
					return item.trayItem.tooltipTitle || item.trayItem.title || item.trayItem.id;
				return SystemTray.items.values.length + " items";
			}
		}

		GridLayout {
			id: grid
			Layout.fillWidth: true
			columns: root.columns
			columnSpacing: Theme.spacingSmall
			rowSpacing: Theme.spacingSmall

			Repeater {
				model: SystemTray.items

				delegate: Rectangle {
					id: cell
					required property var modelData
					readonly property var trayItem: modelData
					readonly property bool hovered: mouse.containsMouse
					property bool navigable: true
					property bool keyFocused: false

					function activate() {
						if (modelData.onlyMenu || root.menuIds.includes(modelData.id))
							root.openMenu(cell, modelData);
						else
							modelData.activate();
					}
					function activateAlt() {
						root.openMenu(cell, modelData);
					}

					implicitWidth: root.cellSize
					implicitHeight: root.cellSize
					radius: Theme.radiusSmall
					color: keyFocused || hovered ? Theme.surfaceVariant : Theme.alpha(Theme.surfaceVariant, 0)
					border.width: keyFocused ? 1 : 0
					border.color: Theme.accent
					Behavior on color { ColorAnimation { duration: Theme.animFast } }

					MouseArea {
						id: mouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						onContainsMouseChanged: {
							if (containsMouse)
								popup.setFocusItem(cell);
							else if (popup.focusItem === cell)
								popup.setFocusItem(null);
						}
						onClicked: event => {
							if (event.button === Qt.MiddleButton)
								cell.modelData.secondaryActivate();
							else if (cell.modelData.onlyMenu || (cell.modelData.hasMenu && event.button == Qt.RightButton) || root.menuIds.includes(cell.modelData.id))
								root.openMenu(cell, cell.modelData);
							else
								cell.modelData.activate();
						}
					}

					IconImage {
						source: cell.modelData.icon
						implicitSize: 22
						anchors.centerIn: parent
						visible: !override.visible
					}
					// Prefer an icon-theme icon named after the item id when one exists.
					IconImage {
						id: override
						source: Quickshell.iconPath(cell.modelData.id, true)
						implicitSize: 22
						anchors.centerIn: parent
						visible: status === Image.Ready
					}
				}
			}
		}

		StyledText {
			Layout.fillWidth: true
			Layout.margins: Theme.spacing
			visible: SystemTray.items.values.length === 0
			text: "No tray items"
			color: Theme.foregroundMuted
			horizontalAlignment: Text.AlignHCenter
		}
	}
}
