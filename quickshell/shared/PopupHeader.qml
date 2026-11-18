import QtQuick
import QtQuick.Layouts
import ".."

// Popup title row: accent icon badge, title, optional subtitle and trailing widgets.
//   PopupHeader { icon: "…"; title: "Bluetooth"; subtitle: "On"; Toggle { … } }
RowLayout {
	id: root
	property string icon: ""
	property string title: ""
	property string subtitle: ""
	default property alias trailing: trailingRow.data

	Layout.fillWidth: true
	Layout.bottomMargin: Theme.spacingSmall
	spacing: Theme.spacing

	Rectangle {
		visible: root.icon !== ""
		implicitWidth: 34
		implicitHeight: 34
		radius: Theme.radiusSmall
		color: Theme.alpha(Theme.accent, 0.18)
		Glyph {
			anchors.centerIn: parent
			text: root.icon
			font.pixelSize: Theme.iconSizeLarge
			color: Theme.accent
		}
	}

	ColumnLayout {
		Layout.fillWidth: true
		spacing: 0
		StyledText {
			Layout.fillWidth: true
			text: root.title
			font.pixelSize: Theme.fontSizeLarge
			font.weight: Font.Bold
			elide: Text.ElideRight
		}
		StyledText {
			Layout.fillWidth: true
			visible: root.subtitle !== ""
			text: root.subtitle
			font.pixelSize: Theme.fontSizeSmall
			color: Theme.foregroundMuted
			elide: Text.ElideRight
		}
	}

	RowLayout {
		id: trailingRow
		spacing: Theme.spacingSmall
	}
}
