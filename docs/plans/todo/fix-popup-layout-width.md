# Fix popup content layout

## Context

The popup content is garbled and unreadable because `viewer.sh` uses `tput cols` to
determine the terminal width, but inside a tmux popup, `tput cols` can return the
**outer terminal's width** (e.g., 200+ columns) instead of the popup's interior width
(78 columns). This causes each binding line to be formatted for ~200 columns, which
wraps multiple times inside the 78-column popup, creating overlapping jumbled text.

## Changes

### 1. `scripts/popup.sh` - Pass popup width to viewer

- Extract the popup width (`80`) into a variable
- Pass it as the second argument to `viewer.sh`

```bash
local popup_width=80
tmux display-popup \
    -E \
    -T " tmux help · ?:close " \
    -w "$popup_width" \
    -h 90% \
    "bash '$CURRENT_DIR/viewer.sh' '$tmpfile' '$popup_width'; rm -f '$tmpfile'"
```

### 2. `scripts/viewer.sh` - Use the passed width

- Accept the popup width as an optional second argument in `main()`
- In `get_term_size()`, compute `TERM_COLS` as `popup_width - 2` (subtracting 2 for
  the left and right border characters) when the parameter is provided, falling back
  to `tput cols` otherwise

```bash
# In main():
POPUP_WIDTH="${2:-}"

# In get_term_size():
get_term_size() {
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    if [[ -n "$POPUP_WIDTH" ]] && (( POPUP_WIDTH > 0 )); then
        TERM_COLS=$(( POPUP_WIDTH - 2 ))
    else
        TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    fi
}
```

## Verification

1. Open tmux and trigger the plugin keybinding to display the popup
2. Verify that content is properly aligned: 5-space indent, key column, then command
3. Verify that long commands are truncated with ellipsis rather than wrapping
4. Test search, navigation, and collapse/expand still work correctly
