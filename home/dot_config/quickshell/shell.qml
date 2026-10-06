import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "modules"

ShellRoot {
    Notifications {}

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top:    true
                bottom: true
                right:  true
            }

            implicitWidth: Theme.barWidth
            color: "#e61e1e26"

            // Workspaces — anchored to the dead vertical centre of the bar,
            // independent of the top/bottom column flow. Full bar width so the
            // dots stay horizontally centred.
            Workspaces {
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                // Top: clock (HH / MM)
                Clock {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                }

                // Window title — rotated 90°, sits below the clock
                WindowTitle {
                    Layout.alignment: Qt.AlignHCenter
                }

                // Flexible spacer fills the middle (workspaces float here, centred)
                // and pushes the status cluster to the bottom
                Item { Layout.fillHeight: true }

                // Bottom: status cluster
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    spacing: 6

                    Tray     { Layout.alignment: Qt.AlignHCenter }
                    Internet { Layout.alignment: Qt.AlignHCenter }
                    Memory   { Layout.alignment: Qt.AlignHCenter }
                    Cpu      { Layout.alignment: Qt.AlignHCenter }
                    Volume   { Layout.alignment: Qt.AlignHCenter; screen: modelData }
                }
            }
        }
    }
}
