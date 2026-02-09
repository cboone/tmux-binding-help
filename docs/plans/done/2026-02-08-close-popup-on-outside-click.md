# Close Popup by Clicking Outside

## Context

The tmux-binding-help popup currently only closes via keyboard (`q` or `Escape`). Users expect to be able to click outside the popup to dismiss it, as is standard for overlay/popup UIs. In tmux 3.4+, the popup may already close on outside click at the tmux level, but for tmux 3.2-3.3 the click may be forwarded to the viewer's PTY with out-of-bounds coordinates. Adding viewer-level detection of these out-of-bounds coordinates provides coverage across tmux versions.

## Changes

All changes are in **`scripts/viewer.sh`** (3 edits, ~10 lines changed).

### 1. Include column in the MOUSE_LEFT token (line 523)

```bash
# Before:
0) printf 'MOUSE_LEFT:%d' "$mouse_row" ;;

# After:
0) printf 'MOUSE_LEFT:%d:%d' "$mouse_row" "$mouse_col" ;;
```

The column is already parsed and validated at line 510-518 but currently discarded. This makes it available to the main loop.

### 2. Extract both row and column in the main loop (lines 589-594)

```bash
# Before:
    # Extract mouse row from MOUSE_LEFT:ROW token
    local mouse_row=0
    if [[ "$key" == MOUSE_LEFT:* ]]; then
      mouse_row="${key#MOUSE_LEFT:}"
      key="MOUSE_LEFT"
    fi

# After:
    # Extract mouse row and column from MOUSE_LEFT:ROW:COL token
    local mouse_row=0 mouse_col=0
    if [[ "$key" == MOUSE_LEFT:* ]]; then
      local mouse_coords="${key#MOUSE_LEFT:}"
      mouse_row="${mouse_coords%%:*}"
      mouse_col="${mouse_coords#*:}"
      key="MOUSE_LEFT"
    fi
```

### 3. Add boundary check before mode dispatch (insert after line 594, before line 596)

```bash
    # Close popup on click outside content area
    if [[ "$key" == "MOUSE_LEFT" ]] && ((mouse_row > TERM_ROWS || mouse_col > TERM_COLS)); then
      break
    fi
```

Placed before the search-mode/normal-mode `if`, so it applies regardless of current mode. The `break` exits the main loop, triggering `cleanup()` via the EXIT trap, and the popup closes via `-E`.

Coordinates < 1 are already rejected as `MOUSE_OTHER` in `read_key()` (line 516), so only the upper-bound check is needed here.

## What does not change

- `click_select()`, scroll events, `popup.sh`, `cleanup()`, release/other mouse events
- No new dependencies or version requirements

## Verification

1. Open the popup, click outside it -- popup should close
2. Click inside on bindings, group headers, search bar, footer, empty area -- all should work as before
3. Enter search mode, click outside -- popup should close
4. Scroll inside popup -- should work as before
5. `make test` -- existing parser tests should pass
