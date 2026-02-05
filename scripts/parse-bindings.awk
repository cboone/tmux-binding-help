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
}

/^bind-key/ {
    # Detect repeat flag
    repeat = ""
    if ($2 == "-r") {
        repeat = " (repeat)"
        # Shift: -r is $2, -T is $3, table is $4, key is $5, cmd is $6..NF
        table = $4
        key = $5
        cmd = ""
        for (i = 6; i <= NF; i++) {
            cmd = cmd (i > 6 ? " " : "") $i
        }
    } else {
        # No -r: -T is $2, table is $3, key is $4, cmd is $5..NF
        table = $3
        key = $4
        cmd = ""
        for (i = 5; i <= NF; i++) {
            cmd = cmd (i > 5 ? " " : "") $i
        }
    }

    # Validate we got a table from -T flag
    if ($2 != "-T" && $3 != "-T") next

    # Register new tables we haven't seen
    if (!(table in table_seen)) {
        table_seen[table] = 1
        if (!(table in table_label)) {
            table_label[table] = table
            order_count++
            order_arr[order_count] = table
        }
    }

    # Unescape tmux key escaping (e.g., \# -> #, \; -> ;)
    gsub(/\\/, "", key)

    count[table]++
    idx = count[table]
    keys[table, idx] = key repeat
    cmds[table, idx] = cmd
}

END {
    for (i = 1; i <= order_count; i++) {
        t = order_arr[i]
        if (count[t] == 0) continue

        label = table_label[t]
        if (label == "") label = t
        printf "GROUP\t%s (%d)\n", label, count[t]

        for (j = 1; j <= count[t]; j++) {
            k = keys[t, j]
            c = cmds[t, j]
            printf "BIND\t%s\t%s\n", k, c
        }
    }
}
