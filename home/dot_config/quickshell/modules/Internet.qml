import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.barWidth
    implicitHeight: stack.implicitHeight

    property string icon:      "󰖩"
    property string iface:     "…"
    property color  iconColor: Theme.fg

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Process {
        id: netProc
        // get the interface used for default route, if any
        command: ["sh", "-c",
            "ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i==\"dev\") print $(i+1); exit}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var iface = text.trim()
                if (iface.length === 0) {
                    root.icon      = "󰖪"
                    root.iface     = "down"
                    root.iconColor = "#FC5C65"
                } else if (iface.startsWith("w")) {
                    root.icon      = "󰖩"
                    root.iface     = iface
                    root.iconColor = Theme.fg
                } else {
                    root.icon      = "󰈀"
                    root.iface     = iface
                    root.iconColor = Theme.fg
                }
            }
        }
    }

    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            antialiasing: Theme.antialiasing
        }

        /* Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: Theme.barWidth - 4
            elide: Text.ElideRight
            text: root.iface
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
            antialiasing: Theme.antialiasing
        } */
    }
}
