---
status: accepted
date: 2026-10-29
read_if:
  - changing what chirp --<skill> --install overwrites
  - an install is refused or skipped
refs:
  - src/chirp/skills.janet#put-copy
  - src/chirp/skills.janet#link-or-copy
---

# D-WDOKPQ422TKMQ3RO Skill install never clobbers edits or foreign directories

## Context
The installed skill is an editable copy, and BR wants it that way: projects are expected to adapt it. People will run install again to upgrade, and some will already have something of their own at the agent path.

## Decision
A shipped file that differs is rewritten only with `--force`. An agent path that is neither this skill's link nor a matching copy of it is never replaced. Files the skill does not ship are never touched, so they never cause a refusal.

## Why
npm `skills` overwrites on reinstall. That is fine for a package nobody edits, but this skill is content people mod, so a silent overwrite would lose their work. Refusing whenever extra files exist would block the common case: the source repo keeps tests next to the shipped files, and users add notes. A copy that matches what an earlier install made counts as ours, because on Windows the link often fails and install falls back to copying. Without that rule a reinstall there would always skip.

## Consequences
An upgrade over an edited copy takes a deliberate `--force`. It rewrites only the shipped files, so the user's own files are kept. Nothing is ever deleted, which means a file the skill stops shipping stays behind until someone removes it.
