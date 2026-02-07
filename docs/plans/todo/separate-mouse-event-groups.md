# Separate Mouse Events into Dedicated Groups

## Context

Mouse bindings (e.g. `MouseDown1Pane`, `WheelUpPane`) are currently mixed in with keyboard bindings in their respective table groups. In a typical tmux config, mouse events dominate the "Root (no prefix)" group (~26 mouse vs ~4 keyboard bindings), making it hard to scan for keyboard shortcuts. This change separates mouse events into dedicated per-table groups displayed after all keyboard groups.

## Approach

Route mouse events to virtual `mouse:<table>` table names in the AWK parser. This creates separate groups like "Mouse (root)", "Mouse (copy-mode-vi)" that appear after all keyboard groups. The viewer is fully data-driven and needs no changes.

### Detection

A key is a mouse event if, after stripping modifier prefixes (`C-`, `M-`, `S-`), it starts with `Mouse`, `Wheel`, `DoubleClick`, or `TripleClick`.

## Files to Modify

### `scripts/parse-bindings.awk`

**1. Add `is_mouse_key()` function** (after `unescape_key`, before `END`):

```awk
function is_mouse_key(k,    bare) {
    bare = k
    while (bare ~ /^[CMS]-/) {
        bare = substr(bare, 3)
    }
    return (bare ~ /^(Mouse|Wheel|DoubleClick|TripleClick)/)
}
```

**2. Seed mouse groups in `BEGIN` (order + labels)** so known mouse tables have a stable ordering and labeling when present:

```awk
order_count++
order_arr[order_count] = "mouse:root"
order_count++
order_arr[order_count] = "mouse:copy-mode-vi"
order_count++
order_arr[order_count] = "mouse:copy-mode"

table_label["mouse:root"]         = "Mouse (root)"
table_label["mouse:copy-mode-vi"] = "Mouse (copy-mode-vi)"
table_label["mouse:copy-mode"]    = "Mouse (copy-mode)"
```

**3. Rewrite lines 82-98** to unescape, detect mouse keys, then route to virtual table:

```awk
    # Light unescape of common tmux-escaped key literals.
    key = unescape_key(key)

    # Route mouse events to dedicated mouse groups
    if (is_mouse_key(key)) {
        table = "mouse:" table
    }

    # Register new tables we haven't seen
    if (!(table in table_seen)) {
        table_seen[table] = 1
        if (!(table in table_label)) {
            if (table ~ /^mouse:/) {
                table_label[table] = "Mouse (" substr(table, 7) ")"
            } else {
                table_label[table] = table
            }
            order_count++
            order_arr[order_count] = table
        }
    }

    count[table]++
    idx = count[table]
    keys[table, idx] = key repeat
    cmds[table, idx] = cmd
```

**4. Replace `END` block** with two-pass output (keyboard groups first, then mouse groups):

```awk
END {
    for (i = 1; i <= order_count; i++) {
        t = order_arr[i]
        if (t ~ /^mouse:/) continue
        if (count[t] == 0) continue
        label = table_label[t]
        if (label == "") label = t
        printf "GROUP\t%s (%d)\n", label, count[t]
        for (j = 1; j <= count[t]; j++)
            printf "BIND\t%s\t%s\n", keys[t, j], cmds[t, j]
    }
    for (i = 1; i <= order_count; i++) {
        t = order_arr[i]
        if (t !~ /^mouse:/) continue
        if (count[t] == 0) continue
        label = table_label[t]
        if (label == "") label = t
        printf "GROUP\t%s (%d)\n", label, count[t]
        for (j = 1; j <= count[t]; j++)
            printf "BIND\t%s\t%s\n", keys[t, j], cmds[t, j]
    }
}
```

### `tests/parse-bindings.scrut`

**1. Update test 2** ("Handles -N and -F options before key") -- the `MouseDown1Pane` binding should now appear under `Mouse (root)` instead of `Root (no prefix)`:

```
GROUP|Prefix (1)
BIND|%|split-window -h
GROUP|Mouse (root) (1)
BIND|MouseDown1Pane|select-pane -t = && display-menu -T "Pane #{pane_index}"
```

**2. Add new test** for mouse event separation with multiple tables and modifiers:

```
# Separates mouse events into dedicated groups after keyboard groups

$ printf '%s\n' \
>   'bind-key -T root n next-window' \
>   'bind-key -T root MouseDown1Pane select-pane' \
>   'bind-key -T root WheelUpPane scroll-up' \
>   'bind-key -T copy-mode-vi MouseDrag1Pane begin-selection' \
>   'bind-key -T copy-mode-vi v send-keys -X begin-selection' \
>   'bind-key -T root M-DoubleClick1Pane resize-pane -Z' \
>   | awk -f scripts/parse-bindings.awk | tr '\t' '|'
GROUP|Root (no prefix) (1)
BIND|n|next-window
GROUP|Copy Mode (vi) (1)
BIND|v|send-keys -X begin-selection
GROUP|Mouse (root) (3)
BIND|MouseDown1Pane|select-pane
BIND|WheelUpPane|scroll-up
BIND|M-DoubleClick1Pane|resize-pane -Z
GROUP|Mouse (copy-mode-vi) (1)
BIND|MouseDrag1Pane|begin-selection
```

### No changes needed

- `scripts/viewer.sh` -- fully data-driven, new groups work automatically
- `scripts/popup.sh` -- just orchestrates parsing and viewer launch

## Verification

1. Run existing tests: `scrut test tests/`
2. Manual check: open tmux, run `prefix + ?`, verify mouse bindings appear in separate collapsible groups at the bottom
3. Verify collapse/expand and search still work on mouse groups
4. Verify that with no mouse bindings (e.g. `set -g mouse off`), no empty mouse groups appear
