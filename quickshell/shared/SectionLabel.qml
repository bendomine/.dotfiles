import QtQuick
import QtQuick.Layouts
import ".."

// Small muted caption above a group of rows.
StyledText {
	Layout.fillWidth: true
	Layout.topMargin: Theme.spacingSmall
	Layout.leftMargin: Theme.spacing
	font.pixelSize: Theme.fontSizeSmall
	font.weight: Font.DemiBold
	font.letterSpacing: 0.6
	font.capitalization: Font.AllUppercase
	color: Theme.foregroundMuted
	elide: Text.ElideRight
}
