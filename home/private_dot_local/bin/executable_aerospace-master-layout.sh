#!/bin/bash

set -euo pipefail

AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}
HS=${HS:-/opt/homebrew/bin/hs}
STATE_DIR=${XDG_STATE_HOME:-"$HOME/.local/state"}/aerospace-master-layout
LOCK_DIR="$STATE_DIR/lock"
# Placements and hotkeys contend for the lock in bursts (for example the
# window-restore flood after login), so callers wait well past one run.
LOCK_WAIT_SECONDS=${LOCK_WAIT_SECONDS:-5}
# No legitimate run holds the lock this long; past it the owner is hung.
LOCK_STALE_SECONDS=${LOCK_STALE_SECONDS:-30}
# Past hs's own 4s message-port timeout, so only a true hang is cut off.
HS_EVAL_LIMIT_SECONDS=${HS_EVAL_LIMIT_SECONDS:-5}

# Optional hooks for retile_workspace, used by move_focused to fold a
# cross-workspace move and the destination rebuild into ONE eval batch.
RETILE_PREFIX=""
RETILE_SUFFIX=""
RETILE_EXTRA_WINDOW=""
RETILE_EXCLUDE_WINDOW=""

mkdir -p "$STATE_DIR"

MONITOR_COUNT_HELPER=${MONITOR_COUNT_HELPER:-"$HOME/.local/bin/aerospace-monitor-count.sh"}
MONITOR_COUNT=""

# Resolve the live screen count once per invocation. AeroSpace's own monitor
# list can briefly still describe the previous display arrangement, and every
# allowed-workspace decision here derives from the monitor count. While it read
# "2 monitors" on a single-monitor Mac, workspaces 5-8 looked legal: stray
# windows were left in place and restore_window could actively move a window
# back onto a workspace whose display was already gone.
resolve_monitor_count() {
	[[ -n $MONITOR_COUNT ]] && return 0
	MONITOR_COUNT=$("$MONITOR_COUNT_HELPER")
}

# Run a Hammerspoon snippet with a hard wall-clock limit. `hs -t` only bounds
# the message-port send/receive; an `hs -c` once hung for 31 hours while
# holding the layout lock, so every later retile and repair failed silently.
hs_eval() {
	local pid watchdog status=0
	"$HS" -c "$1" &
	pid=$!
	(
		sleep "$HS_EVAL_LIMIT_SECONDS"
		kill -TERM "$pid" 2>/dev/null || true
		sleep 0.5
		kill -KILL "$pid" 2>/dev/null || true
	) >/dev/null 2>&1 &
	watchdog=$!
	wait "$pid" || status=$?
	kill "$watchdog" 2>/dev/null || true
	return "$status"
}

lock_owner_pid() {
	local owner=""
	[[ -f $LOCK_DIR/pid ]] && read -r owner <"$LOCK_DIR/pid" 2>/dev/null || true
	printf '%s\n' "$owner"
}

lock_age_seconds() {
	local mtime
	mtime=$(/usr/bin/stat -f %m "$LOCK_DIR" 2>/dev/null) || return 1
	printf '%s\n' $(($(date +%s) - mtime))
}

release_lock() {
	# Only the owner may release; a broken-and-reacquired lock belongs to
	# someone else by the time a killed stale owner runs its EXIT trap.
	[[ $(lock_owner_pid) == "$$" ]] || return 0
	rm -f "$LOCK_DIR/pid"
	rmdir "$LOCK_DIR" 2>/dev/null || true
}

kill_process_tree() {
	local child
	for child in $(pgrep -P "$1" 2>/dev/null || true); do
		kill_process_tree "$child"
	done
	kill -TERM "$1" 2>/dev/null || true
}

# A lock is stale when its owner is gone, or when it has been held far longer
# than any real run (a hung child). A hung owner is killed with its children.
break_stale_lock() {
	local owner age
	age=$(lock_age_seconds) || return 1
	owner=$(lock_owner_pid)

	if [[ -z $owner ]]; then
		# Between mkdir and the pid write; only stale if it stays that way.
		((age >= 2)) || return 1
	elif kill -0 "$owner" 2>/dev/null; then
		((age >= LOCK_STALE_SECONDS)) || return 1
		echo "breaking layout lock held ${age}s by hung pid $owner" >&2
		kill_process_tree "$owner"
	fi

	# Re-check the owner right before the atomic rename so a lock that was
	# released and re-acquired in the meantime is left alone.
	[[ $(lock_owner_pid) == "$owner" ]] || return 1
	mv "$LOCK_DIR" "$LOCK_DIR.stale.$$" 2>/dev/null || return 1
	rm -rf "$LOCK_DIR.stale.$$"
}

