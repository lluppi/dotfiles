import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false

        onNotification: notif => {
            notif.tracked = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }

            margins {
                top: 8
                right: Theme.barWidth + 8
            }

            implicitWidth: 320
            implicitHeight: Math.max(1, notifList.contentHeight)

            ListView {
                id: notifList
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: contentHeight
                clip: false
                spacing: 6

                model: server.trackedNotifications

                add: Transition {
                    NumberAnimation { property: "x"; from: 24; to: 0; duration: 300; easing.type: Easing.OutExpo }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                }
                remove: Transition {
                    NumberAnimation { property: "x"; to: 24; duration: 200; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutExpo }
                }

                delegate: NotifCard {
                    required property var modelData
                    notification: modelData
                    width: 320
                }
            }
        }
    }

    component NotifCard: Rectangle {
        id: card

        required property var notification

        readonly property color urgencyColor: {
            if (notification.urgency === NotificationUrgency.Critical) return "#E46876"
            if (notification.urgency === NotificationUrgency.Low) return "#444455"
            return Theme.activeBg
        }
        readonly property bool hasNamedActions: {
            for (var i = 0; i < notification.actions.length; i++) {
                var a = notification.actions[i]
                if (a.identifier !== "default" && a.text.length > 0) return true
            }
            return false
        }
        // expireTimeout is in seconds; 0 = never, -1 = server default (use 5s)
        readonly property int dismissAfterMs: {
            if (notification.urgency === NotificationUrgency.Critical) return 0
            if (notification.expireTimeout > 0) return Math.round(notification.expireTimeout * 1000)
            return 5000
        }

        property bool hovered: false
        property real elapsed: 0
        property real timeoutFraction: dismissAfterMs > 0 ? Math.max(0, 1 - elapsed / dismissAfterMs) : 1

        height: cardCol.implicitHeight + 26
        color: Theme.bg
        radius: 8
        border.color: Theme.border
        border.width: 1
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: card.urgencyColor
        }

        Column {
            id: cardCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 11
                leftMargin: 14
                rightMargin: card.hasNamedActions ? 90 : 12
                bottomMargin: 11
            }
            spacing: 3

            Item {
                width: parent.width
                height: appNameText.implicitHeight

                Text {
                    id: appNameText
                    text: card.notification.appName.toUpperCase()
                    color: "#505060"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                    antialiasing: Theme.antialiasing
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    antialiasing: Theme.antialiasing
                    opacity: card.hovered ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: mouse => {
                            mouse.accepted = true
                            card.notification.dismiss()
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: card.notification.summary
                color: Theme.fgActive
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
                elide: Text.ElideRight
                antialiasing: Theme.antialiasing
                visible: text.length > 0
                topPadding: 1
            }

            Text {
                width: parent.width
                text: card.notification.body
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                antialiasing: Theme.antialiasing
                visible: text.length > 0
                textFormat: Text.PlainText
            }

        }

        Row {
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 5
            visible: card.hasNamedActions

            Repeater {
                model: card.notification.actions

                Rectangle {
                    required property var modelData

                    property bool btnHovered: false

                    visible: modelData.identifier !== "default" && modelData.text.length > 0
                    height: 22
                    width: btnText.implicitWidth + 16
                    color: btnHovered ? Theme.hoverBg : Theme.activeBg
                    border.color: Theme.border
                    border.width: 1
                    radius: 4

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Text {
                        id: btnText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: Theme.fgActive
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        antialiasing: Theme.antialiasing
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.btnHovered = true
                        onExited: parent.btnHovered = false
                        onClicked: mouse => {
                            mouse.accepted = true
                            modelData.invoke()
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: "transparent"
            visible: card.dismissAfterMs > 0

            Rectangle {
                width: parent.width * card.timeoutFraction
                height: parent.height
                color: card.urgencyColor
                opacity: 0.45

                Behavior on width {
                    NumberAnimation { duration: 50 }
                }
            }
        }

        HoverHandler {
            onHoveredChanged: card.hovered = hovered
        }

        Timer {
            interval: 50
            repeat: true
            running: card.dismissAfterMs > 0 && !card.hovered
            onTriggered: {
                card.elapsed += 50
                if (card.elapsed >= card.dismissAfterMs)
                    card.notification.dismiss()
            }
        }
    }
}
