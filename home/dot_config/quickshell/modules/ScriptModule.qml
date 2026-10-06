import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitHeight: Theme.barHeight
    implicitWidth: label.implicitWidth + Theme.modulePadding
    visible: root.displayText.length > 0

    property string script: ""
    property int interval: 5000
    property string displayText: ""

    Timer {
        interval: root.interval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                var t = collector.text.trim()
                if (t.length > 0) root.displayText = t
            }
        }
    }

    Process {
        id: clickProc
        command: ["sh", "-c", root.script]
        onRunningChanged: if (!running) fetchProc.running = true
    }

    function runWithButton(btn) {
        clickProc.environment = { "BLOCK_BUTTON": btn, "TERMINAL": "ghostty" }
        clickProc.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        height: Theme.barHeight
        verticalAlignment: Text.AlignVCenter
        text: root.displayText
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
        antialiasing: Theme.antialiasing
        font.kerning: Theme.kerning
        font.preferShaping: Theme.preferShaping
        renderType: Theme.renderType
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) root.runWithButton("1")
            else if (mouse.button === Qt.MiddleButton) root.runWithButton("2")
            else root.runWithButton("3")
        }
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) root.runWithButton("4")
            else root.runWithButton("5")
        }
        hoverEnabled: true
    }
}
