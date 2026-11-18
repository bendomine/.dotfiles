import QtQuick
import QtQuick.Layouts
import ".."

// Themed horizontal slider. Controlled: it never writes `value`; dragging, wheel
// and h/l (BarPopup nav protocol: decrease()/increase()) emit moved(value) with the
// requested value, so `value` can stay bound to its source:
//   Slider { value: sink.audio.volume; onMoved: v => sink.audio.volume = v }
// While dragging, the knob follows the pointer even if the source lags behind.
Item {
	id: root
	property real value: 0
	property real from: 0
	property real to: 1
	property real stepSize: 0.05
	property color accentColor: Theme.accent
	property bool navigable: true
	property bool keyFocused: false
	readonly property bool pressed: mouse.pressed
	readonly property bool hovered: mouse.containsMouse
	readonly property real visualValue: pressed ? d.dragValue : value
	readonly property real position: to === from ? 0 : Math.max(0, Math.min(1, (visualValue - from) / (to - from)))
	signal moved(real value)

	function clamp(v) {
		return Math.max(Math.min(from, to), Math.min(Math.max(from, to), v));
	}
	function decrease() {
		moved(clamp(value - stepSize));
	}
	function increase() {
		moved(clamp(value + stepSize));
	}

	implicitWidth: 160
	implicitHeight: 20
	Layout.fillWidth: true
	Layout.alignment: Qt.AlignVCenter
	opacity: enabled ? 1 : 0.4

	QtObject {
		id: d
		property real dragValue: 0
		function valueAt(x) {
			const usable = root.width - knob.width;
			const t = usable > 0 ? Math.max(0, Math.min(1, (x - knob.width / 2) / usable)) : 0;
			return root.from + t * (root.to - root.from);
		}
	}

	Rectangle {
		id: track
		anchors.verticalCenter: parent.verticalCenter
		width: parent.width
		height: 6
		radius: height / 2
		color: Theme.surfaceVariant

		Rectangle {
			height: parent.height
			radius: parent.radius
			width: knob.x + knob.width / 2
			color: root.accentColor
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}
	}

	Rectangle {
		id: knob
		width: 16
		height: 16
		radius: 8
		anchors.verticalCenter: parent.verticalCenter
		x: root.position * (root.width - width)
		color: root.accentColor
		border.width: 3
		border.color: Theme.surface
		scale: root.pressed ? 1.15 : (root.hovered || root.keyFocused ? 1.08 : 1)
		Behavior on scale { NumberAnimation { duration: Theme.animFast } }
		Behavior on x {
			enabled: !root.pressed
			NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
		}

		// Focus ring
		Rectangle {
			anchors.centerIn: parent
			width: parent.width + 8
			height: width
			radius: width / 2
			color: "transparent"
			border.width: 2
			border.color: Theme.alpha(root.accentColor, 0.5)
			opacity: root.keyFocused ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
		}
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		anchors.topMargin: -4
		anchors.bottomMargin: -4
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		preventStealing: true
		onPressed: event => {
			d.dragValue = d.valueAt(event.x);
			root.moved(d.dragValue);
		}
		onPositionChanged: event => {
			if (!pressed)
				return;
			d.dragValue = d.valueAt(event.x);
			root.moved(d.dragValue);
		}
		onWheel: event => {
			if (event.angleDelta.y > 0)
				root.increase();
			else if (event.angleDelta.y < 0)
				root.decrease();
		}
	}
}
