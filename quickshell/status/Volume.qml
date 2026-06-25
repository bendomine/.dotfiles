import QtQuick
import Quickshell.Services.Pipewire

Text {
    PwObjectTracker {
	objects: [Pipewire.defaultAudioSink]
    }
    property real volume: (Pipewire.defaultAudioSink.audio.volume * 100).toFixed()
    text: "Volume: " + volume + "%"
}