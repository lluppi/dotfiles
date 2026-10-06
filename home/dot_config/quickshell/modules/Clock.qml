import QtQuick

Item {
    id: root
    implicitWidth: Theme.barWidth
    implicitHeight: col.implicitHeight + 2

    function hh() { return Qt.formatDateTime(new Date(), "HH") }
    function mm() { return Qt.formatDateTime(new Date(), "mm") }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: { hhText.text = root.hh(); mmText.text = root.mm() }
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 0

        Text {
            id: hhText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hh()
            color: Theme.fgActive
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.letterSpacing: Theme.letterSpacing
            antialiasing: Theme.antialiasing
        }

        Text {
            id: mmText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.mm()
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            font.letterSpacing: Theme.letterSpacing
            antialiasing: Theme.antialiasing
        }
    }
}
