#!/bin/bash
# Discord Push-to-Talk fix for Wayland.
#
# Discord can't grab global keybinds on Wayland, so `push-to-talk` reads the
# physical key straight off the input device and re-emits it for Discord.
#
# Keyboard event nodes are resolved live from /proc/bus/input/devices, NOT from
# /dev/input/by-id/*-event-kbd, because by-id symlinks are USB-only. Bluetooth /
# virtual (uhid) keyboards like the iso74 ZMK board never get a by-id link.
# A "real keyboard" here = has the kbd handler, has auto-repeat (EV_REP), and is
# not also a mouse.
#
# We watch EVERY keyboard (one push-to-talk per device) and re-scan on a short
# loop. This self-heals the two ways the old `spawn-then-wait` version broke:
#   1. A Bluetooth keyboard drops -> its watcher dies. The old script kept
#      running on the surviving watchers, so systemd never restarted and the
#      dropped keyboard was never re-watched (service looked healthy, PTT dead).
#   2. A Bluetooth keyboard connects *after* startup -> old script never saw it.
# When the set of keyboards (or their event nodes) changes, we restart all
# watchers to match reality.

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
    ' /proc/bus/input/devices | sort
}

pids=()

stop_watchers() {
    [ ${#pids[@]} -gt 0 ] && kill "${pids[@]}" 2>/dev/null
    pids=()
}

start_watchers() {
    pids=()
    for kbd in $1; do
        echo "discord-ptt: watching $kbd" >&2
        push-to-talk -k KEY_X -n x "$kbd" &
        pids+=($!)
    done
}

trap 'stop_watchers; exit 0' TERM INT

current="$(find_keyboards)"
[ -n "$current" ] && start_watchers "$current" || echo "discord-ptt: no keyboard yet, waiting" >&2

while true; do
    sleep 3
    latest="$(find_keyboards)"

    # Count watchers that are still alive; a died watcher (e.g. a BT keyboard
    # that blipped) must be respawned even if the device list looks unchanged.
    alive=0
    for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && alive=$((alive + 1)); done

    if [ "$latest" != "$current" ] || [ "$alive" -ne "${#pids[@]}" ]; then
        echo "discord-ptt: re-arming watchers (devices/watchers changed)" >&2
        stop_watchers
        current="$latest"
        [ -n "$current" ] && start_watchers "$current"
    fi
done
