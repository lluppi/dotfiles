import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    spacing: 0

    Repeater {
        model: [1, 2, 3, 4]

        Rectangle {
            required property int modelData
            property int wsId: modelData
            property bool isActive: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
            property bool hovered: false
            property var wsObject: {
                for (const ws of Hyprland.workspaces.values) {
                    if (ws.id === wsId) return ws;
                }
                return null;
            }
            property bool hasWindows: wsObject !== null && wsObject.toplevels.values.length > 0

            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: hovered ? Theme.hoverBg : "transparent"

            Text {
                anchors.centerIn: parent
                text: isActive || hasWindows ? "●" : "○"
                color: isActive ? Theme.fgActive : hasWindows ? Theme.activeBg : "#444455"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                antialiasing: Theme.antialiasing
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
                onEntered: parent.hovered = true
                onExited: parent.hovered = false
            }
        }
    }
}
