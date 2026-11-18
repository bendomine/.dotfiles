// Toggle.qml
import QtQuick
import QtQuick.Layouts
import ".."

// Themed on/off switch. Controlled: it never changes `checked` itself, it emits
// toggled(value) with the requested state, so `checked` can stay bound:
//   Toggle { checked: adapter.enabled; onToggled: value => adapter.enabled = value }
// Keyboard (BarPopup nav protocol): Space/Return toggles when focused.
Item {
	id: root
	property bool checked: false
	property bool navigable: true
	property bool keyFocused: false
	signal toggled(bool value)

	function activate() {
		toggled(!checked);
	}

	implicitWidth: 38
	implicitHeight: 22
	Layout.alignment: Qt.AlignVCenter
	opacity: enabled ? 1 : 0.4

	Rectangle {
		id: track
		anchors.fill: parent
		radius: height / 2
		color: root.checked ? Theme.accent : Theme.surfaceVariant
		border.width: 1
		border.color: root.keyFocused ? Theme.accent : (root.checked ? Theme.accent : Theme.border)
		Behavior on color { ColorAnimation { duration: Theme.animFast } }

		Rectangle {
			id: knob
			width: track.height - 6
			height: width
			radius: width / 2
			anchors.verticalCenter: parent.verticalCenter
			x: root.checked ? track.width - width - 3 : 3
			color: root.checked ? Theme.onAccent : Theme.foregroundMuted
			scale: mouse.pressed ? 0.85 : 1
			Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
			Behavior on scale { NumberAnimation { duration: Theme.animFast } }
		}
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onClicked: root.activate()
	}
}
