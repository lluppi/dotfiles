#!/bin/bash

set -euo pipefail

AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}
MASTER_LAYOUT=${MASTER_LAYOUT:-"$HOME/.local/bin/aerospace-master-layout.sh"}
MONITOR_COUNT_HELPER=${MONITOR_COUNT_HELPER:-"$HOME/.local/bin/aerospace-monitor-count.sh"}
STATE_DIR=${XDG_STATE_HOME:-"$HOME/.local/state"}/aerospace-topology
LOG_FILE="$STATE_DIR/topology.log"
LOG_MAX_LINES=400

# `--check` is read-only: it exits 1 while a disallowed workspace is still
# visible or still holds windows. Callers use it to verify that a
# reconciliation pass actually converged, which is how a stale monitor count at
# the trigger instant stops mattering.
#
# `--monitors N` pins the monitor count. The live screen count is authoritative
# and comes from macOS (see aerospace-monitor-count.sh); AeroSpace's own
# `list-monitors` is only consulted for the diagnostic log line, because it can
# lag a display change and would otherwise hide real drift.
check_only=false
monitors_override=""

usage() {
	printf 'usage: %s [--check] [--monitors N]\n' "${0##*/}" >&2
	exit 2
}

while (($# > 0)); do
	case $1 in
	--check) check_only=true ;;
	--monitors)
		monitors_override=${2:-}
		[[ $monitors_override =~ ^[0-9]+$ ]] || usage
		shift
		;;
	reconcile) ;;
	*) usage ;;
	esac
	shift
done

# Reconciliation only runs on real triggers (startup, display change, a drift
# poll that found something), so logging every pass is low-volume and is the
# only way to tell after the fact whether a trigger fired and what the two
# monitor counts were at that moment.
log() {
	mkdir -p "$STATE_DIR"
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
	if (($(wc -l <"$LOG_FILE") > LOG_MAX_LINES)); then
		tail -n $((LOG_MAX_LINES / 2)) "$LOG_FILE" >"$LOG_FILE.tmp" &&
			mv "$LOG_FILE.tmp" "$LOG_FILE"
	fi
}

if [[ -n $monitors_override ]]; then
	monitor_count=$monitors_override
else
	monitor_count=$("$MONITOR_COUNT_HELPER")
fi

# One AeroSpace request returns every workspace and every window. `ws|` rows
# are name|visible|focused|monitor-is-main, `win|` rows are id|workspace.
snapshot=$("$AEROSPACE" eval -- "list-workspaces --all --format 'ws|%{workspace}|%{workspace-is-visible}|%{workspace-is-focused}|%{monitor-is-main}' && list-windows --all --format 'win|%{window-id}|%{workspace}'")
ws_rows=""
win_rows=""
focused=""
while IFS='|' read -r kind f1 f2 f3 f4; do
	case $kind in
	ws)
		ws_rows+="$f1|$f2|$f4"$'\n'
		[[ $f3 == true && -z $focused ]] && focused=$f1
		;;
	win) win_rows+="$f1|$f2"$'\n' ;;
	esac
done <<<"$snapshot"
target_focus=$focused
commands=""
touched=""
needs_reconcile=false

workspace_is_allowed() {
	local workspace=$1
	if ((monitor_count == 1)); then
		[[ $workspace =~ ^[1-4]$ ]]
	else
		[[ $workspace =~ ^[1-8]$ ]]
	fi
}

workspace_fallback() {
	local workspace=$1 is_main
	if ((monitor_count == 1)); then
		if [[ $workspace =~ ^[5-8]$ ]]; then
			printf '%s\n' "$((workspace - 4))"
		else
			printf '1\n'
		fi
		return
	fi

	is_main=""
	while IFS='|' read -r name _ main; do
		if [[ $name == "$workspace" ]]; then
			is_main=$main
			break
		fi
	done <<<"$ws_rows"
	if [[ $is_main == false ]]; then
		printf '5\n'
	else
		printf '1\n'
	fi
}

# Reconcile every workspace, including an empty but visible rogue workspace.
# `persistent-workspaces` keeps 5-8 alive even on one monitor, so plain
# existence is expected and is not by itself drift: only a disallowed workspace
# that is visible or still holds windows needs action.
while IFS='|' read -r source is_visible _; do
	[[ -n $source ]] || continue
	workspace_is_allowed "$source" && continue

	window_ids=""
	while IFS='|' read -r win_id win_ws; do
		[[ $win_ws == "$source" ]] && window_ids+="${window_ids:+$'\n'}$win_id"
	done <<<"$win_rows"
	if [[ -n $window_ids || $is_visible == true ]]; then
		needs_reconcile=true
	fi
	if [[ $check_only == true ]]; then
		continue
	fi

	target=$(workspace_fallback "$source")
	while IFS= read -r window_id; do
		[[ -n $window_id ]] || continue
		commands+="${commands:+; }move-node-to-workspace --window-id $window_id $target"
		touched+=" $target"
	done <<<"$window_ids"

	# Replacing windows is insufficient when the rogue workspace is empty but
	# visible. Activate its assigned fallback on that monitor, then restore the
	# previously focused workspace after every monitor has been reconciled.
	if [[ $is_visible == true ]]; then
		commands+="${commands:+; }workspace $target"
	fi
	[[ $focused == "$source" ]] && target_focus=$target
done < <(printf '%s' "$ws_rows" | sort -t'|' -k1,1V)

if [[ $check_only == true ]]; then
	if [[ $needs_reconcile == true ]]; then
		aerospace_count=$("$AEROSPACE" list-monitors --count)
		log "check drift monitors=$monitor_count aerospace=$aerospace_count focused=$focused"
		exit 1
	fi
	exit 0
fi

moves=0
if [[ -n $commands ]]; then
	if workspace_is_allowed "$target_focus"; then
		commands+="; workspace $target_focus"
	fi
	# grep exits 1 with no matches; under pipefail that would abort the script
	# before eval, leaving an empty-but-visible rogue workspace unreconciled.
	moves=$( { printf '%s' "$commands" | grep -o 'move-node-to-workspace' || true; } | wc -l | tr -d ' ')
	"$AEROSPACE" eval -- "$commands"
fi

aerospace_count=$("$AEROSPACE" list-monitors --count)
log "reconcile monitors=$monitor_count aerospace=$aerospace_count focused=$focused drift=$needs_reconcile moves=$moves"

for target in 1 2 3 4 5 6 7 8; do
	if [[ " $touched " == *" $target "* ]]; then
		AEROSPACE_MONITOR_COUNT="$monitor_count" "$MASTER_LAYOUT" --workspace "$target"
	fi
done