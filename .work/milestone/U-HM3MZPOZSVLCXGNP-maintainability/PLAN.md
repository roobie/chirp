# Plan

## Steps
- [x] Owner answers the open questions in DESIGN.md (2026-11-24); move to execute
- [ ] Wave A, then B, then C, then D; each child is spawned with `new … --parent milestone/maintainability` when its wave starts
- [ ] After each wave: `ci` green on main, Evidence gets one line per closed child
- [ ] Finalize: check each criterion against Evidence, harvest, close

## Children
Units inside a wave touch different files and can run in parallel worktrees. A later wave needs the earlier one merged.

### Wave A: foundations
- **task `repo-tests`** (delivered 2026-11-24) (finding 4). `tools/test.janet` finds and runs every `*.test.janet`. First tests beside `src/chirp/update.janet`, `help.janet`, `skills.janet` and `source.janet`. The CI job `leakcheck` becomes `checks`, no longer waits for the build, fetches the `:chirp` pin (a released linux-x64 chirp, sha256 checked) and calls the driver in place of its hand list. `cut.janet` and the `chirp-release` skill move that pin after a release. The README's Building section says how to run them.
  Done when: the driver passes from a checkout with an installed chirp in under 30 seconds; CI runs it; the dev-proc tests run in it; a deliberately broken version comparison fails it.
- **task `build-guards`** (delivered 2026-11-24) (findings 3, 8). The notices assert in `build.janet`. `test/smoke/run.janet` lists its directory. The three patches move to `:patches` in `config.jdn`. The stub C source moves to a file.
  Done when: removing a `:notices` entry fails a local build with the pin's name; a new smoke file runs unlisted; all five targets build twice with matching hashes; NOTICES files are byte-identical to the previous main build's.
- **task `pin-reader`** (delivered 2026-11-24) (finding 6). `tools/build/pin.sh` and its test; the four callers use it.
  Done when: `rg "sed -n" tools test .github` finds only `pin.sh`; the test passes in `checks`; a local container build and a manual `build-image` dry read still resolve the same image digest.
- **task `hygiene`** (delivered 2026-11-24) (finding 8, status loose ends). In order:
  1. Push main.
  2. Delete the merged branches on origin: `dev-proc-no-work-dir-exit`, `dev-proc-refuse-links`, `dev-proc-status-json`, `release-env`, and `main-builds` once its one extra commit is confirmed to be the merge of pull request 13, already in main.
  3. Drop B-6XHZ4VAU236R34IH after confirming no unit carries a `## Now`.
  4. Record a backlog item for issue #21 and link it on the issue. Issue #20 is wave C's.
  5. With the owner: give `windows-cancel-tls-read` and `windows-ca-root-source` a real Scope and Next, or return each to the backlog with its notes.
  6. With the owner: the untracked `voice` skill directory either moves to `.agents/skills` with a link (D-HLIOIUOA4NCCKNJI) or is excluded locally. It is the owner's file; nobody else commits or removes it.
  7. Trim the project unit's Evidence to one line per success criterion plus the latest release; older release lines live in the changelog, the releases page and `dig`. Change the `chirp-release` skill so a release's evidence line replaces the previous release's.
  8. Update the chirp that runs the hooks on each working machine to a current build (a note for whoever works there, no repo change).
  Done when: the milestone's hygiene criterion reads true from `git branch -r`, `status` and the issue.

### Wave B: needs A
- **slice `pin-guards`** (delivered 2026-11-24) (findings 1, 2; needs `build-guards`). Versions resolved from `:tag`; `:mirrors` with the check; smoke asserts by shape; version numbers out of the README table and the docstrings.
  Done when: `rg` for each pinned version literal finds only `pins.jdn`, the changelog and fixtures; a build with a mirror's recorded hash altered fails naming the chirp file; five targets, matching hashes, smoke green.
- **task `path-helpers`** (delivered 2026-11-24) (finding 7; needs `repo-tests`). `src/chirp/paths.janet` with tests; six callers moved.
  Done when: `src/chirp` has one OS test and one directory-of-path helper; smoke green on all four native runners, windows above all.
- **task `ci-work-only`** (delivered 2026-11-24) (finding 4; needs `repo-tests`). The changes job in `ci.yml`; `pages.yml`'s plan publishes nothing for a run that built nothing.
  Done when: a `.work/`-only push to a branch shows `checks` run and the builds skipped; the same on main leaves `pages` green with nothing deployed; a code push and a release dry run still build everything; a decision records the trade.

### Wave C: needs B
- **task `c-warnings`** (finding 5; needs `pin-guards` merged, same files). `:repo-cflags` and the fixes it asks for.
  Done when: five targets build twice with matching hashes under `-Wall -Wextra -Werror` on repo sources; every exemption is data with a reason; any behaviour fix has a changelog entry.
- **task `skill-install-parent-links`** (issue #20; needs `path-helpers`). Refuse a link anywhere between the base and the skill dir; unit test and smoke case; D-TKUKHE7T3TSZWWSD superseded or extended; changelog entry; issue on the next release's GitHub milestone.
  Done when: the smoke case passes on linux and macOS (windows keeps its known exception, B-GJ36TPGEOECQYDFU).
- **task `upstream-watch`** (finding 2; `--from B-DE4OCJCKANMSZ75T`). `tools/pins/watch.janet`, its feeds data, a test of the tag ordering, and a line in the `chirp-release` preflight.
  Done when: one command prints newer tags or "current" for every pin and the feeds' new items, and exits 0 with nothing written.
- **task `pins-skill`** (findings 1, 2, 3; needs every guard above). `.agents/skills/chirp-pins/SKILL.md` with the `.claude/skills` link; both procedures; each step names its guard. `skillcheck` passes.
  Done when: a reader can bump a pin from the skill alone, which wave D tests.

### Wave D: proof
- **slice `pin-bump-proof`** (`--from B-6UDB6YVY3NJFAAMU`; jsec to `v0.2.0-interim1`, a quiet pin if it stalls). One real bump by the skill, start to finish, by an agent that did not write it. Every place the skill was wrong or silent is fixed in the skill in the same slice.
  Done when: the bump is on main with CI green on all targets, and the slice's Evidence lists the skill corrections it caused (none is an acceptable count).

## Verification
| Criterion | Shown by |
|---|---|
| Skill and one real bump | `pins-skill` merged; `pin-bump-proof` Evidence names the commit and run |
| Versions once | the `rg` output in `pin-guards` Evidence |
| Mirror change fails the build | the failing local build's message in `pin-guards` Evidence, and the proof bump if it trips one |
| Notices and smoke guards | the failing build and the unlisted check's line in `build-guards` Evidence |
| Unit tests fast and in CI | timed driver run and the `checks` job link in `repo-tests` Evidence |
| `.work/`-only push | the two run links in `ci-work-only` Evidence, or the decision's id |
| C warnings | the CI run link in `c-warnings` Evidence |
| One reader, one helper set | `rg` output in `pin-reader` and `path-helpers` Evidence |
| Issue #20 | smoke line in `skill-install-parent-links` Evidence; the issue closes with its release, noted on the project unit |
| Newer tags listed | the command's output in `upstream-watch` Evidence |
| Hygiene | `git branch -r`, `status`, the issue link and the project unit's diff in `hygiene` Evidence |
