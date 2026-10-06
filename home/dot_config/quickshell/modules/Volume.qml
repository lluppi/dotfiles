import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: Theme.barWidth
    implicitHeight: stack.implicitHeight

    property var    screen:      null
    property string displayPct:  "…"
    property string displayIcon: "󰕾"
    property bool   popupOpen:   false
    property int    volumeValue: 0
    property bool   isMuted:     false
    property var    sinks:       []
    property string defaultSink: ""

    TextMetrics {
        id: numMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: "100%"
    }

    function icon(pct, muted) {
        if (muted || pct === 0) return "󰖁"
        if (pct < 40)           return "󰕿"
        if (pct < 70)           return "󰖀"
        return "󰕾"
    }

    function fetch() { volProc.running = true }

    function fetchSinks() {
        sinksProc.running    = true
        defaultSinkProc.running = true
    }

    onPopupOpenChanged: { if (popupOpen) fetchSinks() }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.fetch()
    }

    Timer {
        id: sliderDebounce
        interval: 80
        repeat: false
        property int pendingVol: -1
        onTriggered: {
            if (pendingVol >= 0 && !setVolProc.running) {
                setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pendingVol + "%"]
                setVolProc.running = true
                pendingVol = -1
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var line  = text.trim()
                var muted = line.indexOf("MUTED") !== -1
                var match = line.match(/[\d.]+/)
                if (match) {
                    var pct = Math.round(parseFloat(match[0]) * 100)
                    root.isMuted     = muted
                    root.volumeValue = pct
                    root.displayIcon = root.icon(pct, muted)
                    root.displayPct  = pct + "%"
                }
            }
        }
    }

    Process {
        id: sinksProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.sinks = data.map(function(s) {
                        return { name: s.name, description: s.description }
                    })
                } catch(e) {}
            }
        }
    }

    Process {
        id: defaultSinkProc
        command: ["pactl", "get-default-sink"]
        stdout: StdioCollector {
            onStreamFinished: { root.defaultSink = text.trim() }
        }
    }

    Process {
        id: cmdProc
        onRunningChanged: if (!running) root.fetch()
    }

    Process {
        id: setVolProc
        onRunningChanged: if (!running) root.fetch()
    }

    Process {
        id: sinkSwitchProc
        onRunningChanged: if (!running) { root.fetch(); root.fetchSinks() }
    }

    // ── Bar click handler ────────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.popupOpen = !root.popupOpen
            } else {
                cmdProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                cmdProc.running = true
            }
        }
        onWheel: (wheel) => {
            var cmd = wheel.angleDelta.y > 0
                ? "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
                : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            cmdProc.command = ["sh", "-c", cmd]
            cmdProc.running = true
        }
    }

    // ── Popup + backdrop (single window) ────────────────────────────────────

    PanelWindow {
        screen: root.screen ?? Quickshell.screens[0]
        visible: root.popupOpen && root.screen !== null
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        // Outside click closes the popup
        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupBg
            width: 280
            height: popupCol.implicitHeight + 28
            x: parent.width - Theme.barWidth - width - 10
            y: {
                let _track = root.y
                if (!root.screen) return 40
                let globalCenterY = root.mapToGlobal(0, root.height / 2).y
                let localCenterY  = globalCenterY - (root.screen.y || 0)
                return Math.max(8, Math.min(parent.height - height, localCenterY - height / 2))
            }
            color: Theme.bg
            radius: 8
            border.color: Theme.border
            border.width: 1

            // Absorb clicks so they don't reach the backdrop MouseArea
            MouseArea { anchors.fill: parent }

            Column {
                id: popupCol
                anchors {
                    top:         parent.top
                    left:        parent.left
                    right:       parent.right
                    topMargin:   14
                    leftMargin:  14
                    rightMargin: 14
                }
                spacing: 10

                // ── Volume row ─────────────────────────────────────────────
                Row {
                    width: parent.width
                    height: 28
                    spacing: 8

                    // Mute icon (clickable)
                    Text {
                        id: muteIcon
                        width: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayIcon
                        color: root.isMuted ? "#ff6e6e" : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                cmdProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                cmdProc.running = true
                            }
                        }
                    }

                    // Slider
                    Item {
                        id: sliderItem
                        width: parent.width - muteIcon.width - pctLabel.width - 16
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        property real frac: Math.max(0, Math.min(1, root.volumeValue / 100.0))

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Rectangle {
                                width: track.width * sliderItem.frac
                                height: track.height
                                radius: track.radius
                                color: Theme.fg
                            }
                        }

                        Rectangle {
                            x: sliderItem.frac * (sliderItem.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed:         (m) => seek(m.x)
                            onPositionChanged: (m) => { if (pressed) seek(m.x) }

                            function seek(x) {
                                var pct = Math.max(0, Math.min(100, Math.round(x / sliderItem.width * 100)))
                                root.volumeValue = pct
                                root.displayPct  = pct + "%"
                                root.displayIcon = root.icon(pct, root.isMuted)
                                sliderDebounce.pendingVol = pct
                                sliderDebounce.restart()
                            }
                        }
                    }

                    // Percentage
                    Text {
                        id: pctLabel
                        width: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayPct
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // ── Separator ──────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                // ── Output device label ────────────────────────────────────
                Text {
                    text: "output device"
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.4)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }

                // ── Sink list ──────────────────────────────────────────────
                Repeater {
                    model: root.sinks

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width:  popupCol.width
                        height: 24

                        property bool active: modelData.name === root.defaultSink

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin:  -4
                            anchors.rightMargin: -4
                            radius: 5
                            color: active ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            spacing: 8

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: active ? Theme.fg : "transparent"
                                border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, active ? 1.0 : 0.4)
                                border.width: 1.5
                            }

                            Text {
                                text: modelData.description
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, active ? 1.0 : 0.5)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                width: popupCol.width - 15 - 8
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                sinkSwitchProc.command = ["pactl", "set-default-sink", modelData.name]
                                sinkSwitchProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Bar display ──────────────────────────────────────────────────────────

    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 1

        Text {
            id: iconText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayIcon
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
