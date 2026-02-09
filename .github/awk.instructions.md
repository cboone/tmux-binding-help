---
applyTo: "**/*.awk"
---

- **Virtual `mouse:` table prefix**: The `mouse:` prefix on table names is an internal routing convention within the AWK parser to separate mouse bindings from keyboard bindings. These are virtual names that never leave the script -- tmux itself never sees them. Tmux key table names cannot contain colons, so there is no collision risk with real tables. Do not flag this prefix as a potential namespace collision.
- **String comparison in sort**: The `sort_bindings` function uses `<=` for lexicographic comparison. Key values stored via `keys[table, idx] = key repeat` are string-typed because the concatenation with the `repeat` variable converts strnum field values to strings. Do not flag this as a numeric comparison issue.
