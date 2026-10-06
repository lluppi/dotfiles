#!/usr/bin/env sh

set -eu

fullscreen=$(hyprctl -j activewindow | jq -r '.fullscreen')

case "$fullscreen" in
  1|2)
    hyprctl dispatch 'hl.dsp.window.fullscreen()' >/dev/null
    ;;
esac

hyprctl eval 'hl.config({ general = { layout = "master" } })' >/dev/null
