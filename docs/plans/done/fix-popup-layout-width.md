# Fix popup content layout

## Context

The popup content is garbled and unreadable because `viewer.sh` uses `tput cols` to
determine the terminal width, but inside a tmux popup, `tput cols` can return the
**outer terminal's width** (e.g., 200+ columns) instead of the popup's interior width
(78 columns). This causes each binding line to be formatted for ~200 columns, which
wraps multiple times inside the 78-column popup, creating overlapping jumbled text.

## Changes

### 1. `scripts/popup.sh` - Pass actual popup width to viewer

- Extract the configured popup width (`80`) into a variable for `display-popup`
- Pass the **runtime popup pane width** (not the configured literal) as the second
  argument to `viewer.sh`, so tmux clamping and future `%` widths still work

```bash
local popup_width=80
tmux display-popup \
    -E \
    -T " tmux help · ?:close " \
    -w "$popup_width" \
    -h 90% \
    "popup_pane_width=\"\$(tmux display-message -p '#{pane_width}')\"; bash '$CURRENT_DIR/viewer.sh' '$tmpfile' \"$popup_pane_width\"; rm -f '$tmpfile'"
```

### 2. `scripts/viewer.sh` - Use the passed width

- Accept the popup width as an optional second argument in `main()`
- Validate that argument is numeric before using it
- In `get_term_size()`, compute `TERM_COLS` as `popup_width - 2` (subtracting 2 for
  the left and right border characters) when the parameter is valid and `> 2`,
  falling back to `tput cols` otherwise
- Clamp to a small minimum width to avoid negative or unusable widths in edge cases

```bash
# In main():
POPUP_WIDTH_RAW="${2:-}"
POPUP_WIDTH=""
if [[ "$POPUP_WIDTH_RAW" =~ ^[0-9]+$ ]]; then
    POPUP_WIDTH="$POPUP_WIDTH_RAW"
fi

# In get_term_size():
get_term_size() {
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    if [[ -n "$POPUP_WIDTH" ]] && (( POPUP_WIDTH > 2 )); then
        TERM_COLS=$(( POPUP_WIDTH - 2 ))
    else
        TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    fi
    (( TERM_COLS < 20 )) && TERM_COLS=20
}
```

### 3. Optional follow-up - Height parity

- If testing still shows viewport issues in some tmux setups, pass runtime popup
  height the same way and derive rows from that value instead of `tput lines`

## Verification

1. Open tmux and trigger the plugin keybinding to display the popup
2. Verify that content is properly aligned: 5-space indent, key column, then command
3. Verify that long commands are truncated with ellipsis rather than wrapping
4. Test search, navigation, and collapse/expand still work correctly
