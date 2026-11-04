---
status: accepted
date: 2026-11-04
read_if:
  - running dev-proc outside a git repo
  - changing how dev-proc finds its roots
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#NEEDS-GIT
  - .agents/skills/dev-proc/scripts/dev-proc.janet#all-roots
---

# D-QXMTO5IDSCYSUDTD Outside a git repo dev-proc uses only the nearest work dir and refuses the commit commands

## Context
Every dev-proc command stopped with "not inside a git repository". BR wanted the git integration optional, so the process can run in a plain directory.

## Decision
Outside a git repo the work dir is the nearest one up to `/`, or `--root`, and nothing else; its parent stands in for the repo top. `dev-proc.root` is not read there. The commands that work on commits, the index or hooks (`trailers`, `check-msg`, `check --staged`, `hooks`, `report`) refuse, naming git as the need. Such a work dir has no history, so close and supersede keep files in `closed/` (D-3XCALRBERDES5HTA).

## Why
Finding every root inside a repo relies on `git ls-files` honouring `.gitignore`; walking a plain tree for them would mean rebuilding git's ignore rules by hand, so outside git there is one root. A global `dev-proc.root` is set for the person's repos; reading it in any directory would send work to a dir set up for something else. An environment variable or XDG file for it would be a second configuration path to keep in step with git config (D-6RKLCVKL6N2QK75E). Refusing the commit commands is clearer than letting them do nothing.

## Consequences
A plain directory with several work dirs below it is covered one at a time, through `--root` or the cwd. Moving a work dir into a git repo later gives it history from then on; what it kept in `closed/` stays there.
