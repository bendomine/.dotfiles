import QtQuick
import Quickshell.Services.Mpris

Text {
    property color fontColor: "black"
    text: "Currently playing: " + Mpris.players.values[0].trackTitle + " by " + Mpris.players.values[0].trackArtist
    color: fontColor
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}