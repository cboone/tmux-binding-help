# tmux-binding-help

tmux-binding-help is a tmux plugin that displays an interactive popup showing all tmux key bindings organized by table. It provides keyboard and mouse navigation, incremental search, and collapsible groups. Written entirely in Bash and AWK with no external dependencies. Requires tmux 3.2+ (for `display-popup`).

## Commands

### Testing

Tests use [Scrut](https://github.com/facebookincubator/scrut), a snapshot testing tool:

make test
```

This runs `scrut test -w . tests` via the Makefile.

There is no build or lint step.

### Installation (for manual testing)

Source `tmux-binding-help.tmux` from a tmux config, or install via TPM Redux:

```text
set -g @plugin 'cboone/tmux-binding-help'
```

## Architecture

The plugin is a 4-stage pipeline:

```text
tmux-binding-help.tmux → scripts/popup.sh → scripts/parse-bindings.awk → scripts/viewer.sh
```

1. **`tmux-binding-help.tmux`** -- Plugin entry point sourced by TPM. Reads the `@tmux-binding-help-key` option (default: `?`) and binds it to launch `popup.sh`.

2. **`scripts/popup.sh`** -- Orchestrator. Pipes `tmux list-keys` through the AWK parser, writes results to a temp file, calculates popup width (66% of client width), and launches `display-popup` running `viewer.sh`.

3. **`scripts/parse-bindings.awk`** -- Parses raw `tmux list-keys` output into TAB-delimited `GROUP` and `BIND` lines. Routes mouse events to virtual `mouse:<table>` groups (internal convention, never exposed to tmux). Uses a two-pass END block: keyboard groups first, then mouse groups.

4. **`scripts/viewer.sh`** -- Interactive TUI (696 lines). Uses parallel arrays for data, supports keyboard navigation (j/k, arrows, g/G, PgUp/PgDn), SGR mouse mode (click, scroll), incremental search with highlighting, and collapsible groups.

**`scripts/helpers.sh`** -- Single utility function `get_tmux_option()` for reading tmux options with defaults.

## Conventions

- **`CURRENT_DIR` from `BASH_SOURCE`**: The pattern `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` embedded in tmux `display-popup` commands is the standard tmux plugin pattern. Not a command injection vulnerability.
- **Single-quoted path interpolation in tmux commands**: `$CURRENT_DIR` inside single-quoted segments of tmux command strings is intentional -- expanded by the outer shell before tmux receives the command.
- **Virtual `mouse:` table prefix**: Internal AWK routing convention to separate mouse from keyboard bindings. Tmux table names cannot contain colons, so no collision risk. These virtual names never leave the parser.
- **Repeated simple calls over loop abstractions**: When a function like `move_up` is called a small fixed number of times (e.g., 3), repeating the call is preferred over a loop. Do not extract loops for trivial repetition.
- **Parsed-but-not-persisted variables**: When a parsed value (e.g., mouse column coordinate) is used only for validation and not stored, this is intentional. The variable serves its purpose during parsing and does not need to persist.
- **Plan documents in `docs/plans/`**: Design sketches that may not exactly match the final implementation. Minor wording discrepancies are expected.
