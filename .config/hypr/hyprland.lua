-- hyprland config ported from hyprland.conf (hyprlang → lua)

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR+",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
    bitdepth = 10,
    cm       = "srgb",
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})


---------------------
---- MY PROGRAMS ----
---------------------

local mainMod           = "SUPER"
local terminal          = "ghostty"
local fallbackTerminal  = "ghostty"
local browser           = "/home/lee/.local/bin/librewolf" -- wrapper so h264 works (arch ffmpeg9/libavcodec.so.63 is unlinkable by firefox)
local menu              = "fuzzel"
local runterminal       = "ghostty"
local screenshotBox     = "sh ~/.local/bin/screenshotssh.sh box"
local screenshotWindow  = "sh ~/.local/bin/screenshotssh.sh window"
local pickColor         = "hyprpicker -a"
local toggleBar         = [[sh -lc 'if pgrep -x quickshell >/dev/null; then pkill -x quickshell; else quickshell >/dev/null 2>&1 & fi']]
local gapsDown          = [[sh -lc 'g=$(hyprctl getoption general:gaps_in | awk '"'"'/int:/ {print $2}'"'"'); g=$((g > 0 ? g - 1 : 0)); hyprctl eval "hl.config({ general = { gaps_in = $g, gaps_out = $g } })"']]
local gapsUp            = [[sh -lc 'g=$(hyprctl getoption general:gaps_in | awk '"'"'/int:/ {print $2}'"'"'); g=$((g + 1)); hyprctl eval "hl.config({ general = { gaps_in = $g, gaps_out = $g } })"']]


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Kool")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")
hl.env("DISPLAY", ":0")
local home = os.getenv("HOME") or "/home/lee"
hl.env("XDG_DATA_HOME", home .. "/.local/share")
hl.env("XDG_CONFIG_HOME", home .. "/.config")
hl.env("XDG_CACHE_HOME", home .. "/.cache")
hl.env("XDG_STATE_HOME", home .. "/.local/state")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 1,

        col = {
            active_border   = "rgba(3d3d3dee)",
            inactive_border = "rgba(3d3d3daa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "master",
    },

    decoration = {
        rounding         = 4,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 2,
            color        = "rgba(000000aa)",
        },

        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status  = "master",
        orientation = "center",
        mfact       = 0.5,
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
    },

    render = {
        cm_auto_hdr = 2,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})


-----------------------
---- ANIMATIONS -------
-----------------------

