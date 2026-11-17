#!/bin/sh
set -eu

AEROSPACE=/opt/homebrew/bin/aerospace
bundle_id=${1:-}

case "$bundle_id" in
'' | *[!A-Za-z0-9._-]*)
	echo "usage: ${0##*/} <bundle-id>" >&2
	exit 2
	;;
esac

/usr/bin/open -b "$bundle_id"

attempt=0
while [ "$attempt" -lt 40 ]; do
	window_id=$(
		"$AEROSPACE" list-windows \
			--monitor all \
			--app-bundle-id "$bundle_id" \
			--format '%{window-id}' 2>/dev/null | /usr/bin/sed -n '1p'
	)

	if [ -n "$window_id" ] && "$AEROSPACE" focus --window-id "$window_id" 2>/dev/null; then
		exit 0
	fi

	attempt=$((attempt + 1))
	/bin/sleep 0.05
done

# Some utility apps expose windows that AeroSpace cannot manage. Activating the
# app still brings those windows forward as a reliable fallback.
/usr/bin/osascript -e "tell application id \"$bundle_id\" to activate" >/dev/null
