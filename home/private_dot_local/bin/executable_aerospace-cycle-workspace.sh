#!/bin/bash

set -euo pipefail

AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}

direction=${1:-}
case $direction in
next) step=1 ;;
prev) step=-1 ;;
*)
	printf 'usage: %s (next|prev)\n' "${0##*/}" >&2
	exit 2
	;;
esac

# One snapshot for every fact the step depends on. Reading the workspace and its
# monitor in two separate calls let the answers come from different instants: a
# workspace on one display paired with the main-ness of another selected the
# wrong display's four names, and the endpoint fallback below then jumped to a
# workspace that was already visible instead of stepping.
snapshot=$("$AEROSPACE" list-workspaces --all \
	--format '%{workspace}|%{monitor-id}|%{monitor-is-main}|%{workspace-is-focused}')

current=""
monitor_id=""
is_main=""
while IFS='|' read -r workspace id row_is_main is_focused; do
	[[ -n $workspace ]] || continue
	if [[ $is_focused == true ]]; then
		current=$workspace
		monitor_id=$id
		is_main=$row_is_main
		break
	fi
done <<<"$snapshot"

# Workspaces 1-4 belong to the main display and 5-8 to the secondary one, so the
# monitor that owns the focused workspace decides which four names are cycled.
if [[ $is_main == true ]]; then
	first=1
else
	first=5
fi
last=$((first + 3))

if [[ $current =~ ^[0-9]+$ ]] && ((current >= first && current <= last)); then
	index=$((current - first))
	index=$(((index + step + 4) % 4))
elif ((step > 0)); then
	index=0
else
	index=3
fi
target=$((first + index))

commands="workspace $target"

# Activating a workspace that holds no windows does not move AeroSpace's focused
# display: focus stays on the display that still has the previously focused
# window. The next keypress was then computed from that other display and cycled
# it instead of the display just switched, so left/right looked like they had
# stopped working on one screen. Pin the display that owns the target.
monitor_index() {
	local wanted=$1 id idx=0
	while IFS= read -r id; do
		[[ -n $id ]] || continue
		if [[ $id == "$wanted" ]]; then
			printf '%s\n' "$idx"
			return 0
		fi
		idx=$((idx + 1))
	done < <("$AEROSPACE" list-monitors --format '%{monitor-id}')
	return 1
}

if [[ -n $monitor_id ]]; then
	focused_monitor=$("$AEROSPACE" list-monitors --focused --format '%{monitor-id}')
	if [[ -n $focused_monitor && $focused_monitor != "$monitor_id" ]]; then
		# `focus-monitor` also accepts a pattern, but a bare id is ambiguous:
		# the id 2 matches the monitor *name* "DELL U2725QE (2)" as well (both
		# names contain 2725), and an ambiguous pattern can land on the wrong
		# display. Walk the ordered monitor list instead.
		count=$("$AEROSPACE" list-monitors --count)
		if ((count > 0)); then
			current_index=$(monitor_index "$focused_monitor") || current_index=0
			target_index=$(monitor_index "$monitor_id") || target_index=0
			steps=$(((target_index - current_index + count) % count))
			while ((steps > 0)); do
				commands+="; focus-monitor --wrap-around next"
				steps=$((steps - 1))
			done
		fi
	fi
fi

exec "$AEROSPACE" eval -- "$commands"
