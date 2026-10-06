pragma Singleton
import QtQuick

QtObject {
    // Font
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property real letterSpacing: 0
    readonly property bool antialiasing: true

    // Colors — matched to librewolf/hyprland palette
    readonly property color bg:        "#1e1e26"
    readonly property color fg:        "#bbbbbb"
    readonly property color fgActive:  "#efefef"
    readonly property color activeBg:  "#786FA6"
    readonly property color hoverBg:   "#2a2a35"
    readonly property color border:    "#3d3d3d"
    readonly property color separator: "#2a2a35"

    // Sizes
    readonly property int barHeight:     20
    readonly property int barWidth:      32
    readonly property int modulePadding: 12
}
