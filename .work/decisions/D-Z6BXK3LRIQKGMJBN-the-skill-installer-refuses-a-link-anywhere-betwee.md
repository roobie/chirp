---
status: accepted
date: 2026-11-24
read_if:
  - changing what chirp --dev-proc --install writes through or skips
  - a skill dir or a directory above it is a link
refs:
  - src/chirp/skills.janet#linked-above?
  - test/smoke/dev-proc-install.janet
  - src/chirp/skills.test.janet
---

# D-Z6BXK3LRIQKGMJBN The skill installer refuses a link anywhere between the install base and the skill dir

## Context
D-TKUKHE7T3TSZWWSD refuses a link at the skill dir and allows one above it (`.agents`, `.agents/skills`), for the sake of dotfiles managers. Issue 20 showed the cost: when such a link ends in a checkout, `install --force` rewrites the checkout's shipped files, which is the damage the first guard was made to stop.

## Decision
The install refuses, forced or not and with nothing written, when any directory between the install base and a directory it would write files into is a link: `.agents` or `.agents/skills` for the canonical copy, and with `--copy` the agent directories' parents. The base itself and everything above it are not looked at. The agent directory's parent may still be a link when only a link is made there (`.claude/skills` pointing at `.agents/skills`, as this repo has). This replaces the "a link above stays allowed" part of D-TKUKHE7T3TSZWWSD; the rest of it stands.

## Why
A link above the skill dir leaves the base exactly as one at the skill dir does, and the installer cannot tell a dotfiles store from a checkout: both are directories somewhere else that hold the skill. Of the two mistakes, refusing a store costs one manual step, while writing through to a checkout loses work. Comparing the real path with the spelled one from the home directory down, as the issue suggests, would also refuse a home directory that is itself reached through a link, which is common and harmless; so only the part below the base is checked.

## Consequences
- A `.agents` kept in a dotfiles store through a link no longer installs. The message names the link and says to put the skill there from its own source or make the directory real.
- Windows is unchanged: the check does not see links there (B-GJ36TPGEOECQYDFU).
- Builds before this change still write through a linked parent.
