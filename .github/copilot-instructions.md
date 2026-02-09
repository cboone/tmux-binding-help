# GitHub Copilot Instructions

## PR Review

- **Cross-file link consistency**: When flagging URL mismatches between files, verify which URL is correct before suggesting a change. The `.claude/CLAUDE.md` file is the authoritative project reference; if a URL differs elsewhere (e.g., README.md), the other file is more likely wrong.
- **Scrut test framework**: This project uses [Scrut from facebookincubator](https://github.com/facebookincubator/scrut). Do not suggest changing this URL to other forks or repositories.
