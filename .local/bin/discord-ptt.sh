#!/bin/sh
# Discord Push-to-Talk fix for Wayland.
#
# Discord can't grab global keybinds on Wayland, so push-to-talk reads the
# physical key straight off the input device and re-emits it on a virtual
# uinput keyboard that Discord listens to.
#
# We resolve keyboard event nodes live from /proc/bus/input/devices instead of
# globbing /dev/input/by-id/*-event-kbd, because by-id symlinks are USB-only.
# Bluetooth / virtual (uhid) keyboards like the iso74 ZMK board never get a
# by-id link, which is what broke the old script. A "real keyboard" here =
# has the kbd handler, has auto-repeat (EV_REP), and is not also a mouse.

find_keyboards() {
    awk '
        BEGIN { RS=""; FS="\n" }
        {
            ev=""; handlers=""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^B: EV=/)       { ev = $i;       sub(/^B: EV=/, "", ev) }
                if ($i ~ /^H: Handlers=/) { handlers = $i; sub(/^H: Handlers=/, "", handlers) }
            }
            if (handlers ~ /kbd/ && handlers !~ /mouse/ && and(strtonum("0x" ev), 0x100000)) {
                n = split(handlers, a, " ")
                for (i = 1; i <= n; i++)
                    if (a[i] ~ /^event[0-9]+$/) print "/dev/input/" a[i]
            }
        }
    ' /proc/bus/input/devices
}

kbds=$(find_keyboards)

if [ -z "$kbds" ]; then
    echo "discord-ptt: no keyboard event device found, will retry" >&2
    exit 1
fi

for kbd in $kbds; do
    echo "discord-ptt: watching $kbd" >&2
    push-to-talk -k KEY_X -n x "$kbd" &
done
wait
