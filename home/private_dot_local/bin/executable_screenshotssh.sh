#!/usr/bin/env sh

set -eu

usage() {
  printf 'usage: %s {box|window}\n' "$0" >&2
  exit 1
}

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

[ $# -eq 1 ] || usage

need grim
need jq
need scp
need wl-copy

filename=$(date '+%d%b%y-%H:%M:%S').png
tmpfile=$(mktemp "/tmp/${filename}.XXXXXX")
rm -f "$tmpfile"
tmpfile="${tmpfile}.png"

cleanup() {
  rm -f "$tmpfile"
}
trap cleanup EXIT INT TERM

case "$1" in
  box)
    need slurp
    geometry=$(slurp) || exit 1
    grim -g "$geometry" "$tmpfile"
    ;;
  window)
    geometry=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    [ -n "$geometry" ] && [ "$geometry" != "null,null nullxnull" ] || {
      printf 'could not determine active window geometry\n' >&2
      exit 1
    }
    grim -g "$geometry" "$tmpfile"
    ;;
  *)
    usage
    ;;
esac

scp "$tmpfile" "root@imre.al:/home/lee/imre.al-zig/public/imre.al/images/screenshot/$filename"
url="https://imre.al/images/screenshot/$filename"
printf '%s' "$url" | wl-copy
notify "Screenshot uploaded" "$url"
printf '%s\n' "$url"
