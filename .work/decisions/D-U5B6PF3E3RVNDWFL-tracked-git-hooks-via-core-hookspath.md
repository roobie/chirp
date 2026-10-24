---
status: accepted
date: 2026-10-24
read_if:
  - adding or changing a commit hook
  - dev-proc hooks install skips a foreign hook
refs:
  - tools/hooks/pre-commit
  - tools/hooks/commit-msg
---

# D-U5B6PF3E3RVNDWFL Tracked git hooks via core.hooksPath

## Context
More than one check has to run at commit time (leakcheck and dev-proc). Hooks in `.git/hooks` are not versioned, and `dev-proc hooks install` overwrites only the hooks it wrote itself.

## Decision
Hooks are tracked in the repo and call each check themselves. Each clone points `core.hooksPath` at them once.

## Why
Versioned hooks are the same on every machine and are reviewed like code. The alternative, hooks installed per clone into `.git/hooks`, drifts silently between machines. It also makes each check's installer compete for the same file.

## Consequences
A fresh clone has no hooks until `core.hooksPath` is set (AGENTS.md says how). To add a new check, edit the tracked hooks; installers that write into the hooks path cannot do it. dev-proc's installer now sees these as foreign hooks and skips them, which is intended.
