import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.barWidth
    implicitHeight: stack.implicitHeight

    property var prevIdle:  -1
    property var prevTotal: -1
    property string displayPct: "…"

    TextMetrics {
        id: numMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.letterSpacing: Theme.letterSpacing
        text: "100%"
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                var user    = parseInt(parts[1])
                var nice    = parseInt(parts[2])
                var system  = parseInt(parts[3])
                var idle    = parseInt(parts[4])
                var iowait  = parseInt(parts[5])
                var irq     = parseInt(parts[6])
                var softirq = parseInt(parts[7])

                var totalIdle  = idle + iowait
                var total      = user + nice + system + idle + iowait + irq + softirq

                if (root.prevTotal >= 0) {
                    var diffIdle  = totalIdle - root.prevIdle
                    var diffTotal = total     - root.prevTotal
                    var pct = diffTotal > 0 ? Math.round((1 - diffIdle / diffTotal) * 100) : 0
                    root.displayPct = pct + "%"
                }

                root.prevIdle  = totalIdle
                root.prevTotal = total
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
            text: "\uDB83\uDEE0"
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
