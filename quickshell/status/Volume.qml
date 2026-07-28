import QtQuick
import Quickshell.Services.Pipewire

Text {
    PwObjectTracker {
	objects: [Pipewire.defaultAudioSink]
    }
    property real volume: (Pipewire.defaultAudioSink.audio.volume * 100).toFixed()
    property bool muted: Pipewire.defaultAudioSink.audio.muted
    property string icon: muted ? "󰝟" : (volume == 0 ? "" : (volume < 50 ? "󰖀" : "󰕾"))
    property color fontColor: "black"
    text: icon + " " + volume + "%"
    color: fontColor
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}