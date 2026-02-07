---
applyTo: "**/*.sh"
---

- **CURRENT_DIR from BASH_SOURCE**: Deriving `CURRENT_DIR` via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` and embedding it in tmux `display-popup` commands is the standard tmux plugin pattern. The installation path is controlled by the user or their plugin manager (e.g., TPM). Do not flag this as a command injection vulnerability.
- **Single-quoted path interpolation in tmux commands**: Embedding `$CURRENT_DIR` inside single-quoted segments of tmux `display-popup` command strings is intentional. The variable is expanded by the outer shell before tmux receives the command. This is the conventional tmux plugin approach.
- **Repeated simple function calls over loop abstractions**: When a function like `move_up` or `move_down` is called a small fixed number of times (e.g., 3), repeating the call is preferred over a loop or helper. This is more readable in Bash and avoids unnecessary abstraction for trivial repetition. Do not suggest extracting loops or helpers for small fixed-count call sequences.