acquire_lock() {
	local attempt attempts=$((LOCK_WAIT_SECONDS * 20))
	for ((attempt = 0; attempt < attempts; attempt++)); do
		if mkdir "$LOCK_DIR" 2>/dev/null; then
			printf '%s\n' "$$" >"$LOCK_DIR/pid"
			trap release_lock EXIT
			return 0
		fi
		# Check staleness about once a second, not on every 50ms poll.
		if ((attempt % 20 == 0)); then
			break_stale_lock && continue
		fi
		sleep 0.05
	done
	echo "layout lock busy (owner pid $(lock_owner_pid), waited ${LOCK_WAIT_SECONDS}s)" >&2
	return 1
}

# Sets CKSUM_KEY to `printf '%s' NAME | cksum | awk '{print $1}'` without
# spawning for the known workspace names (values verified against cksum).
CKSUM_LAST_NAME=""
CKSUM_LAST_KEY=""
cksum_key() {
	case $1 in
	1) CKSUM_KEY=433426081 ;;
	2) CKSUM_KEY=1799278962 ;;
	3) CKSUM_KEY=3106345134 ;;
	4) CKSUM_KEY=2397597396 ;;
	5) CKSUM_KEY=1559342856 ;;
	6) CKSUM_KEY=773517531 ;;
	7) CKSUM_KEY=4228067591 ;;
	8) CKSUM_KEY=1099172911 ;;
	*)
		if [[ -z $CKSUM_LAST_KEY || $1 != "$CKSUM_LAST_NAME" ]]; then
			CKSUM_LAST_KEY=$(printf '%s' "$1" | cksum | awk '{print $1}')
			CKSUM_LAST_NAME=$1
		fi
		CKSUM_KEY=$CKSUM_LAST_KEY
		;;
	esac
}

state_file_for_workspace() {
	local workspace=$1 key
	cksum_key "$workspace"
	key=$CKSUM_KEY
	printf '%s/workspace-%s.master\n' "$STATE_DIR" "$key"
}

array_contains() {
	local needle=$1 item
	shift
	for item in "$@"; do
		[[ $item == "$needle" ]] && return 0
	done
	return 1
}

screen_width_for_window() {
	local window_id=$1
	hs_eval "local w=hs.window.get($window_id); if w then print(math.floor(w:screen():frame().w)) end" 2>/dev/null |
		awk 'NF { value=$1 } END { print value }'
}

window_width() {
	local window_id=$1
	hs_eval "local w=hs.window.get($window_id); if w then print(math.floor(w:frame().w)) end" 2>/dev/null |
		awk 'NF { value=$1 } END { print value }'
}

# The Hammerspoon round-trip costs 50-100ms, which delays width settling
# enough to be visible. Monitor widths are stable, so cache them; the cache
# is cleared on every full rebuild (display-topology changes trigger those).
screen_width_for_monitor() {
	local monitor_name=$1 window_id=$2 key cache_file width=""
	cksum_key "$monitor_name"
	key=$CKSUM_KEY
	cache_file="$STATE_DIR/monitor-$key.width"

	if [[ -f $cache_file ]]; then
		read -r width <"$cache_file" || width=""
		if [[ $width =~ ^[0-9]+$ ]] && ((width > 0)); then
			printf '%s\n' "$width"
			return 0
		fi
	fi

	width=$(screen_width_for_window "$window_id")
	if [[ $width =~ ^[0-9]+$ ]] && ((width > 0)); then
		printf '%s\n' "$width" >"$cache_file"
		printf '%s\n' "$width"
	fi
}

