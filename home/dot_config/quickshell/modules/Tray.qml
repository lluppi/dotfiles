import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ColumnLayout {
    spacing: 8

    Repeater {
        model: SystemTray.items

        Item {
            required property SystemTrayItem modelData
            implicitWidth: Theme.barWidth
            implicitHeight: 20

            Image {
                anchors.centerIn: parent
                source: parent.modelData.icon
                width: 14
                height: 14
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            parent.parent.modelData.activate()
                        else
                            parent.parent.modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
