# tmux-binding-help

Interactive popup showing all tmux key bindings, organized by table.

Bindings are grouped into collapsible sections (Prefix, Root, Copy Mode vi,
Copy Mode emacs, plus any custom tables). Mouse bindings are separated into
their own groups (Mouse (root), Mouse (copy-mode-vi), etc.) so keyboard shortcuts
are easy to scan. Navigate with the keyboard or mouse, search incrementally,
and collapse/expand groups.

Requires **tmux 3.2+** (for `display-popup`). No external dependencies.

## Install

### With [TPM Redux](https://github.com/RyanMacG/tpm-redux) (recommended)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'cboone/tmux-binding-help'
```

Then press `prefix + I` to install.

### Manual

Clone the repo:

```bash
git clone --depth 1 https://github.com/cboone/tmux-binding-help.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/tmux/plugins/tmux-binding-help
```

Then add to `~/.tmux.conf`:

```tmux
run-shell ~/.local/share/tmux/plugins/tmux-binding-help/tmux-binding-help.tmux
```

### With [TPM](https://github.com/tmux-plugins/tpm) (deprecated)

> [!WARNING]
> The original TPM has not been updated since February 2023. TPM Redux is a
> backward-compatible reimplementation with a maintained codebase, a proper test
> suite, and active development. The plugin format is the same, so switching
> requires only replacing TPM with TPM Redux.

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'cboone/tmux-binding-help'
```

Then press `prefix + I` to install.

## Usage

Press **`prefix + ?`** to open the help popup.

### Keyboard controls

| Key             | Action                       |
| --------------- | ---------------------------- |
| `j` / `k`       | Move down / up               |
| `Down` / `Up`   | Move down / up               |
| `g` / `G`       | Jump to top / bottom         |
| `Home` / `End`  | Jump to top / bottom         |
| `PgUp` / `PgDn` | Page up / down               |
| `Enter` / `Tab` | Toggle group collapse        |
| `Space`         | Toggle group collapse        |
| `c`             | Collapse all groups          |
| `e`             | Expand all groups            |
| `/`             | Start search                 |
| `n` / `N`       | Next / previous search match |
| `Escape`        | Clear search, or quit        |
| `q`             | Quit                         |

### Mouse controls

| Action               | Effect                 |
| -------------------- | ---------------------- |
| Click a binding      | Select it              |
| Click a group header | Toggle collapse        |
| Click the header row | Start search           |
| Scroll wheel         | Move selection up/down |

### Search

Search is case-sensitive and matches against both key names and commands.
Matching text is highlighted, and the status bar shows the number of matches.
Groups auto-expand when a search is active so all results are visible.

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

[MIT](LICENSE). Have fun.
