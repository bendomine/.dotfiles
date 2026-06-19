import Quickshell // for PanelWindow
import Quickshell.Hyprland
import Quickshell.Bluetooth
import QtQuick // for Text
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "."
import "./shared"
import "./bluetooth"
import "./status"

ShellRoot {
    id: root
    readonly property var theme: Theme
    /* BluetoothPanel {} */
    StatusBar {}

    /* FloatingWindow { */
    /* 	ColumnLayout { */
    /* 	    anchors.centerIn: parent */
    /* 	    spacing: 10 */
    /* 	    Toggle { */
    /* 		checked: Bluetooth.defaultAdapter.discovering */
    /* 		onToggled: { */
    /* 		    Bluetooth.defaultAdapter.discovering = checked */
    /* 		} */
    /* 		text: "Toggle discovery" */
    /* 	    } */
    /* 	    Column { */
    /* 		/\* anchors.centerIn: parent *\/ */
    /* 		spacing: 10 */

    /* 		Repeater { */
    /* 		    model: Bluetooth.defaultAdapter.devices */

    /* 		    delegate: Device { */
    /* 			readonly property bool isNameless: { */
    /* 			    const macAddressRegex = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/i; */
    /* 			    return !modelData.name || modelData.name.trim() === "" || macAddressRegex.test(modelData.name) */
    /* 			} */
    /* 			visible: !isNameless */
    /* 			deviceName: modelData.name */
    /* 			/\* deviceName: modelData.address *\/ */
    /* 			iconName: modelData.icon */
    /* 		    } */
    /* 		} */
    /* 	    } */
    /* 	} */
    /* } */
}