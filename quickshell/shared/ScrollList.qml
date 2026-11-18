import QtQuick
import QtQuick.Layouts
import ".."

// Vertical list that grows with its content up to `maxHeight`, then scrolls.
// BarPopup keyboard navigation scrolls the focused row into view automatically.
//   ScrollList { maxHeight: 320; MenuRow { … } Repeater { … } }
Flickable {
	id: root
	default property alias content: column.data
	property real maxHeight: 320
	property alias spacing: column.spacing

	Layout.fillWidth: true
	Layout.preferredHeight: implicitHeight
	implicitHeight: Math.min(column.implicitHeight, maxHeight)
	contentWidth: width
	contentHeight: column.implicitHeight
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	ColumnLayout {
		id: column
		width: root.width - (root.contentHeight > root.height ? 7 : 0)
		spacing: 2
	}

	// Scroll indicator
	Rectangle {
		parent: root
		visible: root.contentHeight > root.height
		anchors.right: parent.right
		width: 3
		radius: 1.5
		y: root.visibleArea.yPosition * root.height
		height: Math.max(16, root.visibleArea.heightRatio * root.height)
		color: Theme.alpha(Theme.foregroundMuted, root.moving ? 0.6 : 0.3)
		Behavior on color { ColorAnimation { duration: Theme.animNormal } }
	}
}
