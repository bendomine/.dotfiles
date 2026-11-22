import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../shared"
import ".."

// Workspace slots 1..N (N >= 5): empty slots are dim, occupied ones are bright with
// a dot, urgent ones use Theme.urgent; an accent pill slides to the active one.
// Scroll to cycle through existing workspaces.
StatusBox {
	id: root
	property var screen: null
	readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
	readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
	readonly property var byId: {
		const map = {};
		for (const ws of Hyprland.workspaces.values) {
			if (ws.id > 0)
				map[ws.id] = ws;
		}
		return map;
	}
	readonly property int slotCount: Math.max(5, activeId, ...Object.keys(byId).map(Number))
	readonly property int slotSize: Theme.pillHeight - 8
	readonly property int slotSpacing: 3

	interactive: false
	padding: 4

	function dispatchWorkspace(target) {
		Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${target}" })` : `workspace ${target}`);
	}

	function focusWorkspace(id) {
		const ws = byId[id];
		if (ws)
			ws.activate();
		else
			dispatchWorkspace(id);
	}

	onScrolled: steps => dispatchWorkspace(steps < 0 ? "e+1" : "e-1")

	// Elastic indicator: the leading edge moves faster than the trailing one.
	property bool movingRight: true
	property int previousId: 0
	property real indicatorLeft: 0
	property real indicatorRight: slotSize
	Behavior on indicatorLeft { NumberAnimation { duration: root.movingRight ? Theme.animSlow : Theme.animNormal; easing.type: Easing.OutCubic } }
	Behavior on indicatorRight { NumberAnimation { duration: root.movingRight ? Theme.animNormal : Theme.animSlow; easing.type: Easing.OutCubic } }
	onActiveIdChanged: {
		// Reading indicatorLeft would return the animated value, so use the target.
		const left = (activeId - 1) * (slotSize + slotSpacing);
		movingRight = activeId > previousId;
		previousId = activeId;
		indicatorLeft = left;
		indicatorRight = left + slotSize;
	}
	Component.onCompleted: activeIdChanged()

	Item {
		implicitWidth: slots.implicitWidth
		implicitHeight: root.slotSize

		Rectangle {
			x: root.indicatorLeft
			width: root.indicatorRight - root.indicatorLeft
			height: root.slotSize
			radius: height / 2
			color: Theme.accent
		}

		Row {
			id: slots
			spacing: root.slotSpacing

			Repeater {
				model: root.slotCount

				Item {
					id: slot
					required property int index
					readonly property int wsId: index + 1
					readonly property var ws: root.byId[wsId] ?? null
					readonly property bool isActive: wsId === root.activeId
					readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0
					readonly property bool urgent: ws !== null && ws.urgent
					width: root.slotSize
					height: root.slotSize

					Rectangle {
						anchors.fill: parent
						radius: height / 2
						color: slot.urgent && !slot.isActive ? Theme.alpha(Theme.urgent, 0.25) : Theme.alpha(Theme.surfaceVariant, slotMouse.containsMouse && !slot.isActive ? 1 : 0)
						Behavior on color { ColorAnimation { duration: Theme.animFast } }
					}

					StyledText {
						anchors.centerIn: parent
						anchors.verticalCenterOffset: slot.occupied && !slot.isActive ? -1 : 0
						text: slot.wsId
						font.pixelSize: Theme.fontSizeSmall
						font.weight: slot.isActive || slot.occupied ? Font.Bold : Font.Normal
						color: slot.isActive ? Theme.onAccent : (slot.urgent ? Theme.urgent : (slot.occupied ? Theme.foreground : Theme.alpha(Theme.foregroundMuted, 0.6)))
					}

					// Occupied marker
					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.bottom: parent.bottom
						anchors.bottomMargin: 2
						width: 3
						height: 3
						radius: 1.5
						visible: slot.occupied && !slot.isActive
						color: slot.urgent ? Theme.urgent : Theme.accent
					}

					MouseArea {
						id: slotMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.focusWorkspace(slot.wsId)
					}
				}
			}
		}
	}
}
