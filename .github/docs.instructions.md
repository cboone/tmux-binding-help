---
applyTo: "docs/**/*.md"
---

- **Plan documents in docs/plans/**: These are design documents (both in-progress and completed). Code snippets describe the intended approach at the time of writing and may not exactly match the final implementation. Do not flag code style or escaping issues in these documents.
- **Plan wording vs implementation**: Minor wording discrepancies between plan prose and final code behavior (e.g., "always emitted" when empty groups are actually skipped) are expected in iterative plans. Only flag semantic contradictions that would mislead a reader about the architecture.
