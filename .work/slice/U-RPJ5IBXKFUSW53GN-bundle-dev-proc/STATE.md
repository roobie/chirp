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
Dogfooded: the skill's source of truth is now `.agents/skills/dev-proc`, and `.claude/skills/dev-proc` is the link `chirp --dev-proc --install` made. Waiting on CI (run 40791461184 for 2ec89fb, then the dogfood commit).

## Next
- CI green on every target (windows takes the copy fallback; untested so far), then check criteria and finalize

## Evidence
- 2026-10-28 local linux-x64 container build: smoke suite all 17 checks pass, dev-proc-install included (layout, relative link, installed copy runs init+status, up-to-date, refuse, --force, foreign dir, --copy, -g). CI not yet run.
- 2026-10-28 dogfood: git mv to .agents/skills/dev-proc, rebuilt, `chirp --dev-proc --install` in the repo → "up to date" (3 test files left in place, not shipped) + "linked .claude/skills/dev-proc -> ../../.agents/skills/dev-proc". Then smoke (all pass), the 3 dev-proc test files (pass), dev-proc check (ok), site build + site check (11 pages ok).

- 2026-10-28 CI run 40791461184 (2ec89fb): every build, compare, leakcheck and smoke green except smoke windows-x64, where dev-proc-install's byte compare met a CRLF checkout; the test now compares text without CR.

## Harvest
- [ ] decision: --install refuses to overwrite a modified copy or replace a foreign .claude/skills/dev-proc, unlike npm skills which overwrites — content is moddable, so user edits are not clobbered silently; files it does not ship never refuse an install (they are never touched, and the source repo keeps its tests beside the shipped files)
- [ ] decision: this repo's skill lives in .agents/skills/dev-proc, the same layout the installer makes, with .claude/skills/dev-proc a committed link
- [ ] decision: install mirrors npm skills' .agents/skills canonical dir + per-agent links
- [ ] learning: os/spawn with :e replaces the whole environment (no PATH/HOME); merge (os/environ) to override a few vars

## Log
- 2026-10-28 initialized
- 2026-10-28 phase initialize → execute
