---
status: accepted
date: 2026-11-04
read_if:
  - running dev-proc outside a git repo
  - changing how dev-proc finds its roots
  - adding a dev-proc option that holds for every command
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#NEEDS-GIT
  - .agents/skills/dev-proc/scripts/dev-proc.janet#all-roots
  - .agents/skills/dev-proc/scripts/dev-proc.janet#ENV-OPTIONS
supersedes:
  - D-QXMTO5IDSCYSUDTD
---

# D-OJWNN7A4X42UNFUG Outside a git repo dev-proc uses only one work dir, and every global option has a DEV_PROC_ variable

## Context
D-QXMTO5IDSCYSUDTD made dev-proc run outside a git repo with the nearest work dir or `--root`, and turned down an environment variable for the root. BR then wanted a work dir, and other options that never change, pinned per directory, without typing `--root` each time and without git.

## Decision
Outside a git repo the work dir is the nearest one up to `/`, or `--root`, and nothing else; its parent stands in for the repo top. `dev-proc.root` is not read there. The commands that work on commits, the index or hooks (`trailers`, `check-msg`, `check --staged`, `hooks`, `report`) refuse, naming git as the need. Such a work dir has no history, so close and supersede keep files in `closed/` (D-3XCALRBERDES5HTA).

Each option that holds for every command takes its default from a `DEV_PROC_<NAME>` variable listed in one table; the command line wins. `DEV_PROC_ROOT` is the first, and must be absolute. It is a default for `--root`, not a second `dev-proc.root`.

## Why
Finding every root inside a repo relies on `git ls-files` honouring `.gitignore`; walking a plain tree for them would rebuild git's ignore rules by hand, so outside git there is one root. A global `dev-proc.root` is set for the person's repos; reading it in any directory would send work to a dir set up for something else.

The earlier objection to a variable was that it would be a second path for `dev-proc.root`, which the hooks, other shells and agents could miss (D-6RKLCVKL6N2QK75E). Making the variable mean exactly `--root` avoids that: it changes only which work dir a command runs against, never which roots the hooks and `check` cover, so a missed variable costs a wrong cwd, not a leaked id. Binding it to a directory is left to direnv or the shell rather than built into dev-proc, and one table keeps every such option on the same rule. A relative value is refused because it would point somewhere else from each subdirectory.

## Consequences
A plain directory with several work dirs below it is covered one at a time, through `--root`, `DEV_PROC_ROOT` or the cwd. Moving a work dir into a git repo later gives it history from then on; what it kept in `closed/` stays there. A future global option gets its variable by adding a table entry.
