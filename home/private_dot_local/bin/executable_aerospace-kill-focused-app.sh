#!/bin/sh
set -eu

pid=$(/opt/homebrew/bin/aerospace list-windows --focused --format '%{app-pid}' | /usr/bin/head -n 1)
case "$pid" in
'' | *[!0-9]*) exit 0 ;;
esac
[ "$pid" -gt 1 ] || exit 0

# Terminate the entire focused application, not only its current window.
/bin/kill -TERM "$pid" 2>/dev/null || exit 0

attempt=0
while /bin/kill -0 "$pid" 2>/dev/null && [ "$attempt" -lt 15 ]; do
	/bin/sleep 0.1
	attempt=$((attempt + 1))
done

# A hung application should not turn a kill binding into a no-op.
if /bin/kill -0 "$pid" 2>/dev/null; then
	/bin/kill -KILL "$pid" 2>/dev/null || true
fi
