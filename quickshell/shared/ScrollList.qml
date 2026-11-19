import QtQuick
import QtQuick.Layouts
import ".."

// Vertical list that grows with its content up to `maxHeight`, then scrolls.
// BarPopup keyboard navigation scrolls the focused row into view automatically.
//   ScrollList { maxHeight: 320; MenuRow { … } Repeater { … } }
// Scrolling is handled here rather than by Flickable's kinetic flicking (which felt
// laggy with a mouse wheel and made rows draggable): wheel notches step a fixed
// distance with a short ease, touchpads scroll 1:1, and the scrollbar can be
// dragged or clicked.
Flickable {
	id: root
	default property alias content: column.data
	property real maxHeight: 320
	property alias spacing: column.spacing
	property real wheelStep: 60 // px per mouse-wheel notch
	// Touchpad deltas arrive already scaled by Hyprland's touchpad scroll_factor (0.4),
	// which makes 1:1 scrolling feel sluggish in short lists; amplify them here.
	property real touchpadSpeed: 3

	readonly property bool scrollable: contentHeight > height
	readonly property real maxContentY: Math.max(0, contentHeight - height)
	// Where the list is heading (end of a running animation), for chained scrolls.
	readonly property real targetY: scrollAnim.running ? scrollAnim.to : contentY

	function scrollTo(y, animate) {
		y = Math.max(0, Math.min(maxContentY, y));
		scrollAnim.stop();
		if (animate === false || Math.abs(y - contentY) < 1) {
			contentY = y;
			return;
		}
		scrollAnim.from = contentY;
		scrollAnim.to = y;
		scrollAnim.start();
	}

	Layout.fillWidth: true
	Layout.preferredHeight: implicitHeight
	implicitHeight: Math.min(column.implicitHeight, maxHeight)
	contentWidth: width
	contentHeight: column.implicitHeight
	clip: true
	// Interactive so Flickable still scrolls natively if a wheel event ever bypasses the
	// WheelHandler below, but with no buttons accepted so rows can't be dragged.
	interactive: true
	acceptedButtons: Qt.NoButton
	boundsBehavior: Flickable.StopAtBounds

	// Content shrinking (e.g. a device list emptying) must not leave us past the end.
	onMaxContentYChanged: if (contentY > maxContentY) scrollTo(maxContentY, false)

	NumberAnimation {
		id: scrollAnim
		target: root
		property: "contentY"
		duration: Theme.animFast
		easing.type: Easing.OutCubic
	}

	WheelHandler {
		target: null
		enabled: root.scrollable
		// WheelHandler defaults to mouse only; touchpad scrolling is a separate device type.
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: event => {
			const touchpad = event.device && event.device.type === PointerDevice.TouchPad;
			if (touchpad || event.pixelDelta.y !== 0) {
				// Prefer pixel deltas; fall back to angle (1/8 degree units) if a touchpad sends none.
				const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 8;
				root.scrollTo(root.targetY - delta * root.touchpadSpeed, false);
			} else {
				root.scrollTo(root.targetY - event.angleDelta.y / 120 * root.wheelStep, true);
			}
		}
	}

	ColumnLayout {
		id: column
		width: root.width - (root.scrollable ? 10 : 0)
		spacing: 2
	}

	// Scrollbar: thin indicator that widens on hover; drag the handle or click the track.
	Item {
		id: track
		parent: root
		visible: root.scrollable
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.bottom: parent.bottom
		width: 8

		Rectangle {
			id: handle
			readonly property bool hot: trackArea.containsMouse || trackArea.pressed
			anchors.right: parent.right
			width: hot ? 6 : 3
			radius: width / 2
			height: Math.max(16, root.height * root.height / Math.max(1, root.contentHeight))
			y: root.maxContentY > 0 ? root.contentY / root.maxContentY * (track.height - height) : 0
			color: Theme.alpha(Theme.foregroundMuted, trackArea.pressed ? 0.85 : (hot || scrollAnim.running ? 0.6 : 0.3))
			Behavior on width { NumberAnimation { duration: Theme.animFast } }
			Behavior on color { ColorAnimation { duration: Theme.animFast } }
		}

		MouseArea {
			id: trackArea
			property real grabOffset: 0

			function dragTo(mouseY) {
				const range = track.height - handle.height;
				if (range > 0)
					root.scrollTo((mouseY - grabOffset) / range * root.maxContentY, false);
			}

			anchors.fill: parent
			hoverEnabled: true
			preventStealing: true
			onPressed: mouse => {
				const onHandle = mouse.y >= handle.y && mouse.y <= handle.y + handle.height;
				// Grab the handle where it was pressed; a track click centers the handle there.
				grabOffset = onHandle ? mouse.y - handle.y : handle.height / 2;
				if (!onHandle)
					dragTo(mouse.y);
			}
			onPositionChanged: mouse => {
				if (pressed)
					dragTo(mouse.y);
			}
		}
	}
}
