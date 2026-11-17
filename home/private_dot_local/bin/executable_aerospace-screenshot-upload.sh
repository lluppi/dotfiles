#!/bin/sh

set -eu

usage() {
  printf 'usage: %s {box|window}\n' "$0" >&2
  exit 1
}

[ "$#" -eq 1 ] || usage

AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}
SCREENSHOT_DEST=${SCREENSHOT_DEST:-root@imre.al:/home/lee/imre.al-zig/public/imre.al/images/screenshot}
SCREENSHOT_BASE_URL=${SCREENSHOT_BASE_URL:-https://imre.al/images/screenshot}

filename=$(/bin/date '+%d%b%y-%H:%M:%S').png
tmpdir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp/}aerospace-screenshot.XXXXXX")
tmpfile="$tmpdir/$filename"

cleanup() {
  /bin/rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM

case "$1" in
  box)
    /usr/sbin/screencapture -i -s "$tmpfile"
    ;;
  window)
    window_id=$(
      "$AEROSPACE" list-windows --focused --format '%{window-id}' 2>/dev/null || true
    )

    if [ -n "$window_id" ]; then
      /usr/sbin/screencapture -l "$window_id" "$tmpfile" 2>/dev/null || true
    fi

    if [ ! -s "$tmpfile" ]; then
      /usr/sbin/screencapture -i -W "$tmpfile"
    fi
    ;;
  *)
    usage
    ;;
esac

# Interactive capture exits without a file when canceled.
[ -s "$tmpfile" ] || exit 0

/usr/bin/scp "$tmpfile" "$SCREENSHOT_DEST/$filename"
url="$SCREENSHOT_BASE_URL/$filename"
printf '%s' "$url" | /usr/bin/pbcopy
/usr/bin/osascript -e "display notification \"$url\" with title \"Screenshot uploaded\""
printf '%s\n' "$url"
