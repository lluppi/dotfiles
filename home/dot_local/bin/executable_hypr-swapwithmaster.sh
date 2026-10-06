#!/usr/bin/env sh

set -eu

layout=$(hyprctl getoption general:layout | awk -F: '/str:/ {gsub(/^ /, "", $2); print $2}')

if [ "$layout" != "master" ]; then
    hyprctl keyword general:layout master >/dev/null
fi

hyprctl dispatch layoutmsg swapwithmaster >/dev/null
