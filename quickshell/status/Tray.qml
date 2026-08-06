import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PopupWindow {
    id: root 
    required property Item anchorPoint
    required property real iconSize
    property real xOffset: iconSize - 3
    property real yOffset: 0
    property real dWidth: 150
    property real dHeight: 150
    property real animDuration: 500
    property real animProgress: windowActive ? 1.0 : -0.1
    property bool displayWindow: animProgress > -0.1
    property bool windowActive
    property color bgColor: "white"
    property color fontColor: "black"
    property list<string> menuIds: [
	"Antigravity_status_icon_1",
	"spotify-client",
	"steam"
    ]

    onDisplayWindowChanged: Bluetooth.defaultAdapter.discovering = displayWindow

    Connections {
	target: anchorPoint
	function onXChanged() {
	    if (!root.displayWindow) {
		root.visible = false
		Qt.callLater(() => root.visible = true)
	    }
	}
    }
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.item: anchorPoint
    anchor.rect.x: xOffset
    anchor.rect.y: yOffset
    visible: true
    color: "transparent"

    implicitWidth: displayWindow ? dWidth : iconSize + 2
    implicitHeight: displayWindow ? dHeight : iconSize + 2

    function mix(x, y, a, b) {
	a /= b;
	a = Math.min(Math.max(a, 0.0), 1.0);
	return x * (1 - a) + y * a;
    }

    Behavior on animProgress { NumberAnimation {
	duration: animDuration
	easing.type: Easing.OutQuart
    } }

    Rectangle {
	anchors.right: parent.right
	HoverHandler {
	    id: displayHandler
	    onHoveredChanged: {
		if (hovered) windowActive = true;
		else if (!menuAnchor.visible) windowActive = false;
	    }
	}
	clip: true
	implicitWidth: mix(iconSize, dWidth, animProgress, 0.4)
	implicitHeight: mix(iconSize, dHeight, animProgress - 0.4, 0.6)
	color: bgColor
	radius: iconSize / 2

	Behavior on color { ColorAnimation { duration: animDuration * 0.67 } }

	ColumnLayout {
	    anchors.fill: parent
	    spacing: 1
	    Layout.fillWidth: true
	    Layout.preferredHeight: title.implicitHeight
	    RowLayout {
		layoutDirection: Qt.RightToLeft
		id: title
		anchors.right: parent.right
		Layout.fillWidth: true
		/* implicitWidth: 200 */
		Rectangle {
		    color: "transparent"
		    Layout.preferredWidth: iconSize
		    Layout.preferredHeight: iconSize
		    Text {
			anchors.centerIn: parent
			text: "󱊖"
			font.pointSize: 12
			color: root.fontColor
		    }
		    /* Layout.alignment: Qt.AlignRight */
		}
		Item {
		    Layout.fillWidth: true
		}
		Text {
		    text: "System Tray"
		    color: root.fontColor
		    Layout.alignment: Qt.AlignLeft
		    Layout.leftMargin: 5
		}
	    }

	    Rectangle {
		Layout.alignment: Qt.AlignHCenter
		Layout.maximumWidth: parent.width - 10
		Layout.fillWidth: true
		color: "lightgrey"
		implicitHeight: 2
	    }

	    ScrollView {
		id: scrollView
		Layout.fillWidth: true
		Layout.fillHeight: true
		Layout.alignment: Qt.AlignHCenter
		Layout.maximumWidth: parent.width - 10
		clip: true
		ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

		GridLayout {
		    width: scrollView.availableWidth
		    rows: 5
		    columns: 5
		    QsMenuAnchor {
			id: menuAnchor
			anchor.window: root
		    }
		    Repeater {
			model: SystemTray.items
			delegate: Rectangle {
			    id: child
			    implicitWidth: trayItem.implicitWidth
			    implicitHeight: trayItem.implicitHeight
			    color: "red"
			    MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				acceptedButtons: Qt.LeftButton | Qt.RightButton
				onClicked: (mouse) => {
				    if (modelData.onlyMenu || (modelData.hasMenu && mouse.button == Qt.RightButton) || menuIds.includes(modelData.id)) {
					var mapped = child.mapToItem(null, mouse.x, mouse.y)
					menuAnchor.anchor.rect.x = mapped.x
					menuAnchor.anchor.rect.y = mapped.y
					menuAnchor.menu = modelData.menu
					menuAnchor.open()
				    } else {
					modelData.activate()
				    }
				}
			    }
			    IconImage {
				id: trayItem
				source: modelData.icon.toString().replace("-symbolic", "")
				implicitSize: 20
				anchors.centerIn: parent
			    }
			}
		    }
		}
	    }
	}
    }
    GlobalShortcut {
	description: "Toggles the system tray."
	name: "toggle-tray"
	onPressed: windowActive = !windowActive;
    }
    /* Shortcut { */
    /* 	sequence: "j" */
    /* 	onActivated: { */
    /* 	    devicesContainer.focusIdx ++; */
    /* 	    if (devicesContainer.focusIdx >= connectedDevices.count + knownDevices.count + otherDevices.count) */
    /* 		devicesContainer.focusIdx = 0; */
    /* 	} */
    /* } */
    /* Shortcut { */
    /* 	sequence: "k" */
    /* 	onActivated: { */
    /* 	    devicesContainer.focusIdx --; */
    /* 	    if (devicesContainer.focusIdx < 0) */
    /* 		devicesContainer.focusIdx = connectedDevices.count + knownDevices.count + otherDevices.count - 1 */
    /* 	} */
    /* } */
    /* Shortcut { */
    /* 	sequences: ["Space", "Return"] */
    /* 	onActivated: { */
    /* 	    if (devicesContainer.focusIdx < 0) return; */
    /* 	    if (devicesContainer.focusIdx < connectedDevices.count) */
    /* 		connectedDevices.itemAt(devicesContainer.focusIdx).action(); */
    /* 	    else if (devicesContainer.focusIdx < knownDevices.count + connectedDevices.count) */
    /* 		knownDevices.itemAt(devicesContainer.focusIdx - connectedDevices.count).action(); */
    /* 	    else otherDevices.itemAt(devicesContainer.focusIdx - connectedDevices.count - knownDevices.count).action(); */
    /* 	} */
    /* } */
    /* onWindowActiveChanged: { */
    /* 	grab.active = windowActive; */
    /* 	devicesContainer.focusIdx = -1; */
    /* } */
    /* HyprlandFocusGrab { */
    /* 	id: grab */
    /* 	windows: [ root ] */
    /* 	active: false */
    /* } */
}