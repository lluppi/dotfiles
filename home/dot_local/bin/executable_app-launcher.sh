#!/bin/sh

set -eu

collect_apps() {
    for dir in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications; do
        [ -d "$dir" ] || continue
        for file in "$dir"/*.desktop; do
            [ -f "$file" ] || continue

            name="$(awk -F= '
                /^\[Desktop Entry\]$/ { in_entry=1; next }
                /^\[/ && $0 != "[Desktop Entry]" { in_entry=0 }
                in_entry && /^Name=/ { print substr($0, 6); exit }
            ' "$file")"

            nodisplay="$(awk -F= '
                /^\[Desktop Entry\]$/ { in_entry=1; next }
                /^\[/ && $0 != "[Desktop Entry]" { in_entry=0 }
                in_entry && /^NoDisplay=/ { print tolower($2); exit }
            ' "$file")"

            hidden="$(awk -F= '
                /^\[Desktop Entry\]$/ { in_entry=1; next }
                /^\[/ && $0 != "[Desktop Entry]" { in_entry=0 }
                in_entry && /^Hidden=/ { print tolower($2); exit }
            ' "$file")"

            [ -n "$name" ] || continue
            [ "$nodisplay" != "true" ] || continue
            [ "$hidden" != "true" ] || continue

            printf '%s\t%s\n' "$name" "$file"
        done
    done
}

desktop_value() {
    file="$1"
    key="$2"

    awk -F= -v key="$key" '
        /^\[Desktop Entry\]$/ { in_entry=1; next }
        /^\[/ && $0 != "[Desktop Entry]" { in_entry=0 }
        in_entry && $1 == key { print substr($0, index($0, "=") + 1); exit }
    ' "$file"
}

sanitize_exec() {
    printf '%s\n' "$1" | sed 's/ *%[fFuUdDnNickvm]//g'
}

choice="$(
    collect_apps \
        | sort -u \
        | fzf --delimiter="$(printf '\t')" --with-nth=1 --prompt='Run: ' --layout=reverse --height=40%
)"

[ -n "$choice" ] || exit 0

desktop_file="$(printf '%s\n' "$choice" | awk -F '\t' '{ print $2 }')"
[ -n "$desktop_file" ] || exit 1
[ -f "$desktop_file" ] || exit 1

exec_line="$(desktop_value "$desktop_file" Exec)"
[ -n "$exec_line" ] || exit 1

exec_line="$(sanitize_exec "$exec_line")"
[ -n "$exec_line" ] || exit 1

exec sh -lc "$exec_line"
