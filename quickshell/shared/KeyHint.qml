import QtQuick
import ".."

// Outlined single-key shortcut hint, shown at the right of a MenuRow whose popup
// activates it on that key (see Launcher's wallpaper chooser).
//   MenuRow { text: "Dark"; KeyHint { label: "d" } }
Rectangle {
	id: root
	property string label: ""
	property color tint: Theme.foregroundMuted
	implicitWidth: Math.max(implicitHeight, hintText.implicitWidth + 10)
	implicitHeight: 20
	radius: 6
	color: "transparent"
	border.width: 1
	border.color: Theme.alpha(root.tint, 0.6)

	StyledText {
		id: hintText
		anchors.centerIn: parent
		text: root.label
		font.pixelSize: Theme.fontSizeSmall
		color: root.tint
	}
}
