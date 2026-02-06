#!/usr/bin/env bash
#
# tmux-binding-help: Display an interactive popup with all tmux key bindings.
#
# Installation:
#   With TPM: set -g @plugin 'cboone/tmux-binding-help'
#   Manual:   run-shell /path/to/tmux-binding-help.tmux
#
# Options:
#   @tmux-binding-help-key  - Key to trigger help popup (default: '?')
#                     Bound in the prefix table.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/scripts/helpers.sh"

main() {
    local help_key
    help_key="$(get_tmux_option "@tmux-binding-help-key" "?")"

    tmux bind-key -T prefix "$help_key" run-shell "$CURRENT_DIR/scripts/popup.sh"
}

main
