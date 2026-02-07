# Add Mouse Event Support to Viewer

## Context

The interactive viewer (`scripts/viewer.sh`) currently only supports keyboard navigation.
Adding mouse support will make the plugin more intuitive: click to select items, click
group headers to toggle collapse/expand, click the header row to search, and scroll with
the mouse wheel.

All changes are confined to `scripts/viewer.sh`. No other files need code changes.

## Implementation

### 1. Add mouse coordinate globals

After the existing state variables (~line 50), add:

```bash
MOUSE_ROW=0  # row from last mouse event (1-based)
```

This is set by `read_key()` and read by the main loop. The column coordinate
is parsed for validation but not persisted, as no current behavior requires it.

### 2. Enable/disable mouse tracking

**In `main()`** (after `printf '\033[?25l'`), enable SGR extended mouse tracking:

```bash
printf '\033[?1000h'  # Enable button event tracking
printf '\033[?1006h'  # Enable SGR extended mouse encoding
```

**In `cleanup()`** (before `tput cnorm`), disable it in reverse order:

```bash
printf '\033[?1006l'
printf '\033[?1000l'
```

SGR encoding is preferred because it supports coordinates beyond 223 and
distinguishes press (`M`) from release (`m`).

### 3. Parse SGR mouse sequences in `read_key()`

Add a `'<'` case inside the existing `case "$seq"` block (after `ESC [`):

- Read characters in a loop until `M` (press) or `m` (release), with a 20-char safety limit
- If the safety limit is hit, non-blockingly drain remaining bytes for that mouse sequence
  until `M`/`m` (or timeout), then return `MOUSE_OTHER`
- Ignore release events (`m`) by returning `MOUSE_RELEASE`
- Parse `button;col;row` from the sequence
- Set the `MOUSE_ROW` global (column is validated but not persisted)
- Strip modifier bits from `button` before mapping (`4`, `8`, `16`)
- Return token based on normalized button code:
  - 0 -> `MOUSE_LEFT`
  - 64 -> `MOUSE_SCROLL_UP`
  - 65 -> `MOUSE_SCROLL_DOWN`
  - Everything else -> `MOUSE_OTHER` (ignored by main loop)

### 4. Add `click_select` helper function

In the Navigation section (after `search_next_from_top`):

```bash
click_select() {
  local row="$1"
  # Body occupies rows 2 through TERM_ROWS-1
  if ((row < 2 || row > TERM_ROWS - 1)); then
    return 1
  fi
  local target=$((SCROLL_OFFSET + row - 2))
  if ((target < 0 || target >= ${#VISIBLE[@]})); then
    return 1
  fi
  SELECTED=$target
  return 0
}
```

### 5. Handle mouse events in the main loop

**Normal mode** -- add cases before closing `esac`:

| Token | Behavior |
|-------|----------|
| `MOUSE_LEFT` on row 1 (header) | Enter search mode and clear any existing `SEARCH_TERM` (same behavior as `/`) |
| `MOUSE_LEFT` on body row | Select item; if group, also toggle collapse/expand |
| `MOUSE_LEFT` on footer | Ignore |
| `MOUSE_SCROLL_UP` | `move_up` x3 |
| `MOUSE_SCROLL_DOWN` | `move_down` x3 |
| `MOUSE_RELEASE`, `MOUSE_OTHER`, etc. | Ignore |

**Search mode** -- add cases before closing `esac`:

| Token | Behavior |
|-------|----------|
| `MOUSE_LEFT` on body row | Select item (stay in search mode) |
| `MOUSE_SCROLL_UP` | `move_up` x3 |
| `MOUSE_SCROLL_DOWN` | `move_down` x3 |
| Everything else | Ignore |

### 6. Update file header comment

Add mouse support to the feature list at the top of the file.

## Files to modify

- `scripts/viewer.sh` -- all code changes (mouse parsing, enable/disable, click handling, main loop)

## Verification

1. Ensure tmux mouse mode is enabled: `set -g mouse on`
2. Open tmux and run `prefix + ?` to launch the popup
3. **Click**: Click on a binding item -- it should become selected (reverse video)
4. **Click group**: Click on a group header -- it should toggle collapse/expand
5. **Click header**: Click the top row -- search mode should activate and search term should clear
6. **Scroll**: Use mouse wheel -- selection should move up/down by 3 items
7. **Search + scroll**: Enter search mode, type a term, then scroll through results
8. **Edge cases**: Click on empty body area below last item (should be ignored), click footer (ignored)
9. **Quit**: Press `q` -- terminal should restore cleanly (no lingering mouse tracking)
