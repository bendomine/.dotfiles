import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

PanelWindow {
    id: rootWindow
    anchors.top: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: ExclusionMode.Ignore

    /* mask: Region{} */
    /* color: "transpare" */
    /* ClippingRectangle { */
    /* 	anchors.fill: parent */
    /* 	color: "red" */
    /* 	radius: 10 */
    /* } */

    color: "transparent"

    mask: Region {}


    ClippingRectangle {
	id: screenCorners
	anchors.fill: parent
	/* color: "black" */
	color: "#5AFFFFFF"
	visible: false
	antialiasing: true
    }
    ClippingRectangle {
	id: roundedHole
	anchors.fill: parent
	radius: 20
	color: "black"
	layer.enabled: true
	visible: false
	antialiasing: true
    }

    MultiEffect {
	anchors.fill: parent
	source: screenCorners
	maskEnabled: true
	maskSource: roundedHole
	maskInverted: true
    }

}