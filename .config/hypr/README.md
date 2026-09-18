# which hypr config is live

**`hyprland.lua` is the live config. edit that one.**

Hyprland 0.56 prefers the Lua config when it exists. From hyprland's own log:

    [cfg] Regular config at /home/lee/.config/hypr/hyprland.lua
    [cfg] Using lua config found at /home/lee/.config/hypr/hyprland.lua

`hyprland.conf` and `hyprland.conf.bak` are **dead** - renamed to `*.unused`
so nobody wastes an evening editing a file nothing reads. Both are still in
git history if you ever want the hyprlang version back.

- check it loaded:  `hyprctl configerrors`   (empty = good)
- reload:           `hyprctl reload`
- panic revert:     `cp ~/.cache/hypr-backups/<newest> ~/.config/hypr/hyprland.lua && hyprctl reload`
