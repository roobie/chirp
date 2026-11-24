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
Every child is delivered. One criterion is open: issue 20 closes with the release that carries its fix, and cutting a release is outside this milestone. Finalize after the next release (chirp-release skill), or once BR rewords that criterion.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- pin-reader (U-CIOASS53XGJOLRCU) delivered: tools/build/pin.sh is the only shell reader of pins.jdn, held to Janet's parse by pin.test.janet (40 values); ci run 45371721511 green.
- repo-tests (U-BTEXJZKNTIOO6G4L) delivered: chirp tools/test.janet runs every *.test.janet (13 files; chirp's own 10 in about 1 s with an installed chirp), and CI's checks job runs them on the :chirp pin in 35 s without waiting for a build (run 45371721511, D-235CO5X6BG3S743P).
- build-guards (U-YT7LBKVS4KWB6D6O) delivered: the build refuses a carried pin with no notice (it found jsec's missing from chirp.wasm, L-JHSEB5OVK5G34PN6), smoke runs every check beside its driver, patches are :patches data, the stub C source is a file; linux-x64 binary unchanged by the change, run 45371721511 green with released targets' NOTICES equal to 0.13.1's.
- hygiene (U-NSJDS3SYUX7Y4CO3) delivered: main pushed and origin has only main; stale backlog item gone; issue 21 is B-IRCVVXCJX6GVYOES; the two stalled windows tasks are back in the backlog (D-OYMZ5GI46ZE4M5QR); project Evidence is one line per criterion plus the latest release. Wave A is complete.
- pin-guards (U-6YPX4V6UF4GJLDIE) delivered: version defines resolve from the pin's :tag (binary identical with only that change) and no pinned version literal is left outside pins.jdn; :mirrors stops the build when cli-main, run-main or spork's json.c changes upstream, naming the chirp file and the hash to record; run 45384710519 green.
- path-helpers (U-P5BSKWOVDJYIQFHD) delivered: src/chirp/paths.janet holds the one OS test and the one directory-of-path helper under src/chirp, with tests; smoke green on the four native runners in run 45384710519.
- ci-work-only (U-CLMO7BUNR7R6Z4GJ) delivered: a .work/-only push gets a green ci run in about a minute with the builds skipped (run 45389524689 on main) and pages publishes nothing for it (run 45389639071); code pushes, new branches and the release dry run build everything (D-SBFT5Y7OGHMOVIY6). Wave B is complete.
- c-warnings (U-DF6RRQQVXJN6OWDF) delivered: repo C and the generated stubs compile with -Wall -Wextra -Werror in the shipped build; two findings fixed, none changed behaviour; no file is exempt, miniz's unused statics are excused at gzip.c's include; run 45425777802 green.
- skill-install-parent-links (U-X67ZX3RLNIKYEGJB) delivered: a link between the install base and the skill dir is refused, forced or not, with unit and smoke cases (D-Z6BXK3LRIQKGMJBN, issue 20 on GitHub milestone 0.13.2); run 45425777802 green on linux and macOS.
- upstream-watch (U-RSCO6736MTAJIN76) delivered: chirp tools/pins/watch.janet lists newer tags, moved branches, zig releases and the feeds' recent items, reading only; its ordering is tested; the release preflight runs it.
- pins-skill (U-3TUKHKIY6OR6IOHO) delivered: .agents/skills/chirp-pins/SKILL.md holds both procedures, each step with its guard or marked by hand. Wave C is complete.
- pin-bump-proof (U-U5QZHBUMGYEWICHC) delivered: jsec moved from 9b57288 to v0.2.0-interim1 (commit 195deb4) by a separate agent following the chirp-pins skill; the patch guard stopped the first build, both windows patches and the reconstructed license were retired, and five corrections went into the skill; ci run 45449392321 on main green on all targets. Wave D is complete.

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
