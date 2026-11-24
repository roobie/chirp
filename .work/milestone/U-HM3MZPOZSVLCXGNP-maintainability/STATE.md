---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-24
success_criteria:
  - A committed skill gives the procedure for bumping a pin and for adding a bundled component, and Evidence names one real pin bump made by following it.
  - 'Each bundled library''s version is written once, in pins.jdn: searching the tree for a pinned version literal finds it nowhere else outside CHANGELOG.md and test fixtures.'
  - With a pin moved to a commit where upstream code that chirp mirrors (cli-main's REPL branch, run-main, spork's JSON decoder) differs, the build fails and names the chirp file to compare.
  - The build fails for a linked pin that has no :notices entry, and a new file in test/smoke runs without being added to a list.
  - Unit tests of chirp's own Janet logic run from a checkout with an installed chirp, no Docker, in under 30 seconds, and CI runs them on a released chirp pinned in pins.jdn without waiting for the build.
  - A push that changes only .work/ completes CI green without building a target, and pages stays green and deploys nothing for it; a decision records the trade.
  - Every chirp-owned C file compiles with -Wall -Wextra as errors on all five targets, with CI green.
  - Shell reads pins.jdn through one helper whose test compares it with Janet's parse of the same file, and src/chirp has one definition each of the OS test and the directory-of-path helper.
  - A smoke check shows chirp --dev-proc --install --force refusing to write through a linked parent of the skill dir, and issue 20 is closed by the release that carries it.
  - One read-only command lists, for every pin, the upstream tags newer than the pinned one.
  - origin has no merged feature branch, status shows no unit with a TODO scope, issue 21 has a backlog item, B-6XHZ4VAU236R34IH is gone, and the project unit's Evidence holds one line per success criterion plus the latest release.
---

# milestone/maintainability

## Purpose
Take what a person must remember out of maintaining chirp: bumping a pin, adding a component and testing chirp's own logic become guarded, documented and fast, with no change asked of any upstream project.

## Scope
In, each from the 2026-11-24 maintainability review:
- A pin-bump and add-a-component procedure as a repo skill, with the build enforcing what the procedure would otherwise ask a person to remember: library versions written once, mirrored upstream code detected when it moves, patches held as data.
- Build and smoke guards for the two silent gaps: a linked pin with no notice, a smoke check that is not listed.
- Unit tests of chirp's own Janet logic that run without a container build, and a CI that does not cold-build ten targets for a commit that only touches `.work/`.
- Warnings on for chirp-owned C.
- One tested reader of `pins.jdn` for shell, one set of path helpers for `src/chirp/`.
- Issue #20 (skill install writes through a linked parent directory).
- A read-only listing of newer upstream tags for every pin.
- Hygiene: stale remote branches, stalled units, untriaged issues, the stale backlog item, the project unit's Evidence, the stub C source in `build.janet`, the name of the CI job that runs the repo checks.

Out:
- Any contact with an upstream project: no ticket, issue, pull request, patch offer, mail or forum post, on GitHub or fossil. Every `needs: owner` backlog item that is a filing stays where it is (B-4XR7XIFFSIWKFM2Z, B-5AUA2Q7IH5DP2ZME, B-DJQCZSQATWOHTVWU, B-FIMDJ2SCVREG6KFT, B-G44JIOOJKJENQRMG, B-GUXSNK7MDKPJWBUW, B-HFEHNNAUWFDXTAMQ, B-MKHM34WSTBQOE626, B-RFIP6MFEVGQNJ46S, B-RS4LEZTDHMQIMIFM, B-SYLYLCOF4LQP6EQA, B-CJNYKLBSXESBPAQY, B-UKQL6LDUCA2DABBT). Reading what upstream publishes (tags, feeds, sources at a pin) is not contact and is in.
- Removing a carried workaround. That needs upstream to change first; this milestone only makes each one cheaper to carry and impossible to forget at a bump.
- New bundled modules, issue #21 (it gets a backlog item, not a fix), and anything in the vendored dev-proc skill (D-RFPRKKRRWYW54RHC).

## Context & constraints
- Origin: the review found the code itself in good shape (data-driven build, everything pinned, least-privilege workflows) and the debt concentrated in what a person must remember: at a pin bump, when adding a component, and in a feedback loop that needs a 20-minute CI run to test a pure function.
- Must stay true: reproducible double build (D-Q23RA2EVVN5LYCX7); pins in one data file (D-ZOBE3ZBK764B22JY); build logic is Janet, data is jdn (D-ANH2OMRLGDIIVVZY, D-MFWFKRO3I2W4SWIR); never fork or patch beyond the carried patches (D-ZBIADZDYXYPWLX5L); smoke checks are run by the binary under test (D-DPSCZ2KCZA4UB7YM); skills live in `.agents/skills` with a `.claude/skills` link (D-HLIOIUOA4NCCKNJI); the image is written by `tools/build/image.janet` alone, so editing it moves hashes and editing `build.janet` does not (L-ZI52YKRRPPUHTQEI); a bundled module's top-level values are computed on the linux build host, so OS tests stay functions (L-J2G76CUIQU4OWGMK).
- Already true, so not redone: the ordered JSON decoder copy is held to spork's by a parity corpus (D-ZXXSPKUCZ4IOIQPN); `leakcheck all` flagging a workflow's token variable on a host that exports that name is known and by design (L-EGSSVSI3WKR7ORNR); the three patches already fail the build loudly when they stop applying; records carry `read_if: bumping the <pin> pin`, so `find` already answers "what do I owe at this bump".
- User-visible changes are few (the #20 fix, anything the C warnings turn up), so most children add no changelog entry. They ship with whatever release follows; this milestone cuts none.
- Design and the child units are in DESIGN.md and PLAN.md.

## Next

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

## Log
- 2026-11-24 initialized
- 2026-11-24 phase initialize → execute
- 2026-11-24 BR answered the open questions: upstream excludes contact only; the .work-only CI skip is wanted; jsec v0.2.0-interim1 proves the procedure; CI checks run on a pinned released chirp; watch runs by hand
