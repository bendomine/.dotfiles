//@ pragma UseQApplication
//@ pragma IconTheme Papirus
import Quickshell // for PanelWindow
import Quickshell.Hyprland
import Quickshell.Bluetooth
import QtQuick // for Text
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "."
import "./shared"
import "./status"

ShellRoot {
    id: root
    readonly property var theme: Theme
    StatusBar {}
    /* Edges {} */

}