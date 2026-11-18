import QtQuick
import ".."

// Text with the theme font and foreground color.
Text {
	font.family: Theme.fontFamily
	font.pixelSize: Theme.fontSize
	color: Theme.foreground
	verticalAlignment: Text.AlignVCenter
	Behavior on color { ColorAnimation { duration: Theme.animFast } }
}