hl.curve("linear",        { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("md3_standard",  { type = "bezier", points = { {0.2, 0},     {0, 1}       } })
hl.curve("md3_decel",     { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}     } })
hl.curve("md3_accel",     { type = "bezier", points = { {0.3, 0},     {0.8, 0.15}  } })
hl.curve("overshot",      { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.1}   } })
hl.curve("crazyshot",     { type = "bezier", points = { {0.1, 1.5},   {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.0}   } })
hl.curve("fluent_decel",  { type = "bezier", points = { {0.1, 1},     {0, 1}       } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0},    {0.15, 1}    } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0, 0.55},    {0.45, 1}    } })
hl.curve("easeOutExpo",   { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3,   bezier = "md3_decel",   style = "popin 60%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.5, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,   bezier = "md3_decel",   style = "slidevert" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        sensitivity  = 0.5,
        kb_layout    = "us",
        follow_mouse = 1,
        accel_profile = "flat",

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({
    name          = "bastard-keyboards-charybdis-mini-(3x6)-splinky-mouse",
    sensitivity   = 1.0,
    accel_profile = "adaptive",
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


---------------------
---- KEYBINDINGS ----
---------------------

-- core app bindings
hl.bind(mainMod .. " + RETURN",       hl.dsp.layout("swapwithmaster"))
hl.bind(mainMod .. " + ALT + RETURN", hl.dsp.exec_cmd(runterminal))
hl.bind(mainMod .. " + R",            hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B",            hl.dsp.exec_cmd(toggleBar))
hl.bind(mainMod .. " + C",            hl.dsp.exec_cmd(pickColor))

-- window management
hl.bind(mainMod .. " + J",            hl.dsp.layout("cyclenext"))
hl.bind(mainMod .. " + K",            hl.dsp.layout("cycleprev"))
hl.bind(mainMod .. " + I",            hl.dsp.layout("addmaster"))
hl.bind(mainMod .. " + D",            hl.dsp.exec_cmd("sh ~/.local/bin/hypr-cycle-layout.sh"))
hl.bind(mainMod .. " + ALT + H",      hl.dsp.window.resize({ x = 0, y = 40 }))
hl.bind(mainMod .. " + Q",            hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + ALT + Q",      hl.dsp.exit())
hl.bind(mainMod .. " + ALT + L",      hl.dsp.exec_cmd("qs -p ~/.config/quickshell/lock.qml"))
hl.bind(mainMod .. " + ALT + C",      hl.dsp.window.close())
hl.bind(mainMod .. " + TAB",          hl.dsp.layout("swapwithmaster"))
hl.bind("ALT + TAB",                  hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB",          hl.dsp.window.cycle_next({ next = false }))

-- layouts and floating
hl.bind(mainMod .. " + T",            hl.dsp.exec_cmd("sh ~/.local/bin/hypr-set-master.sh"))
hl.bind(mainMod .. " + F",            hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M",            hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SPACE",        hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + SPACE",  hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + minus",        hl.dsp.exec_cmd(gapsDown))
hl.bind(mainMod .. " + equal",        hl.dsp.exec_cmd(gapsUp))

-- monitor and workspace movement
hl.bind(mainMod .. " + comma",        hl.dsp.layout("mfact -0.02"), { repeating = true })
hl.bind(mainMod .. " + period",       hl.dsp.layout("mfact +0.02"), { repeating = true })
hl.bind(mainMod .. " + left",         hl.dsp.exec_cmd("sh ~/.local/bin/hypr-workspace-cycle.sh left"))
hl.bind(mainMod .. " + right",        hl.dsp.exec_cmd("sh ~/.local/bin/hypr-workspace-cycle.sh right"))
hl.bind(mainMod .. " + ALT + left",   hl.dsp.exec_cmd("sh ~/.local/bin/hypr-movetoworkspace-cycle.sh left"))
hl.bind(mainMod .. " + ALT + right",  hl.dsp.exec_cmd("sh ~/.local/bin/hypr-movetoworkspace-cycle.sh right"))

-- multi-monitor
hl.bind(mainMod .. " + O",            hl.dsp.focus({ monitor = "+1" }))
hl.bind(mainMod .. " + ALT + O",      hl.dsp.window.move({ monitor = "+1" }))

-- common apps
hl.bind(mainMod .. " + ALT + B",      hl.dsp.exec_cmd(browser))

-- screenshots
hl.bind(mainMod .. " + S",            hl.dsp.exec_cmd(screenshotBox))
hl.bind(mainMod .. " + ALT + S",      hl.dsp.exec_cmd(screenshotWindow))

-- workspaces
for i = 1, 4 do
    hl.bind(mainMod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
end

-- mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- multimedia
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "gimp-float",
    match = { class = "^(Gimp)$" },
    float = true,
})

hl.window_rule({
    name  = "feh-float",
    match = { class = "^(feh)$" },
    float = true,
})

hl.window_rule({
    name  = "event-tester-float",
    match = { title = "^(Event Tester)$" },
    float = true,
})

hl.window_rule({
    name  = "media-viewer-float",
    match = { title = "^(Media viewer)$" },
    float = true,
})

hl.window_rule({
    name  = "floating-title-float",
    match = { title = "^(floating)$" },
    float = true,
})

hl.window_rule({
    name  = "steam-float",
    match = { class = "^steam$" },
    float = true,
})

hl.window_rule({
    name  = "steam-main-tile",
    match = { class = "^steam$", title = "^Steam$" },
    tile  = true,
})

-- steam spawns transient X11 helper windows with class "steam" and an EMPTY
-- title for its dropdown menus / submenus / tooltips. hyprland was treating
-- them as real toplevels: matching steam-float, animating them and grabbing
-- focus for them, which made steam tear them back down ~100ms after they
-- showed up. that is the "menus and modals flash then vanish" bug.
-- no_initial_focus keeps the compositor from auto-focusing them; a click
-- still focuses them normally, so this cannot make a window unfocusable.
hl.window_rule({
    name              = "steam-popup-nofocus",
    match             = { class = "^steam$", title = "^$" },
    no_initial_focus  = true,
})

hl.window_rule({
    name    = "steam-popup-noanim",
    match   = { class = "^steam$", title = "^$" },
    no_anim = true,
})

hl.window_rule({
    name  = "xdg-portal-float",
    match = { class = "^xdg-desktop-portal-gtk$" },
    float = true,
})

hl.window_rule({
    name  = "thunar-float",
    match = { class = "^thunar$" },
    float = true,
})

hl.window_rule({
    name  = "thunar-main-tile",
    match = { class = "^thunar$", title = "^.* - Thunar$" },
    tile  = true,
})

hl.window_rule({
    name  = "thunar-bare-tile",
    match = { class = "^thunar$", title = "^Thunar$" },
    tile  = true,
})

-- wine creates phantom IME helper windows that briefly steal focus when
-- photoshop is running
hl.window_rule({
    name     = "wine-ime-nofocus",
    match    = { title = "^(Default IME)$" },
    no_focus = true,
})

hl.window_rule({
    name     = "wine-msctf-nofocus",
    match    = { title = "^(MSCTFIME UI)$" },
    no_focus = true,
})

-------------------------------------------------------------------------------
---- DEAD REFERENCES STRIPPED (2026-09-18) ------------------------------------
-------------------------------------------------------------------------------
-- these were bound here but the package was never installed, so they only ever
-- failed silently or flashed an empty terminal. install the package and re-add
-- the binding if you want it back (the old lines are in git history):
--
--   XF86MonBrightnessUp / XF86MonBrightnessDown  ->  pacman -S brightnessctl
--   SUPER + E            (emacsclient -c -a emacs) ->  pacman -S emacs
--   SUPER + P            (mpc toggle)              ->  pacman -S mpc
--   SUPER + ALT + M      (ghostty -e ncmpcpp)      ->  pacman -S ncmpcpp
--   exec-once nm-applet  (tray applet)             ->  pacman -S network-manager-applet
--
-- also dropped: the pickColor fallback to ~/.local/bin/xcolor.sh, which does
-- not exist - hyprpicker is installed so pickColor is now just `hyprpicker -a`.
