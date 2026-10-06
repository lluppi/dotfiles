import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.barWidth
    implicitHeight: stack.implicitHeight

    property string displayPct: "…"

    TextMetrics {
        id: numMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.letterSpacing: Theme.letterSpacing
        text: "100%"
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }

    Process {
        id: memProc
        command: ["sh", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%d%%\", int((t-a)/t*100)}' /proc/meminfo"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t.length > 0) root.displayPct = t
            }
        }
    }

    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 1

        Text {
            id: iconText
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰘚"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            antialiasing: Theme.antialiasing
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.displayPct
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            antialiasing: Theme.antialiasing
        }
    }
}
