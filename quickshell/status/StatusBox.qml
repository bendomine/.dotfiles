import QtQuick
import QtQuick.Layouts
import "../shared"
import ".."

// Bar pill: rounded surface holding a row of icons / labels.
// Children should color themselves with `fg` / `fgMuted` so they follow `active`.
Rectangle {
	id: root
	default property alias content: row.data
	property bool active: false // e.g. its popup is open: accent background
	property bool interactive: true // pointer cursor + hover feedback + clicks
	property real padding: Theme.pillPadding
	property alias spacing: row.spacing
	readonly property bool hovered: hover.hovered
	readonly property color fg: active ? Theme.onAccent : Theme.foreground
	readonly property color fgMuted: active ? Theme.alpha(Theme.onAccent, 0.75) : Theme.foregroundMuted

	signal clicked(int button)
	signal scrolled(int steps) // +1 per wheel notch up, -1 down

	implicitHeight: Theme.pillHeight
	implicitWidth: row.implicitWidth + padding * 2
	radius: height / 2
	color: active ? Theme.accent : (hovered && interactive ? Theme.surfaceVariant : Theme.alpha(Theme.surface, 0.85))
	border.width: 1
	border.color: active ? Theme.accent : Theme.alpha(Theme.border, hovered && interactive ? 0.9 : 0.45)
	Behavior on color { ColorAnimation { duration: Theme.animFast } }
	Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

	HoverHandler {
		id: hover
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
	}

	MouseArea {
		property real wheelAccum: 0
		anchors.fill: parent
		acceptedButtons: root.interactive ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
		onClicked: mouse => root.clicked(mouse.button)
		onWheel: wheel => {
			wheelAccum += wheel.angleDelta.y;
			while (Math.abs(wheelAccum) >= 120) {
				const step = wheelAccum > 0 ? 1 : -1;
				wheelAccum -= step * 120;
				root.scrolled(step);
			}
		}
	}

	RowLayout {
		id: row
		anchors.centerIn: parent
		spacing: Theme.spacing - 2
	}
}
