#!/usr/bin/env sh
# super+RETURN / super+TAB - swap the focused window with the master.
#
# hyprland 0.56: the master layout implements swapwithmaster, dwindle does not.
# dwindle's whole message list is preselect/splitratio/movetoroot/rotatesplit/
# swapsplit/togglesplit, so swapwithmaster dies with "Unknown dwindle layoutmsg".
# movetoroot is the closest dwindle thing: it yanks the focused window to the
# root of the tree, which is the slot the master lives in.
#
# also 0.56: hyprctl dispatch lua-evals its arguments, so the old
# `hyprctl dispatch layoutmsg swapwithmaster` form fails to parse as lua.

set -eu

layout=$(hyprctl getoption general:layout | awk -F: '/str:/ {gsub(/^ /, "", $2); print $2}')

case "$layout" in
dwindle)
	msg=movetoroot
	;;
*)
	msg=swapwithmaster
	;;
esac

hyprctl dispatch "hl.dsp.layout(\"$msg\")" >/dev/null
