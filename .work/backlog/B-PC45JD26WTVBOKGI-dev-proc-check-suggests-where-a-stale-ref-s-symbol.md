---
created: 2026-10-30
---

# B-PC45JD26WTVBOKGI dev-proc check suggests where a stale ref's symbol went

## Why
When a renamed symbol breaks a ref, `check` says the ref is broken but not where the symbol went, so the agent hunts by hand. Reported from heavy dev-proc use in another repo (2026-10-30 ergonomics feedback).

## Notes
- Idea: when the file still exists, search git history (`git log -S`) for the old name and suggest the new one; `--fix` would apply it.
- Parked rather than built: rename guessing is fuzzy, `--fix` would rewrite durable records on a guess, and it happens rarely. Revisit if broken refs become common.