retile_workspace() {
	local workspace=$1 master_override=${2:-} width_override=${3:-} preferred_left=${4:-}
	local monitor_name="" window_id layout state_file master
	local monitor_name_lower is_lg=false

	# Never create layout state for a transient workspace outside the configured
	# topology. Topology reconciliation will switch it to a valid workspace.
	workspace_is_allowed "$workspace" || return 0
	local screen_width="" desired_weight=""
	local available_width="" root_children="" batch_weight="" batch step
	local -a ids=() extras=() target=()
	local count extra_count left_count master_index right_start i

	while IFS='|' read -r window_id monitor_name_for_window layout; do
		[[ -n $window_id && $layout != floating ]] || continue
		[[ $window_id != "$RETILE_EXCLUDE_WINDOW" ]] || continue
		ids[${#ids[@]}]=$window_id
		[[ -n $monitor_name ]] || monitor_name=$monitor_name_for_window
	done < <("$AEROSPACE" list-windows --workspace "$workspace" \
		--format '%{window-id}|%{monitor-name}|%{window-layout}')

	if [[ -n $RETILE_EXTRA_WINDOW ]]; then
		if ((${#ids[@]} == 0)); then
			ids[0]=$RETILE_EXTRA_WINDOW
		elif ! array_contains "$RETILE_EXTRA_WINDOW" "${ids[@]}"; then
			ids[${#ids[@]}]=$RETILE_EXTRA_WINDOW
		fi
	fi
	if [[ -z $monitor_name ]]; then
		monitor_name=$("$AEROSPACE" list-workspaces --all \
			--format '%{workspace}|%{monitor-name}' |
			awk -F'|' -v ws="$workspace" '$1 == ws { print $2; exit }')
	fi

	count=${#ids[@]}
	if ((count == 0)); then
		# Still commit the caller's prefix (for example the float toggle itself)
		# even when no tiled windows remain to arrange.
		if [[ -n $RETILE_PREFIX ]]; then
			"$AEROSPACE" eval -- "$RETILE_PREFIX${RETILE_SUFFIX:+; $RETILE_SUFFIX}"
		fi
		return 0
	fi
	monitor_name_lower=$(printf '%s' "$monitor_name" | tr '[:upper:]' '[:lower:]')
	[[ $monitor_name_lower == *"lg ultragear"* ]] && is_lg=true

	state_file=$(state_file_for_workspace "$workspace")
	master=$master_override
	if [[ -z $master && -f $state_file ]]; then
		read -r master <"$state_file" || master=""
	fi
	if [[ -z $master ]] || ! array_contains "$master" "${ids[@]}"; then
		master=${ids[0]}
	fi
	printf '%s\n' "$master" >"$state_file"

	for window_id in "${ids[@]}"; do
		[[ $window_id == "$master" ]] || extras[${#extras[@]}]=$window_id
	done
	extra_count=$((count - 1))

	if [[ $is_lg == true && $count -ge 4 && -n $preferred_left ]] &&
		array_contains "$preferred_left" "${extras[@]}"; then
		local -a reordered_extras=("$preferred_left")
		for window_id in "${extras[@]}"; do
			[[ $window_id == "$preferred_left" ]] || reordered_extras[${#reordered_extras[@]}]=$window_id
		done
		extras=("${reordered_extras[@]}")
	fi

	if [[ $is_lg == true && $count -ge 4 ]]; then
		left_count=$((extra_count / 2))
		for ((i = 0; i < left_count; i++)); do
			target[i]=${extras[i]}
		done
		target[left_count]=$master
		for ((i = left_count; i < extra_count; i++)); do
			target[i + 1]=${extras[i]}
		done
	else
		left_count=0
		target[0]=$master
		for ((i = 0; i < extra_count; i++)); do
			target[i + 1]=${extras[i]}
		done
	fi

	[[ $workspace =~ ^[A-Za-z0-9._-]+$ ]] || return 1
	batch="${RETILE_PREFIX:+$RETILE_PREFIX; }flatten-workspace-tree --workspace $workspace; layout --workspace $workspace --root h_tiles || true"

	# AeroSpace double-buffers commands sent in one eval batch. Building the
	# complete tree in one request prevents users from seeing the intermediate
	# flatten, swap, join, and resize states.
	for ((i = count - 1; i >= 0; i--)); do
		for ((step = 0; step < count; step++)); do
			batch+="; swap --window-id ${target[i]} dfs-prev || true"
		done
	done

	# Stacks are built with ONE join-with (which creates the v_tiles container
	# from the first pair) and 'move' for every further member. A second
	# join-with would pair a window with the container itself, and the nested
	# same-orientation container gets re-oriented by normalization.
	if [[ $is_lg == true && $count -ge 4 ]]; then
		if ((left_count >= 2)); then
			batch+="; join-with --window-id ${target[1]} left"
			for ((i = 2; i < left_count; i++)); do
				batch+="; move --window-id ${target[i]} left"
			done
		fi

		master_index=$left_count
		right_start=$((master_index + 1))
	else
		right_start=1
	fi
	if ((count - right_start >= 2)); then
		batch+="; join-with --window-id ${target[count - 2]} right"
		for ((i = count - 3; i >= right_start; i--)); do
			batch+="; move --window-id ${target[i]} right"
		done
	fi

	if ((count >= 2)); then
		screen_width=$(screen_width_for_monitor "$monitor_name" "$master")
		if [[ $screen_width =~ ^[0-9]+$ ]] && ((screen_width > 0)); then
			if [[ $is_lg == true && $count -ge 4 ]]; then
				root_children=3
			else
				root_children=2
			fi
			available_width=$((screen_width - 12)) # 6px configured outer gap on each side

			if [[ $width_override =~ ^[0-9]+$ ]] &&
				((width_override > 0 && width_override < screen_width)); then
				# Hammerspoon reports the physical frame. Convert it back to the
				# virtual tile width by restoring the inner-gap share.
				if ((root_children == 3)); then
					desired_weight=$((width_override + 5))
				else
					desired_weight=$((width_override + 3))
				fi
			elif [[ $is_lg == true ]]; then
				desired_weight=$((screen_width * 50 / 100))
			else
				desired_weight=$((screen_width * 55 / 100))
			fi

			# flatten gives every final root child weight 1. During the eventual
			# layout pass AeroSpace adds the same normalization delta to each
			# child, so compensate for that delta before the batch is committed.
			batch_weight=$(((desired_weight * root_children - available_width) / root_children + 1))
			if ((batch_weight >= 0)); then
				batch+="; resize --window-id $master width $batch_weight"
			else
				batch+="; resize --window-id $master width 1; resize --window-id $master width -$((1 - batch_weight))"
			fi
		fi
	fi

	if [[ -n $RETILE_SUFFIX ]]; then
		batch+="; $RETILE_SUFFIX"
	fi
	"$AEROSPACE" eval -- "$batch"
}

workspace_for_window() {
	local wanted_id=$1 id workspace
	while IFS='|' read -r id workspace; do
		if [[ $id == "$wanted_id" ]]; then
			printf '%s\n' "$workspace"
			return 0
		fi
	done < <("$AEROSPACE" list-windows --all --format '%{window-id}|%{workspace}')
	return 1
}

workspace_is_allowed() {
	local workspace=$1
	resolve_monitor_count
	if ((MONITOR_COUNT == 1)); then
		[[ $workspace =~ ^[1-4]$ ]]
	else
		[[ $workspace =~ ^[1-8]$ ]]
	fi
}

safe_workspace_for_window() {
	local wanted_id=$1 id monitor_is_main is_main=""
	resolve_monitor_count
	if ((MONITOR_COUNT == 1)); then
		printf '1\n'
		return
	fi

	while IFS='|' read -r id monitor_is_main; do
		if [[ $id == "$wanted_id" ]]; then
			is_main=$monitor_is_main
			break
		fi
	done < <("$AEROSPACE" list-windows --all --format '%{window-id}|%{monitor-is-main}')
	if [[ $is_main == false ]]; then
		printf '5\n'
	else
		printf '1\n'
	fi
}

window_is_left_of() {
	local window_id=$1 master=$2
	hs_eval "local window=hs.window.get($window_id); local master=hs.window.get($master); if window and master then local frame=window:frame(); local masterFrame=master:frame(); if frame.x+frame.w/2 < masterFrame.x+masterFrame.w/2 then print('true') end end" 2>/dev/null |
		awk '$1 == "true" { found=1 } END { exit !found }'
}

master_has_windows_on_both_sides() {
	local master=$1 old_ifs=$IFS id_csv
	shift
	old_ifs=$IFS
	IFS=,
	id_csv="$*"
	IFS=$old_ifs

	hs_eval "local master=hs.window.get($master); if master then local frame=master:frame(); local center=frame.x+frame.w/2; local left=false; local right=false; for _,id in ipairs({$id_csv}) do local window=hs.window.get(id); if window and window:id()~=master:id() then local other=window:frame(); local otherCenter=other.x+other.w/2; left=left or otherCenter<center; right=right or otherCenter>center end end; if left and right then print('true') end end" 2>/dev/null |
		awk '$1 == "true" { found=1 } END { exit !found }'
}

workspace_layout_is_valid() {
	local workspace=$1 preferred_left=${2:-} state_file master="" id monitor_name="" layout
	local monitor_name_lower is_lg=false master_layout=""
	local count=0 h_nonmaster=0 v_nonmaster=0 extra_count
	local left_count right_count expected_h=0 expected_v=0
	local -a ids=()

	state_file=$(state_file_for_workspace "$workspace")
	[[ -f $state_file ]] && read -r master <"$state_file" || true
	[[ -n $master ]] || return 1

	while IFS='|' read -r id monitor_name_for_window layout; do
		[[ -n $id && $layout != floating ]] || continue
		ids[${#ids[@]}]=$id
		count=$((count + 1))
		[[ -n $monitor_name ]] || monitor_name=$monitor_name_for_window
		if [[ $id == "$master" ]]; then
			master_layout=$layout
		elif [[ $layout == h_tiles ]]; then
			h_nonmaster=$((h_nonmaster + 1))
		elif [[ $layout == v_tiles ]]; then
			v_nonmaster=$((v_nonmaster + 1))
		else
			return 1
		fi
	done < <("$AEROSPACE" list-windows --workspace "$workspace" \
		--format '%{window-id}|%{monitor-name}|%{window-layout}')

	((count > 0)) || return 1
	[[ $master_layout == h_tiles ]] || return 1
	extra_count=$((count - 1))
	monitor_name_lower=$(printf '%s' "$monitor_name" | tr '[:upper:]' '[:lower:]')
	[[ $monitor_name_lower == *"lg ultragear"* ]] && is_lg=true

	if [[ $is_lg == true && $count -ge 4 ]]; then
		left_count=$((extra_count / 2))
		right_count=$((extra_count - left_count))
		((left_count == 1)) && expected_h=$((expected_h + 1))
		((right_count == 1)) && expected_h=$((expected_h + 1))
	else
		((count == 2)) && expected_h=1
	fi
	expected_v=$((extra_count - expected_h))

	((h_nonmaster == expected_h && v_nonmaster == expected_v)) || return 1
	if [[ $is_lg == true && $count -ge 4 ]]; then
		master_has_windows_on_both_sides "$master" "${ids[@]}" || return 1
		if [[ $count -eq 4 && -n $preferred_left ]]; then
			window_is_left_of "$preferred_left" "$master"
		else
			return 0
		fi
	else
		return 0
	fi
}

place_fourth_lg_window() {
	local workspace=$1 new_window=$2 state_file master="" id monitor_name="" layout
	local monitor_name_lower count=0 h_nonmaster=0 v_nonmaster=0
	local master_layout="" new_layout="" screen_width target_width batch_weight

	# The synchronous config fast path has already fixed positions; this pass
	# only settles the master width. A short wait lets the tree queries land
	# after AeroSpace commits the detection transaction.
	sleep 0.03

	state_file=$(state_file_for_workspace "$workspace")
	[[ -f $state_file ]] && read -r master <"$state_file" || true
	[[ -n $master ]] || return 1

	while IFS='|' read -r id monitor_name_for_window layout; do
		[[ -n $id && $layout != floating ]] || continue
		count=$((count + 1))
		[[ -n $monitor_name ]] || monitor_name=$monitor_name_for_window
		if [[ $id == "$master" ]]; then
			master_layout=$layout
		elif [[ $id == "$new_window" ]]; then
			new_layout=$layout
		elif [[ $layout == h_tiles ]]; then
			h_nonmaster=$((h_nonmaster + 1))
		elif [[ $layout == v_tiles ]]; then
			v_nonmaster=$((v_nonmaster + 1))
		fi
	done < <("$AEROSPACE" list-windows --workspace "$workspace" \
		--format '%{window-id}|%{monitor-name}|%{window-layout}')

	monitor_name_lower=$(printf '%s' "$monitor_name" | tr '[:upper:]' '[:lower:]')
	[[ $monitor_name_lower == *"lg ultragear"* ]] || return 1
	[[ $count -eq 4 && $master_layout == h_tiles && $new_layout == h_tiles ]] || return 1
	((h_nonmaster == 0 && v_nonmaster == 2)) || return 1

	screen_width=$(screen_width_for_monitor "$monitor_name" "$master")
	[[ $screen_width =~ ^[0-9]+$ ]] && ((screen_width > 0)) || return 1
	target_width=$((screen_width * 50 / 100))
	batch_weight=$(((target_width * 3 - (screen_width - 12)) / 3 + 1))

	# At the three-to-four transition AeroSpace has already built exactly three
	# root columns; only their first two occupants are reversed. Swap the new
	# singleton, equalize both sides, and size the master in one commit.
	"$AEROSPACE" eval -- "swap --window-id $new_window left || true; balance-sizes; resize --window-id $master width $batch_weight"
}

place_new_window() {
	local new_window=$1 workspace="" id layout="" attempt

	# Un-minimized/un-hidden windows re-enter AeroSpace's tree noticeably later
	# than the Hammerspoon event that reports them, so wait generously.
	for ((attempt = 0; attempt < 40; attempt++)); do
		workspace=$(workspace_for_window "$new_window" 2>/dev/null || true)
		[[ -n $workspace ]] && break
		sleep 0.05
	done
	[[ -n $workspace ]] || return 0

	# A stale workspace can reappear during macOS display/window restoration.
	# Never let the placement pass bless it as a new window home: evacuate the
	# window to the matching monitor's configured range before laying it out.
	if ! workspace_is_allowed "$workspace"; then
		local safe_workspace
		safe_workspace=$(safe_workspace_for_window "$new_window")
		RETILE_PREFIX="move-node-to-workspace --window-id $new_window $safe_workspace"
		RETILE_EXTRA_WINDOW=$new_window
		retile_workspace "$safe_workspace" "" "" "$new_window"
		RETILE_PREFIX=""
		RETILE_EXTRA_WINDOW=""
		return 0
	fi

	while IFS='|' read -r id window_layout; do
		[[ $id == "$new_window" ]] && layout=$window_layout
	done < <("$AEROSPACE" list-windows --workspace "$workspace" \
		--format '%{window-id}|%{window-layout}')

	[[ -n $layout && $layout != floating ]] || return 0
	place_fourth_lg_window "$workspace" "$new_window" && return 0

	# AeroSpace often inserts the new window directly into the desired place.
	# Leave that native placement untouched instead of rebuilding an identical
	# tree—the redundant rebuild is what caused the left → stack → left motion.
	workspace_layout_is_valid "$workspace" "$new_window" && return 0

	# The callback launches this helper asynchronously while AeroSpace is still
	# finishing window detection. Recheck once after that transient state settles.
	sleep 0.04
	workspace_layout_is_valid "$workspace" "$new_window" && return 0
	retile_workspace "$workspace" "" "" "$new_window"
}

# Toggle the focused window between floating and tiling, rebuilding the
# workspace in the same eval batch so the remaining/rejoining tiles land
# directly in the master layout.
toggle_floating() {
	local window layout workspace state_file floated_file master="" master_width=""
	local memo_id="" memo_master="" memo_width=""
	local focused_info
	focused_info=$("$AEROSPACE" list-windows --focused --format '%{window-id}|%{window-layout}|%{workspace}') || return 0
	[[ -n $focused_info ]] || return 0
	IFS='|' read -r window layout workspace <<<"$focused_info"
	[[ -n $window ]] || return 0

	state_file=$(state_file_for_workspace "$workspace")
	floated_file="${state_file%.master}.floated-master"
	[[ -f $state_file ]] && read -r master <"$state_file" || true

	if [[ $layout == floating ]]; then
		[[ -f $floated_file ]] && read -r memo_id memo_master memo_width <"$floated_file" || true
		RETILE_PREFIX="layout --window-id $window tiling"
		RETILE_EXTRA_WINDOW=$window
		if [[ $memo_id == "$window" && $memo_master == "$window" ]]; then
			# A floated master reclaims its slot and width when it re-tiles.
			rm -f "$floated_file"
			retile_workspace "$workspace" "$window" "$memo_width"
		elif [[ $memo_id == "$window" ]]; then
			# Restore the master width memoized at float time. The master's
			# CURRENT width is unusable here: with the window floated away the
			# master may span the whole screen, and restoring that would
			# squeeze the rejoining window into an invisible sliver.
			rm -f "$floated_file"
			retile_workspace "$workspace" "" "$memo_width" "$window"
		else
			retile_workspace "$workspace" "" "" "$window"
		fi
		RETILE_PREFIX=""
		RETILE_EXTRA_WINDOW=""
	else
		# Memoize the pre-float master geometry while the layout is intact.
		if [[ -n $master ]]; then
			master_width=$(window_width "$master")
			printf '%s %s %s\n' "$window" "$master" "$master_width" >"$floated_file"
		fi
		if [[ $master != "$window" ]]; then
			RETILE_PREFIX="layout --window-id $window floating"
			RETILE_EXCLUDE_WINDOW=$window
			retile_workspace "$workspace" "" "$master_width"
		else
			RETILE_PREFIX="layout --window-id $window floating"
			RETILE_EXCLUDE_WINDOW=$window
			retile_workspace "$workspace"
		fi
		RETILE_PREFIX=""
		RETILE_EXCLUDE_WINDOW=""
	fi

	# Tell tiling_focus the layout changed, off the critical path: the layout
	# has committed, and the double fork keeps lock release from waiting on it.
	( hs_eval 'if tilingFocus and tilingFocus.requestRefresh then tilingFocus.requestRefresh("toggle-floating") end' >/dev/null 2>&1 & )
}

# Move the focused window to another workspace/monitor and rebuild the
# destination in the same eval batch, so the window lands directly inside the
# master layout instead of flashing as an extra root column.
move_focused() {
	local direction=$1 window layout cur dest="" focus_suffix=""
	local focused_info is_main="" cur_monitor=""
	focused_info=$("$AEROSPACE" list-windows --focused \
		--format '%{window-id}|%{window-layout}|%{workspace}|%{monitor-is-main}|%{monitor-id}') || return 0
	[[ -n $focused_info ]] || return 0
	IFS='|' read -r window layout cur is_main cur_monitor <<<"$focused_info"
	[[ -n $window ]] || return 0

	case $direction in
	prev | next)
		local first index
		if [[ $is_main == true ]]; then
			first=1
		else
			first=5
		fi
		[[ $cur =~ ^[0-9]+$ ]] && ((cur >= first && cur < first + 4)) || return 0
		index=$((cur - first))
		if [[ $direction == next ]]; then
			dest=$((first + (index + 1) % 4))
		else
			dest=$((first + (index + 3) % 4))
		fi
		;;
	monitor)
		local -a monitors=()
		local monitor idx=0 cur_idx=-1
		while IFS= read -r monitor; do
			[[ -n $monitor ]] || continue
			monitors[idx]=$monitor
			[[ $monitor == "$cur_monitor" ]] && cur_idx=$idx
			idx=$((idx + 1))
		done < <("$AEROSPACE" list-monitors --format '%{monitor-id}')
		((idx > 1 && cur_idx >= 0)) || return 0
		dest=$("$AEROSPACE" list-workspaces --monitor "${monitors[(cur_idx + 1) % idx]}" \
			--visible --format '%{workspace}' | head -n 1)
		focus_suffix="focus --window-id $window"
		;;
	*)
		usage
		;;
	esac

	[[ -n $dest && $dest != "$cur" ]] || return 0

	if [[ $layout == floating ]]; then
		"$AEROSPACE" eval -- "move-node-to-workspace --window-id $window $dest${focus_suffix:+; $focus_suffix}"
		return
	fi

	RETILE_PREFIX="move-node-to-workspace --window-id $window $dest"
	RETILE_SUFFIX=$focus_suffix
	RETILE_EXTRA_WINDOW=$window
	retile_workspace "$dest" "" "" "$window"
	RETILE_PREFIX=""
	RETILE_SUFFIX=""
	RETILE_EXTRA_WINDOW=""

	# Removing the window may have broken the source workspace (for example
	# when its master left). Repair it only when its shape is actually wrong.
	if ! workspace_layout_is_valid "$cur"; then
		retile_workspace "$cur"
	fi
}

# Re-place a window that re-entered the tree via un-minimize/un-hide. macOS
# animates such windows from the Dock, and AeroSpace can sample the frame
# mid-animation and bind the window to the wrong monitor's workspace. When a
# home workspace is supplied, the window is moved back there in the same
# batch as the rebuild.
restore_window() {
	local window=$1 home=${2:-} workspace="" attempt

	for ((attempt = 0; attempt < 40; attempt++)); do
		workspace=$(workspace_for_window "$window" 2>/dev/null || true)
		[[ -n $workspace ]] && break
		sleep 0.05
	done
	[[ -n $workspace ]] || return 0

	# Historical home tracking must not perpetuate a workspace outside the
	# configured topology. place_new_window also evacuates a rogue current home.
	if [[ -n $home ]] && ! workspace_is_allowed "$home"; then
		home=""
	fi

	if [[ -n $home && $home != "$workspace" && $home =~ ^[A-Za-z0-9._-]+$ ]]; then
		RETILE_PREFIX="move-node-to-workspace --window-id $window $home"
		RETILE_SUFFIX="focus --window-id $window"
		RETILE_EXTRA_WINDOW=$window
		retile_workspace "$home" "" "" "$window"
		RETILE_PREFIX=""
		RETILE_SUFFIX=""
		RETILE_EXTRA_WINDOW=""

		# The workspace it wrongly landed on may have been reshaped around it.
		if ! workspace_layout_is_valid "$workspace"; then
			retile_workspace "$workspace"
		fi
	else
		place_new_window "$window"
	fi
}

# Universal safety net: repair any visible workspace whose tree drifted from
# the master layout. Covers re-entry paths that never fire on-window-detected
# (app unhide, un-minimize, dock/menubar launchers focusing hidden apps, ...).
repair_workspace_if_invalid() {
	local ws=$1 id layout fullscreen

	# Respect intentional non-master modes.
	while IFS='|' read -r id layout fullscreen; do
		[[ -n $id ]] || continue
		if [[ $layout == *accordion* || $fullscreen == true ]]; then
			return 0
		fi
	done < <("$AEROSPACE" list-windows --workspace "$ws" \
		--format '%{window-id}|%{window-layout}|%{window-is-fullscreen}')

	workspace_layout_is_valid "$ws" && return 0
	sleep 0.05
	workspace_layout_is_valid "$ws" && return 0
	retile_workspace "$ws"
}

repair_visible() {
	local ws
	while IFS= read -r ws; do
		[[ -n $ws ]] && repair_workspace_if_invalid "$ws"
	done < <("$AEROSPACE" list-workspaces --monitor all --visible --format '%{workspace}')
}

retile_all() {
	local workspace
	rm -f "$STATE_DIR"/monitor-*.width
	while IFS= read -r workspace; do
		[[ -n $workspace ]] && retile_workspace "$workspace"
	done < <("$AEROSPACE" list-windows --all --format '%{workspace}' | sort -u)
}

promote_focused() {
	local focused workspace state_file current_master current_master_width=""
	local next_master="" id found=false
	focused=$("$AEROSPACE" list-windows --focused --format '%{window-id}')
	[[ -n $focused ]] || return 0
	workspace=$(workspace_for_window "$focused")
	state_file=$(state_file_for_workspace "$workspace")
	current_master=""
	[[ -f $state_file ]] && read -r current_master <"$state_file" || true

	if [[ $focused == "$current_master" ]]; then
		while IFS= read -r id; do
			if [[ $found == true ]]; then
				next_master=$id
				break
			fi
			[[ $id == "$focused" ]] && found=true
		done < <("$AEROSPACE" list-windows --workspace "$workspace" --format '%{window-id}')

		if [[ -z $next_master ]]; then
			next_master=$("$AEROSPACE" list-windows --workspace "$workspace" --format '%{window-id}' | head -n 1)
		fi
	else
		next_master=$focused
	fi

	[[ -n $next_master ]] || return 0
	if [[ -n $current_master ]]; then
		current_master_width=$(window_width "$current_master")
	fi
	retile_workspace "$workspace" "$next_master" "$current_master_width"
	"$AEROSPACE" focus --window-id "$next_master" >/dev/null 2>&1 || true
}

usage() {
	echo "usage: $0 --all | --workspace WORKSPACE | --focused-workspace | --window-id ID | --promote-focused | --move-focused (prev|next|monitor) | --toggle-floating | --repair-visible | --restore-window ID [WORKSPACE]" >&2
	exit 2
}

(($# > 0)) || usage
# The repair safety net runs in the background and is coalesced by
# Hammerspoon, so it can afford to outwait a whole placement burst.
[[ $1 == --repair-visible ]] && LOCK_WAIT_SECONDS=${REPAIR_LOCK_WAIT_SECONDS:-15}
acquire_lock

case $1 in
--all)
	(($# == 1)) || usage
	retile_all
	;;
--workspace)
	(($# == 2)) || usage
	retile_workspace "$2"
	;;
--focused-workspace)
	(($# == 1)) || usage
	retile_workspace "$("$AEROSPACE" list-workspaces --focused)"
	;;
--window-id)
	(($# == 2)) || usage
	place_new_window "$2"
	;;
--promote-focused)
	(($# == 1)) || usage
	promote_focused
	;;
--move-focused)
	(($# == 2)) || usage
	move_focused "$2"
	;;
--toggle-floating)
	(($# == 1)) || usage
	toggle_floating
	;;
--repair-visible)
	(($# == 1)) || usage
	repair_visible
	;;
--restore-window)
	(($# == 2 || $# == 3)) || usage
	restore_window "$2" "${3:-}"
	;;
*)
	usage
	;;
esac
