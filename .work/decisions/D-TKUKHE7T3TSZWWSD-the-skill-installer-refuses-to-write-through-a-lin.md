---
status: accepted
date: 2026-11-15
read_if:
  - changing what chirp --dev-proc --install writes through or skips
  - a skill dir is a link into a checkout
refs:
  - src/chirp/skills.janet#linked?
  - test/smoke/dev-proc-install.janet
---

# D-TKUKHE7T3TSZWWSD The skill installer refuses to write through a link at the skill dir

## Context
The installer follows a link at the skill dir (D-NJRZA5YYOCND3X3E lays out `.claude/skills/<name>` as a link to the canonical copy). A user who points `.agents/skills/<name>` at a checkout of the skill, to work on it in place, found that a forced install rewrote the checkout's shipped files with the binary's older copy.

## Decision
When the canonical skill dir (`.agents/skills/<name>`) is itself a link, whatever its target (a checkout, a directory inside the install base, or nothing), the install refuses, with or without `--force`, and writes nothing. The message says it is a link and that the install would write into its target; for a link to an existing directory it says to update that directory's own source or remove the link, for a dangling one to remove the link. A link above the skill dir (`.agents`, `.agents/skills`) stays allowed, and so does the installer's own link at `.claude/skills/<name>`. The check does not run on Windows.

## Why
The installer only ever makes the canonical dir as a real directory, so a link there was made by the user, and the only reason to make one is to work on the skill in place. A test of where the link leads does not work: with `-g` the base is the home directory, which holds the checkouts, so a checkout lies inside it. `--force` means "rewrite my edited copy", not "rewrite whatever a link leads to", so the guard does not yield to it. A dangling link is refused too, since nothing proves where an install would end. The tradeoff is that a link above the skill dir, as dotfiles managers make, is still followed, so such a store can be overwritten by a forced install; refusing those would break a common layout, and the skill dir there stays a real directory the installer made. The alternatives were to ask for a flag to write through (one more option to get wrong) and to leave it to a warning (the checkout is already overwritten by then).

## Consequences
Extended by D-Z6BXK3LRIQKGMJBN (2026-11-24): a link above the skill dir is refused too. Builds from this change refuse; older builds still overwrite, so a link to a checkout is only safe once the installed chirp has this change. A user who wants the link updated runs the update in the checkout, not the installer. On Windows, where the check does not see links, the installer behaves as before (B-GJ36TPGEOECQYDFU).
