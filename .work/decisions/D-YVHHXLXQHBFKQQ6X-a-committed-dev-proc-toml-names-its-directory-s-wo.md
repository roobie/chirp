---
status: accepted
date: 2026-11-04
read_if:
  - renaming a dev-proc work dir
  - changing how dev-proc finds its roots
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#work-name
  - .agents/skills/dev-proc/scripts/dev-proc.janet#read-config
---

# D-YVHHXLXQHBFKQQ6X A committed .dev-proc.toml names its directory's work dir

## Context
BR wanted a repo, or one directory in a monorepo, to use a name other than `.work` for every clone. A person's own dir was already handled by `git config dev-proc.root` (D-6RKLCVKL6N2QK75E).

## Decision
An optional `.dev-proc.toml` in a directory sets `work_dir`, one directory name, for that directory only. The file is meant to be committed. A git-ignored copy is skipped, with a warning. Any key but `work_dir` is an error. `dig` searches the whole repo by id instead of the current work dir.

## Why
A shared name has to travel with the repo, so it lives in a file in the repo. Git config stays the home of personal settings. Covering only its own directory keeps a root's project directory where it already was, and each subproject decides for itself. Skipping ignored copies keeps every command's view the same: the directory walk could see such a file but `git ls-files` could not. It also stops a private file from silently hiding the team's `.work`. A single path segment keeps location out of this setting, and strict keys mean a typo cannot silently do nothing. TOML is bundled with chirp (tomlin), so the file costs no parser. Ids are unique, so a repo-wide `dig` loses nothing and still finds history from before a rename.

## Consequences
A `.work` left beside a renamed dir is no longer read; `check` warns about it. A broken `.dev-proc.toml` stops every command, the hooks included, until it is fixed.
