#!/usr/bin/awk -f
#
# Parses `tmux list-keys` output into grouped, formatted binding lines.
# Compatible with mawk, gawk, and POSIX awk.
#
# Output format:
#   GROUP<tab>table_name (count)
#   BIND<tab>key<tab>command
#
# Input: raw `tmux list-keys` lines, e.g.:
#   bind-key    -T prefix       c                 new-window
#   bind-key -r -T prefix       Up                select-pane -U

BEGIN {
    # Table display order and friendly names
    order_count = 4
    order_arr[1] = "prefix"
    order_arr[2] = "root"
    order_arr[3] = "copy-mode-vi"
    order_arr[4] = "copy-mode"

    table_label["prefix"]       = "Prefix"
    table_label["root"]         = "Root (no prefix)"
    table_label["copy-mode-vi"] = "Copy Mode (vi)"
    table_label["copy-mode"]    = "Copy Mode (emacs)"

    # Mouse groups appear after all keyboard groups
    order_count++
    order_arr[order_count] = "mouse:root"
    order_count++
    order_arr[order_count] = "mouse:copy-mode-vi"
    order_count++
    order_arr[order_count] = "mouse:copy-mode"

    table_label["mouse:root"]         = "Mouse (root)"
    table_label["mouse:copy-mode-vi"] = "Mouse (copy-mode-vi)"
    table_label["mouse:copy-mode"]    = "Mouse (copy-mode)"
}

/^bind-key/ {
    repeat = ""
    table = ""
    key = ""
    cmd = ""

    # Parse options without assuming fixed field positions.
    i = 2
    while (i <= NF) {
        token = $i

        if (token == "-r") {
            repeat = " (repeat)"
            i++
            continue
        }

        if (token == "-T") {
            if (i + 1 <= NF) {
                table = $(i + 1)
                i += 2
                continue
            }
            break
        }

        # list-keys can include options such as -N/-F before the key.
        # Their argument may be quoted and contain spaces.
        if (token == "-N" || token == "-F") {
            i = consume_option_arg(i + 1)
            continue
        }

        if (token == "--") {
            i++
            break
        }

        if (token ~ /^-/) {
            i++
            continue
        }

        key = token
        i++
        break
    }

    if (table == "" || key == "") next

    for (; i <= NF; i++) {
        cmd = cmd (cmd == "" ? "" : " ") $i
    }

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
}

function consume_option_arg(i,    tok, quote_char) {
    if (i > NF) return i

    tok = $i
    quote_char = substr(tok, 1, 1)

    if ((quote_char == "\"" || quote_char == "'") && length(tok) == 1) {
        while (i < NF) {
            i++
            if (substr($i, length($i), 1) == quote_char) break
        }
        return i + 1
    }

    if ((quote_char == "\"" || quote_char == "'") && substr(tok, length(tok), 1) != quote_char) {
        while (i < NF) {
            i++
            if (substr($i, length($i), 1) == quote_char) break
        }
    }

    return i + 1
}

function unescape_key(raw,    out, i, c, len) {
    out = ""
    len = length(raw)
    for (i = 1; i <= len; i++) {
        c = substr(raw, i, 1)
        if (c == "\\" && i < len) {
            i++
            out = out substr(raw, i, 1)
        } else {
            out = out c
        }
    }
    return out
}

function is_mouse_key(k,    bare) {
    bare = k
    while (bare ~ /^[CMS]-/) {
        bare = substr(bare, 3)
    }
    return (bare ~ /^(Mouse|Wheel|DoubleClick|TripleClick)/)
}

# Insertion sort: order bindings within a table by key text (case-sensitive).
function sort_bindings(t,    i, j, n, tmp_key, tmp_cmd, a, b) {
    n = count[t]
    for (i = 2; i <= n; i++) {
        tmp_key = keys[t, i]
        tmp_cmd = cmds[t, i]
        a = tmp_key
        j = i - 1
        while (j >= 1) {
            b = keys[t, j]
            if (b <= a) break
            keys[t, j + 1] = keys[t, j]
            cmds[t, j + 1] = cmds[t, j]
            j--
        }
        keys[t, j + 1] = tmp_key
        cmds[t, j + 1] = tmp_cmd
    }
}

END {
    for (i = 1; i <= order_count; i++) {
        t = order_arr[i]
        if (t ~ /^mouse:/) continue
        if (count[t] == 0) continue
        sort_bindings(t)
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
        sort_bindings(t)
        label = table_label[t]
        if (label == "") label = t
        printf "GROUP\t%s (%d)\n", label, count[t]
        for (j = 1; j <= count[t]; j++)
            printf "BIND\t%s\t%s\n", keys[t, j], cmds[t, j]
    }
}
