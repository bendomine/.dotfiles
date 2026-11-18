import QtQuick
import QtQuick.Layouts
import ".."

// Thin horizontal divider for popup layouts.
Rectangle {
	Layout.fillWidth: true
	Layout.topMargin: Theme.spacingSmall
	Layout.bottomMargin: Theme.spacingSmall
	implicitHeight: 1
	color: Theme.alpha(Theme.border, 0.8)
}
