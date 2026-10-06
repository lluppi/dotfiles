#!/usr/bin/env sh

set -eu

current=$(hyprctl getoption general:layout | awk '/str:/ { print $2 }')

case "$current" in
  master)
    hyprctl eval 'hl.config({ general = { layout = "dwindle" } })' >/dev/null
    ;;
  dwindle|*)
    hyprctl eval 'hl.config({ general = { layout = "master" } })' >/dev/null
    ;;
esac
