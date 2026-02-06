# tmux-binding-help

Interactive popup showing all tmux key bindings, organized by table.

Bindings are grouped into collapsible sections (Prefix, Root, Copy Mode vi,
Copy Mode emacs, plus any custom tables). Navigate with the keyboard, search
incrementally, and collapse/expand groups.

Requires **tmux 3.2+** (for `display-popup`). No external dependencies.

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'cboone/tmux-binding-help'
```

Then press `prefix + I` to install.

### Manual

Clone the repo and source it:

```tmux
run-shell /path/to/tmux-binding-help/tmux-binding-help.tmux
```

## Usage

Press **`prefix + ?`** to open the help popup.

### Keyboard controls

| Key              | Action                        |
| ---------------- | ----------------------------- |
| `j` / `k`        | Move down / up                |
| `Down` / `Up`    | Move down / up                |
| `g` / `G`        | Jump to top / bottom          |
| `PgUp` / `PgDn`  | Page up / down                |
| `Enter` / `Tab`  | Toggle group collapse         |
| `Space`          | Toggle group collapse         |
| `c`              | Collapse all groups           |
| `e`              | Expand all groups             |
| `/`              | Start search                  |
| `n` / `N`        | Next / previous search match  |
| `Escape`         | Clear search, or quit         |
| `q`              | Quit                          |

## Configuration

```tmux
# Change the key that opens the help popup (default: ?)
set -g @tmux-binding-help-key '?'
```

## Testing

Parser behavior is covered with [Scrut](https://github.com/jorisvink/scrut) tests.

Run tests from the repository root:

```bash
scrut test -w . tests
```

## License

[MIT](LICENSE)
