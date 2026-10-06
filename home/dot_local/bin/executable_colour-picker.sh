#!/usr/bin/env sh

set -eu

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  }
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

need hyprpicker
need wl-copy

color=$(hyprpicker -a | tr -d '\n')
[ -n "$color" ] || exit 1

printf '%s' "$color" | wl-copy
notify "Picked color" "$color"
printf '%s\n' "$color"
