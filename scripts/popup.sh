#!/usr/bin/env bash
#
# Launches the tmux-binding-help popup.
# Called by the tmux keybinding set up in tmux-binding-help.tmux.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  local data
  data="$(tmux list-keys | awk -f "$CURRENT_DIR/parse-bindings.awk")"

  if [[ -z "$data" ]]; then
    tmux display-message "tmux-binding-help: no bindings found"
    return 1
  fi

  # Write data to a temp file for the viewer
  local tmpfile
  tmpfile="$(mktemp "${TMPDIR:-/tmp}/tmux-binding-help.XXXXXX")"
  local cmdfile
  cmdfile="$(mktemp "${TMPDIR:-/tmp}/tmux-binding-help-cmd.XXXXXX")"
  trap 'rm -f "$tmpfile" "$cmdfile"' EXIT
  echo "$data" >"$tmpfile"

  # Launch the popup with the viewer
  local popup_pct=66
  local client_width
  client_width=$(tmux display-message -p '#{client_width}')
  local popup_cols=$(( client_width * popup_pct / 100 ))

  local bind_count
  bind_count=$(grep -c '^BIND' "$tmpfile")

  tmux display-popup \
    -E \
    -T " binding help - $bind_count bindings " \
    -w "${popup_pct}%" \
    -h 90% \
    "bash '$CURRENT_DIR/viewer.sh' '$tmpfile' '$popup_cols' '$cmdfile'; if [ -s '$cmdfile' ]; then tmux source-file '$cmdfile'; rm -f '$cmdfile' '$tmpfile'; else rm -f '$cmdfile' '$tmpfile'; fi"
}

main
