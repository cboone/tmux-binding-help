---
applyTo: "**/*.awk"
---

- **Virtual `mouse:` table prefix**: The `mouse:` prefix on table names is an internal routing convention within the AWK parser to separate mouse bindings from keyboard bindings. These are virtual names that never leave the script -- tmux itself never sees them. Tmux key table names cannot contain colons, so there is no collision risk with real tables. Do not flag this prefix as a potential namespace collision.
