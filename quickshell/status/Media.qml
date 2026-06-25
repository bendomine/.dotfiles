import QtQuick
import Quickshell.Services.Mpris

Text {
    text: "Currently playing: " + Mpris.players.values[0].trackTitle + " by " + Mpris.players.values[0].trackArtist
}