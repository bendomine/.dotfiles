import Quickshell.Services.UPower
import QtQuick

Text {
    text: "Battery: " + (UPower.displayDevice.percentage * 100).toFixed() + "%"
}