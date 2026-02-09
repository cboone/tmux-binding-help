# Execute binding with Enter

## Context

The viewer is currently read-only: users can browse, search, and collapse/expand
bindings but cannot act on them. Pressing Enter on a binding line should close the
popup and execute the selected tmux command, making the binding viewer actionable.

## Changes

### 1. `scripts/viewer.sh` - Handle Enter on binding lines

**Separate ENTER from SPACE/TAB** in the normal-mode case statement (line 659):

```bash
# Before:
ENTER | " " | TAB) toggle_group ;;

# After:
ENTER)
  local idx="${VISIBLE[$SELECTED]}"
  if [[ "${ITEM_TYPE[$idx]}" == "group" ]]; then
    toggle_group
  else
    echo "${ITEM_CMD[$idx]}" > "${input_file}.cmd"
    break
  fi
  ;;
" " | TAB) toggle_group ;;
```

When the selected item is a binding, write its command to `<data-file>.cmd` and
exit. When it is a group, toggle collapse as before. SPACE and TAB keep their
existing toggle-only behavior.

**Update the help hint** (line 229) to mention Enter:

```bash
printf '\033[K %sEnter:execute  /:search  c/e:collapse/expand all%s\n' \
```

**Update the file header comment** (line 10) to mention the new behavior:

```
#   - Press Enter on a binding to execute it, or on a group to toggle collapse
```

### 2. `scripts/popup.sh` - Execute the command after viewer exits

Modify the `display-popup` command string (line 32-37) to check for the `.cmd`
file after the viewer exits and pipe it into `tmux source-file -`:

```bash
tmux display-popup \
    -E \
    -T " binding help - $bind_count bindings " \
    -w "${popup_pct}%" \
    -h 90% \
    "bash '$CURRENT_DIR/viewer.sh' '$tmpfile' '$popup_cols'; if [ -f '${tmpfile}.cmd' ]; then exec_cmd=\$(cat '${tmpfile}.cmd'); rm -f '${tmpfile}.cmd' '$tmpfile'; echo \"\$exec_cmd\" | tmux source-file -; else rm -f '$tmpfile'; fi"
```

The command file is written by the viewer when Enter is pressed on a binding. After
the viewer exits, the shell inside the popup reads it and pipes it to
`tmux source-file -`, which executes the tmux command in the server context
(targeting the pane that was active before the popup opened). Then the popup closes.

Using `tmux source-file -` (stdin, available since tmux 3.2) handles all command
formats including compound commands with `;` separators.

## Files modified

- `scripts/viewer.sh` - lines 10, 229, 659
- `scripts/popup.sh` - lines 32-37

## Verification

1. Run `make test` to ensure the AWK parser tests still pass
2. In tmux, trigger the plugin keybinding (prefix + ?) to open the popup
3. Navigate to a simple binding (e.g., `new-window` under Prefix) and press Enter
4. Verify the popup closes and the command executes (a new window appears)
5. Reopen the popup, navigate to a group header, press Enter -- verify it toggles
6. Verify Space and Tab still toggle groups and do nothing on bindings
7. Test with a compound command (one with `;` separators) if available
