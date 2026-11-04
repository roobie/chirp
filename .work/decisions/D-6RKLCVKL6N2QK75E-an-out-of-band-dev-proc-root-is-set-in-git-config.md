---
status: accepted
date: 2026-11-04
read_if:
  - keeping personal dev-proc work out of a team repo
  - changing how dev-proc finds its roots
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#configured-root
  - .agents/skills/dev-proc/scripts/dev-proc.janet#root-desc
---

# D-6RKLCVKL6N2QK75E An out-of-band dev-proc root is set in git config and kept out of the hooks

## Context
BR wants to run dev-proc on his own, outside what the team sees: a work dir with its own name and place, kept out of the repo, the commits and the hooks.

## Decision
The out-of-band root is named by `git config dev-proc.root`. A root outside the repo, or git-ignored inside it, is out-of-band: the hooks and `trailers` skip it, and `close` names no trailer for it. Its refs resolve against the repo top.

## Why
The setting is personal and specific to the host, so it can't be committed: the repo has to stay free of host-specific values. A committed config file would put it in the repo. An environment variable would be missed by the hooks, by other shells and by agents. Git config is clone-local, the hooks can read it, it can be set globally or per repo through includeIf, and git already expands `~`. Deciding out-of-band from where the root sits, not from a flag, means a team root can never be skipped by mistake. `check` warns when a configured root would be committed.

## Consequences
Private unit ids never appear in team commits, so `dig` on them works only when the root is in a git repo of its own. Renaming `.work` for a whole team is a different need and would take a committed setting.
