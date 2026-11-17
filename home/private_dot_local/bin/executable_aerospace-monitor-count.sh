#!/bin/bash

# Authoritative monitor count.
#
# AeroSpace keeps its own monitor list, which can lag a real display change.
# The workspace topology reconciler and the master layout both use the monitor
# count to decide which workspace names are allowed. During that lag a
# single-monitor Mac still reports two monitors, so workspaces 5-8 look legal:
# stray windows are left where they are, and the master layout's restore path
# can even move a window back onto a workspace that no longer has a display.
#
# macOS itself is never ambiguous about how many screens are attached, so ask
# the live screen list through Hammerspoon first and fall back to AeroSpace
# only when Hammerspoon is unavailable. AEROSPACE_MONITOR_COUNT overrides both,
# which keeps the scripts testable without unplugging anything.

set -euo pipefail

if [[ -n ${AEROSPACE_MONITOR_COUNT:-} ]]; then
	printf '%s\n' "$AEROSPACE_MONITOR_COUNT"
	exit 0
fi

HS=${HS:-/opt/homebrew/bin/hs}
AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}

if [[ -x $HS ]]; then
	# Hard wall-clock limit: `hs -t` only bounds the message port, and an
	# unbounded `hs -c` here once hung for 31 hours inside the layout lock.
	count=$(
		"$HS" -t 1 -c 'print(#hs.screen.allScreens())' 2>/dev/null &
		pid=$!
		(
			sleep 2
			kill -TERM "$pid" 2>/dev/null || true
			sleep 0.5
			kill -KILL "$pid" 2>/dev/null || true
		) >/dev/null 2>&1 &
		watchdog=$!
		wait "$pid" || true
		kill "$watchdog" 2>/dev/null || true
	)
	count=$(printf '%s' "$count" | tr -dc '0-9')
	if [[ -n $count ]] && ((count > 0)); then
		printf '%s\n' "$count"
		exit 0
	fi
fi

"$AEROSPACE" list-monitors --count