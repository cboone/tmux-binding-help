#!/usr/bin/env bash
#
# Launches the tmux-help popup.
# Called by the tmux keybinding set up in tmux-help.tmux.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

main() {
    local data
    data="$(tmux list-keys | awk -f "$CURRENT_DIR/parse-bindings.awk")"

    if [[ -z "$data" ]]; then
        tmux display-message "tmux-help: no bindings found"
        return 1
    fi

    # Write data to a temp file for the viewer
    local tmpfile
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/tmux-help.XXXXXX")"
    echo "$data" > "$tmpfile"

    # Launch the popup with the viewer
    tmux display-popup \
        -E \
        -T " tmux help · ?:close " \
        -w 80 \
        -h 90% \
        "bash '$CURRENT_DIR/viewer.sh' '$tmpfile'; rm -f '$tmpfile'"
}

main
