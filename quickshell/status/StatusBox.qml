import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    default property alias content: row.data
    property color bgColor: "white"
    color: bgColor
    radius: 100
    implicitHeight: 22.5
    property real margin: 5
    implicitWidth: row.implicitWidth + margin * 2
    
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5
    }
}
