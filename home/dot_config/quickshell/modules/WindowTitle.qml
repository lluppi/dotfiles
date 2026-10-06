import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    implicitWidth: Theme.barWidth
    // Height hugs the rotated title's run length (its horizontal extent before
    // rotation), capped so a giant title can't shove the workspaces down.
    implicitHeight: Math.min(titleMetrics.width, maxTitleRun)

    property string windowTitle: ""
    property int maxTitleRun: 320

    // titles that wine / other phantom windows produce briefly and which would
    // otherwise flash through the bar — skip the update entirely so the
    // previous real title stays visible.
    readonly property var ignoredTitles: ["Default IME", "MSCTFIME UI"]

    function updateTitle(t) {
        if (!t || t.length === 0) return
        if (root.ignoredTitles.indexOf(t) !== -1) return
        root.windowTitle = t.length > 72 ? t.substring(0, 72) : t
    }

    // Listen for Hyprland activewindow events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                // data format: "class,title"
                var idx = event.data.indexOf(",")
                if (idx !== -1)
                    root.updateTitle(event.data.substring(idx + 1))
            } else if (event.name === "windowtitlev2") {
                // data format: "address,title"
                var idx2 = event.data.indexOf(",")
                if (idx2 !== -1)
                    root.updateTitle(event.data.substring(idx2 + 1))
            }
        }
    }

    // Measures the title's natural width to size the (rotated) slot — decoupled
    // from the displayed Text so there's no binding loop with its elide width.
    TextMetrics {
        id: titleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.letterSpacing: Theme.letterSpacing
        text: root.windowTitle
    }

    // Rotated 90° so the title runs vertically down the bar. The Text's own
    // width (its horizontal axis pre-rotation) becomes the vertical run after
    // rotation, so binding it to root.height makes long titles elide to fit.
    Text {
        id: titleText
        anchors.centerIn: parent
        rotation: 90
        width: root.height
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: root.windowTitle
        color: Theme.fgActive
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.letterSpacing: Theme.letterSpacing
        antialiasing: Theme.antialiasing
    }
}
