---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-28
success_criteria:
  - chirp --dev-proc --install, run in an empty directory with no repo checkout, writes .agents/skills/dev-proc (SKILL.md, scripts, templates; no tests) byte-identical to the repo's skill, and .claude/skills/dev-proc is a relative symlink to it
  - the installed copy runs (chirp .claude/skills/dev-proc/scripts/dev-proc.janet init, then status) with no other files present
  - -g installs under the home directory instead; --copy writes a real copy into .claude/skills instead of a link
  - re-running install is a no-op on an identical copy, refuses a modified copy unless --force, and never deletes a .claude/skills/dev-proc that is not its own link
  - a smoke test covers install, re-install and the refusals, and passes on a CI build
  - chirp -h and chirp help list --dev-proc; CHANGELOG has an entry
---

# slice/bundle-dev-proc

## Purpose
GitHub issue #2: someone with only the chirp binary can install the dev-proc skill into a project, without a checkout of this repo.

## Scope
In: baking the skill's files into the image at build time; `chirp --dev-proc` (usage) and `chirp --dev-proc --install [-g] [--copy] [--force]`; the npm `skills` layout (canonical copy in `.agents/skills/<name>`, agent dirs link to it); SKILL.md's `DP=` line made correct for a global install; smoke test, help, changelog.
Out: running dev-proc from the binary itself (BR chose a full editable copy); agents other than Claude Code beyond what the link list in chirp.jdn names; issue #3 (flag-style subcommands in general).

## Context & constraints
- BR's answers (2026-10-28): install copies the full skill, not a stub; layout follows npm `skills` (vercel-labs/skills src/installer.ts): base is cwd, or home with -g; link target relative to the link dir's realpath; Windows gets a junction/absolute path; copy when linking fails.
- Source of truth stays `.claude/skills/dev-proc/` in this repo; the build reads it like help topics (D-6MHEZUS5HUJXWV6A, baked-in text). The build container mounts the whole repo read-only, so the path is reachable.
- Which files ship and which agent dirs get links are data in chirp.jdn (content is moddable), not code.
- Image must stay reproducible (D-Q23RA2EVVN5LYCX7): read files in sorted order.
- The installed skill needs chirp's bundled yaml/omap/sqlite3 (L-NYRT2RGVVAXTFIOF) — fine, chirp runs it.

## Now
Implementation committed; waiting on CI for the other targets (windows takes the copy fallback; untested so far).

## Next
- CI build green on every target, then check criteria
- dogfood (BR, 2026-10-28): install into this repo, so the skill's source of truth moves to `.agents/skills/dev-proc` with `.claude/skills/dev-proc` as the link; then repoint chirp.jdn's `:skills`, tools/hooks/*, and anything else naming the old path

## Evidence
- 2026-10-28 local linux-x64 container build: smoke suite all 17 checks pass, dev-proc-install included (layout, relative link, installed copy runs init+status, up-to-date, refuse, --force, foreign dir, --copy, -g). CI not yet run.

## Harvest
- [ ] decision: --install refuses to overwrite a modified copy or replace a foreign .claude/skills/dev-proc, unlike npm skills which overwrites — content is moddable, so user edits are not clobbered silently
- [ ] decision: install mirrors npm skills' .agents/skills canonical dir + per-agent links
- [ ] learning: os/spawn with :e replaces the whole environment (no PATH/HOME); merge (os/environ) to override a few vars

## Log
- 2026-10-28 initialized
- 2026-10-28 phase initialize → execute
