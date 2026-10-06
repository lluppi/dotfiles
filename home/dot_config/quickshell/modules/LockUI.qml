import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

Item {
    id: lockUIRoot

    // --- Properties in (set by parent) ---
    property string username: "User"
    property bool authFailed: false
    property bool authAuthenticating: false
    property string authStatusText: "Locked"
    property string wallpaperPath: ""

    // --- Signals out (handled by parent) ---
    signal passwordSubmitted(string password)
    signal escaped()
    signal powerAction(string action)   // "suspend", "reboot", "poweroff"

    // --- Kanagawa Wave palette ---
    readonly property color kBase:     "#16161D"
    readonly property color kSurface0: "#2A2A37"
    readonly property color kSurface1: "#363646"
    readonly property color kSurface2: "#54546D"
    readonly property color kText:     "#DCD7BA"
    readonly property color kSubtext0: "#727169"
    readonly property color kViolet:   "#957FB8"
    readonly property color kRed:      "#E46876"
    readonly property color kOrange:   "#FFA066"
    readonly property color kBlue:     "#7E9CD8"

    // --- Internal UI state ---
    property real introState: 0.0
    property bool powerMenuOpen: false
    property bool inputActive: false
    property bool isPlayingIntro: true
    property string weatherIcon: ""
    property string weatherTemp: "--°C"

    Component.onCompleted: introSequence.start()

    onAuthFailedChanged: { if (authFailed) shakeAnim.restart() }

    // Weather (every 15 min)
    Process {
        id: weatherPoller
        property string scriptPath: Qt.resolvedUrl("../scripts/weather.sh").toString().replace(/^file:\/\//, "")
        command: ["bash", "-c", '"' + scriptPath + '" --current-icon; "' + scriptPath + '" --current-temp']
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 2) {
                    lockUIRoot.weatherIcon = lines[0] || ""
                    lockUIRoot.weatherTemp = lines[1] || "--°C"
                }
            }
        }
    }
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherPoller.running = true }

    // Auto-hide input when empty and idle
    Timer {
        id: idleTimer
        interval: 15000
        running: lockUIRoot.inputActive && inputField.text.length === 0
        repeat: false
        onTriggered: lockUIRoot.inputActive = false
    }

    // ---- BACKGROUND ----

    Rectangle {
        anchors.fill: parent
        color: lockUIRoot.kBase
    }

    Image {
        id: bgWallpaper
        anchors.fill: parent
        source: lockUIRoot.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        cache: false
    }

    MultiEffect {
        source: bgWallpaper
        anchors.fill: bgWallpaper
        blurEnabled: true
        blurMax: 64
        blur: 1.0
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45
    }

    // ---- CLICK TO ACTIVATE ----

    MouseArea {
        anchors.fill: parent
        enabled: !lockUIRoot.isPlayingIntro
        onClicked: {
            if (lockUIRoot.powerMenuOpen) lockUIRoot.powerMenuOpen = false
            if (!lockUIRoot.inputActive) lockUIRoot.inputActive = true
            inputField.forceActiveFocus()
        }
    }

    // ---- MAIN CONTENT ----

    Item {
        anchors.fill: parent
        opacity: lockUIRoot.introState
        transform: Translate { y: 30 * (1.0 - lockUIRoot.introState) }

        // CLOCK MODULE (idle state)
        ColumnLayout {
            id: clockModule
            anchors.centerIn: parent
            anchors.verticalCenterOffset: lockUIRoot.inputActive ? -120 : -40
            spacing: -10
            opacity: lockUIRoot.inputActive ? 0.0 : 1.0
            scale: lockUIRoot.inputActive ? 0.9 : 1.0
            visible: opacity > 0.01

            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0

                Text {
                    id: clockHours
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 140
                    font.weight: Font.Bold
                    color: lockUIRoot.kText
                }
                Text {
                    text: ":"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 140
                    font.weight: Font.Bold
                    opacity: 0.5
                    color: lockUIRoot.kText
                }
                Text {
                    id: clockMinutes
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 140
                    font.weight: Font.Bold
                    color: lockUIRoot.kText
                }
            }

            Text {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                font.weight: Font.Bold
                color: lockUIRoot.kSubtext0
            }

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date()
                    clockHours.text = Qt.formatDateTime(d, "hh")
                    clockMinutes.text = Qt.formatDateTime(d, "mm")
                    dateText.text = Qt.formatDateTime(d, "dddd, MMMM dd")
                }
            }
        }

        // AUTH MODULE (input state)
        RowLayout {
            id: authModule
            anchors.centerIn: parent
            anchors.verticalCenterOffset: lockUIRoot.inputActive ? -40 : 40
            spacing: 32
            opacity: lockUIRoot.inputActive ? 1.0 : 0.0
            scale: lockUIRoot.inputActive ? 1.0 : 0.9
            visible: opacity > 0.01

            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

            // Avatar (blank circle)
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 170; height: 170; radius: 85
                color: Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.5)
                border.color: lockUIRoot.authFailed
                    ? lockUIRoot.kRed
                    : (lockUIRoot.authAuthenticating
                        ? lockUIRoot.kOrange
                        : Qt.rgba(lockUIRoot.kText.r, lockUIRoot.kText.g, lockUIRoot.kText.b, 0.5))
                border.width: 3
                Behavior on border.color { ColorAnimation { duration: 300 } }
            }

            // Username + status + password
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 16

                Text {
                    Layout.alignment: Qt.AlignLeft
                    text: lockUIRoot.username
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: lockUIRoot.kText
                }

                RowLayout {
                    Layout.alignment: Qt.AlignLeft
                    spacing: 12

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: lockUIRoot.authFailed
                            ? Qt.rgba(lockUIRoot.kRed.r, lockUIRoot.kRed.g, lockUIRoot.kRed.b, 0.2)
                            : (lockUIRoot.authAuthenticating
                                ? Qt.rgba(lockUIRoot.kOrange.r, lockUIRoot.kOrange.g, lockUIRoot.kOrange.b, 0.2)
                                : Qt.rgba(lockUIRoot.kViolet.r, lockUIRoot.kViolet.g, lockUIRoot.kViolet.b, 0.15))
                        border.color: lockUIRoot.authFailed
                            ? lockUIRoot.kRed
                            : (lockUIRoot.authAuthenticating ? lockUIRoot.kOrange : lockUIRoot.kViolet)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        Text {
                            anchors.centerIn: parent
                            text: lockUIRoot.authAuthenticating ? "󰌿" : "󰌾"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: lockUIRoot.authFailed
                                ? lockUIRoot.kRed
                                : (lockUIRoot.authAuthenticating ? lockUIRoot.kOrange : lockUIRoot.kViolet)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }

                    Text {
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        font.letterSpacing: 2.0
                        color: lockUIRoot.authFailed
                            ? lockUIRoot.kRed
                            : (lockUIRoot.authAuthenticating ? lockUIRoot.kOrange : lockUIRoot.kText)
                        text: lockUIRoot.authStatusText.toUpperCase()
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                // Password pill
                Rectangle {
                    id: pinPill
                    Layout.alignment: Qt.AlignLeft
                    width: 280; height: 60; radius: 30; clip: true
                    color: lockUIRoot.authFailed
                        ? Qt.rgba(lockUIRoot.kRed.r, lockUIRoot.kRed.g, lockUIRoot.kRed.b, 0.1)
                        : Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.5)
                    border.width: 2
                    border.color: {
                        if (lockUIRoot.authFailed) return lockUIRoot.kRed
                        if (lockUIRoot.authAuthenticating) return lockUIRoot.kOrange
                        if (inputField.text.length > 0) return lockUIRoot.kBlue
                        return Qt.rgba(lockUIRoot.kText.r, lockUIRoot.kText.g, lockUIRoot.kText.b, 0.08)
                    }
                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    scale: lockUIRoot.authFailed ? 1.05 : (lockUIRoot.authAuthenticating ? 0.98 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    transform: Translate { id: shakeTranslate; x: 0 }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8; duration: 120; easing.type: Easing.InOutSine }
                        NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 8; duration: 120; easing.type: Easing.InOutSine }
                        NumberAnimation { target: shakeTranslate; property: "x"; from: 8; to: 0; duration: 120; easing.type: Easing.InOutSine }
                    }

                    // Hidden input captures keystrokes
                    TextInput {
                        id: inputField
                        anchors.fill: parent
                        opacity: 0
                        echoMode: TextInput.Password
                        enabled: !lockUIRoot.isPlayingIntro
                        property string oldText: ""
                        Component.onCompleted: forceActiveFocus()
                        onActiveFocusChanged: {
                            if (!activeFocus && !lockUIRoot.powerMenuOpen && !lockUIRoot.isPlayingIntro)
                                forceActiveFocus()
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                lockUIRoot.inputActive = false
                                text = ""
                                passModel.clear()
                                lockUIRoot.escaped()
                                event.accepted = true
                            } else if (!lockUIRoot.inputActive) {
                                lockUIRoot.inputActive = true
                            }
                        }
                        onAccepted: {
                            if (text.length > 0 && !lockUIRoot.authAuthenticating) {
                                lockUIRoot.authAuthenticating = true
                                lockUIRoot.authStatusText = "Authenticating..."
                                lockUIRoot.authFailed = false
                                lockUIRoot.passwordSubmitted(text)
                                text = ""
                                oldText = ""
                                passModel.clear()
                            }
                        }
                        onTextChanged: {
                            if (lockUIRoot.authAuthenticating) return
                            if (text.length > 0 && !lockUIRoot.inputActive) lockUIRoot.inputActive = true
                            idleTimer.restart()
                            if (text !== oldText) {
                                if (text.length > oldText.length) {
                                    for (let i = oldText.length; i < text.length; i++)
                                        passModel.append({ "charStr": text.charAt(i), "isDot": false })
                                } else if (text.length < oldText.length) {
                                    let diff = oldText.length - text.length
                                    for (let i = 0; i < diff; i++) passModel.remove(passModel.count - 1)
                                } else {
                                    passModel.clear()
                                    for (let i = 0; i < text.length; i++)
                                        passModel.append({ "charStr": text.charAt(i), "isDot": false })
                                }
                                oldText = text
                            }
                            if (text.length > 0) {
                                lockUIRoot.authFailed = false
                                lockUIRoot.authStatusText = "Enter PIN"
                            } else {
                                if (!lockUIRoot.authFailed) lockUIRoot.authStatusText = "Locked"
                            }
                        }
                    }

                    ListModel { id: passModel }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 20; anchors.rightMargin: 20; clip: true

                        Row {
                            id: dotRow
                            anchors.verticalCenter: parent.verticalCenter
                            x: width > parent.width ? parent.width - width : (parent.width - width) / 2
                            spacing: 4
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            Repeater {
                                model: passModel
                                delegate: Item {
                                    width: charText.implicitWidth; height: 30
                                    Timer {
                                        interval: 300; running: true
                                        onTriggered: {
                                            if (index >= 0 && index < passModel.count)
                                                passModel.setProperty(index, "isDot", true)
                                        }
                                    }
                                    Text {
                                        id: charText
                                        anchors.centerIn: parent
                                        text: model.isDot ? "•" : model.charStr
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: model.isDot ? 32 : 24
                                        font.weight: Font.Bold
                                        color: lockUIRoot.authFailed
                                            ? lockUIRoot.kRed
                                            : (lockUIRoot.authAuthenticating ? lockUIRoot.kOrange : lockUIRoot.kText)
                                        NumberAnimation on opacity { from: 0; to: 1; duration: 150 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- BOTTOM: WEATHER PILL ----

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16
        opacity: lockUIRoot.introState
        transform: Translate { y: 20 * (1.0 - lockUIRoot.introState) }

        Rectangle {
            property bool isHovered: weatherMouse.containsMouse
            Layout.preferredHeight: 48
            Layout.preferredWidth: weatherRow.implicitWidth + 36
            radius: 24
            color: isHovered
                ? Qt.rgba(lockUIRoot.kSurface1.r, lockUIRoot.kSurface1.g, lockUIRoot.kSurface1.b, 0.6)
                : Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.4)
            border.color: isHovered ? lockUIRoot.kBlue : Qt.rgba(lockUIRoot.kText.r, lockUIRoot.kText.g, lockUIRoot.kText.b, 0.08)
            border.width: 1
            scale: isHovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            RowLayout {
                id: weatherRow; anchors.centerIn: parent; spacing: 8
                Text {
                    text: lockUIRoot.weatherIcon
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20
                    color: parent.parent.isHovered ? lockUIRoot.kBlue : lockUIRoot.kText
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: lockUIRoot.weatherTemp
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.weight: Font.Black
                    color: lockUIRoot.kText
                }
            }
            MouseArea { id: weatherMouse; anchors.fill: parent; hoverEnabled: true; enabled: !lockUIRoot.isPlayingIntro }
        }
    }

    // ---- POWER MENU ----

    Rectangle {
        id: powerMenu
        anchors.bottom: powerBtn.top
        anchors.right: parent.right
        anchors.bottomMargin: 15; anchors.rightMargin: 40
        width: 240
        height: lockUIRoot.powerMenuOpen ? (menuLayout.implicitHeight + 20) : 0
        radius: 18; clip: true
        opacity: lockUIRoot.powerMenuOpen ? 1 : 0
        color: Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.95)
        border.color: Qt.rgba(lockUIRoot.kViolet.r, lockUIRoot.kViolet.g, lockUIRoot.kViolet.b, 0.25)
        border.width: 1
        Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 250 } }

        ColumnLayout {
            id: menuLayout
            anchors.top: parent.top; anchors.topMargin: 10
            anchors.left: parent.left; anchors.right: parent.right
            spacing: 6

            Text {
                text: "SYSTEM"
                font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Black
                font.pixelSize: 12; font.letterSpacing: 1.5; color: lockUIRoot.kViolet
                Layout.leftMargin: 18; Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; radius: 12
                color: ma1.containsMouse ? Qt.rgba(lockUIRoot.kBlue.r, lockUIRoot.kBlue.g, lockUIRoot.kBlue.b, 0.1) : "transparent"
                scale: ma1.pressed ? 0.95 : (ma1.containsMouse ? 1.02 : 1.0)
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                    Text { text: "󰜉"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: ma1.containsMouse ? lockUIRoot.kBlue : Qt.rgba(lockUIRoot.kBlue.r, lockUIRoot.kBlue.g, lockUIRoot.kBlue.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                    Item { Layout.fillWidth: true }
                    Text { text: "Reboot"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: ma1.containsMouse ? lockUIRoot.kBlue : Qt.rgba(lockUIRoot.kBlue.r, lockUIRoot.kBlue.g, lockUIRoot.kBlue.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                }
                MouseArea { id: ma1; anchors.fill: parent; hoverEnabled: true; onClicked: { lockUIRoot.powerMenuOpen = false; lockUIRoot.powerAction("reboot") } }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; radius: 12
                color: ma2.containsMouse ? Qt.rgba(lockUIRoot.kViolet.r, lockUIRoot.kViolet.g, lockUIRoot.kViolet.b, 0.1) : "transparent"
                scale: ma2.pressed ? 0.95 : (ma2.containsMouse ? 1.02 : 1.0)
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                    Text { text: "󰒲"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: ma2.containsMouse ? lockUIRoot.kViolet : Qt.rgba(lockUIRoot.kViolet.r, lockUIRoot.kViolet.g, lockUIRoot.kViolet.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                    Item { Layout.fillWidth: true }
                    Text { text: "Suspend"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: ma2.containsMouse ? lockUIRoot.kViolet : Qt.rgba(lockUIRoot.kViolet.r, lockUIRoot.kViolet.g, lockUIRoot.kViolet.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                }
                MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; onClicked: { lockUIRoot.powerMenuOpen = false; lockUIRoot.powerAction("suspend") } }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 8; radius: 12
                color: ma3.containsMouse ? Qt.rgba(lockUIRoot.kRed.r, lockUIRoot.kRed.g, lockUIRoot.kRed.b, 0.1) : "transparent"
                scale: ma3.pressed ? 0.95 : (ma3.containsMouse ? 1.02 : 1.0)
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                    Text { text: "󰐥"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: ma3.containsMouse ? lockUIRoot.kRed : Qt.rgba(lockUIRoot.kRed.r, lockUIRoot.kRed.g, lockUIRoot.kRed.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                    Item { Layout.fillWidth: true }
                    Text { text: "Power Off"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.weight: Font.Medium; color: ma3.containsMouse ? lockUIRoot.kRed : Qt.rgba(lockUIRoot.kRed.r, lockUIRoot.kRed.g, lockUIRoot.kRed.b, 0.6); Behavior on color { ColorAnimation { duration: 200 } } }
                }
                MouseArea { id: ma3; anchors.fill: parent; hoverEnabled: true; onClicked: { lockUIRoot.powerMenuOpen = false; lockUIRoot.powerAction("poweroff") } }
            }
        }
    }

    // Power button
    Rectangle {
        id: powerBtn
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 40
        width: 52; height: 52; radius: 26
        color: lockUIRoot.powerMenuOpen
            ? lockUIRoot.kSurface2
            : (powerBtnMa.containsMouse
                ? Qt.rgba(lockUIRoot.kSurface1.r, lockUIRoot.kSurface1.g, lockUIRoot.kSurface1.b, 0.8)
                : Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.4))
        border.color: lockUIRoot.powerMenuOpen ? lockUIRoot.kText : Qt.rgba(lockUIRoot.kText.r, lockUIRoot.kText.g, lockUIRoot.kText.b, 0.15)
        border.width: 1
        opacity: lockUIRoot.introState
        transform: Translate { y: 20 * (1.0 - lockUIRoot.introState) }
        scale: powerBtnMa.pressed ? 0.9 : (powerBtnMa.containsMouse ? 1.08 : 1.0)
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent; text: "󰐥"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
            color: lockUIRoot.powerMenuOpen ? lockUIRoot.kRed : (powerBtnMa.containsMouse ? lockUIRoot.kText : lockUIRoot.kSubtext0)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        MouseArea {
            id: powerBtnMa; anchors.fill: parent; hoverEnabled: true
            enabled: !lockUIRoot.isPlayingIntro
            onClicked: {
                lockUIRoot.powerMenuOpen = !lockUIRoot.powerMenuOpen
                if (!lockUIRoot.powerMenuOpen) inputField.forceActiveFocus()
            }
        }
    }

    // ---- INTRO ANIMATION ----

    Item {
        id: introOverlay
        anchors.fill: parent; z: 999
        visible: lockUIRoot.isPlayingIntro || opacity > 0

        Rectangle {
            id: ring3
            width: 360; height: 360; radius: 180; anchors.centerIn: parent
            color: "transparent"; border.color: lockUIRoot.kViolet; border.width: 1
            scale: 0.5; opacity: 0.0
        }
        Rectangle {
            id: ring2
            width: 300; height: 300; radius: 150; anchors.centerIn: parent
            color: "transparent"; border.color: lockUIRoot.kText; border.width: 1
            scale: 0.8; opacity: 0.0
        }
        Rectangle {
            id: ring1
            width: 240; height: 240; radius: 120; anchors.centerIn: parent
            color: "transparent"; border.color: lockUIRoot.kText; border.width: 2
            scale: 0.8; opacity: 0.0
        }

        Item {
            id: introLockOrb
            width: 170; height: 170; anchors.centerIn: parent
            scale: 0.0; opacity: 0.0

            Rectangle {
                anchors.fill: parent; radius: 85
                color: Qt.rgba(lockUIRoot.kSurface0.r, lockUIRoot.kSurface0.g, lockUIRoot.kSurface0.b, 0.9)
                border.color: lockUIRoot.kText; border.width: 2
            }
            Text {
                id: introIconUnlocked; anchors.centerIn: parent; text: "󰌿"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 64; color: lockUIRoot.kText
                opacity: 1.0; scale: 1.0; transformOrigin: Item.Center
            }
            Text {
                id: introIconLocked; anchors.centerIn: parent; text: "󰌾"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 64; color: lockUIRoot.kText
                opacity: 0.0; scale: 1.6; transformOrigin: Item.Center
            }
        }

        SequentialAnimation {
            id: introSequence
            ParallelAnimation {
                NumberAnimation { target: introLockOrb; property: "scale"; from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: introLockOrb; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring1; property: "scale"; from: 0.8; to: 1.25; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring1; property: "opacity"; from: 0.6; to: 0.0; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring2; property: "scale"; from: 0.8; to: 1.4; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring2; property: "opacity"; from: 0.4; to: 0.0; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring3; property: "scale"; from: 0.5; to: 1.5; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring3; property: "opacity"; from: 0.3; to: 0.0; duration: 350; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    ParallelAnimation {
                        NumberAnimation { target: introIconUnlocked; property: "scale"; from: 1.0; to: 0.5; duration: 100; easing.type: Easing.InCubic }
                        NumberAnimation { target: introIconUnlocked; property: "opacity"; from: 1.0; to: 0.0; duration: 50 }
                        NumberAnimation { target: introIconLocked; property: "scale"; from: 1.6; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: introIconLocked; property: "opacity"; from: 0.0; to: 1.0; duration: 100 }
                        SequentialAnimation {
                            NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 0; to: 3; duration: 40; easing.type: Easing.OutQuad }
                            NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 3; to: 0; duration: 120; easing.type: Easing.OutBack }
                        }
                    }
                }
            }
            PauseAnimation { duration: 50 }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: introLockOrb; property: "scale"; to: 1.8; duration: 100; easing.type: Easing.InCubic }
                    NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InCubic }
                }
                NumberAnimation { target: lockUIRoot; property: "introState"; from: 0.0; to: 1.0; duration: 100; easing.type: Easing.OutCubic }
            }
            PropertyAction { target: lockUIRoot; property: "isPlayingIntro"; value: false }
            ScriptAction { script: { inputField.text = ""; inputField.forceActiveFocus() } }
        }
    }
}
