# Design

## Problem
The review of 2026-11-24 found little wrong with the code and a lot resting on memory. Eight findings, in the review's order:

1. **Carried upstream workarounds.** Three build patches, a copied JSON decoder (`src/omap/json.c`), two mirrors of private Janet code (`src/chirp/repl.janet`, `run-stdin` in `src/chirp/main.janet`), an overlay, the wasm shims and two compiler flags. Each is a cost at every pin bump, and the items that would retire them are all upstream filings, which this milestone does not make.
2. **No pin-bump procedure.** What a bump owes is spread over comments ("compare the two when the pin moves") and records. A library's version is written in up to five places: the `pins.jdn` tag, a define in `tools/build/natives.jdn`, the README table, a smoke assert and a docstring. Nothing lists newer upstream releases, the statically linked OpenSSL's included.
3. **Adding a component touches about eight files, two of them silently.** A pin with no `:notices` entry ships without its license text. A smoke file missing from the list in `test/smoke/run.janet` never runs.
4. **Slow feedback.** Nothing under `src/chirp/` is tested below a container build. CI takes about 20 minutes and cold-builds ten binaries on every push, the many pushes that only touch `.work/` included. The repo checks wait for that build, and their six commands are a hand-kept list in `ci.yml`, in a job still named `leakcheck`. The vendored dev-proc tests are not in it.
5. **chirp-owned C builds with no warning flags.** About 2,900 lines.
6. **`pins.jdn` is read by `sed` in four places with three regexes** that depend on the file's line layout.
7. **Helpers duplicated with different behaviour.** `windows?` four times in `src/`; directory-of-path helpers that differ in whether they split on a backslash, the difference behind the smoke-backslash-path fix.
8. **Minor.** The stub C source in `build.janet` is one escaped string. The project unit's Evidence and Log grow a line per release. Loose ends: an unpushed commit, merged branches on origin, two units stalled in initialize, issues #20 and #21 untracked, a stale backlog item, an untracked skill directory, an installed chirp older than the tree.

## Approach
One rule decides each case: where the build or a test can hold an obligation, it does, and the procedure document lists only what is left.

**Finding 1 and 2: make a bump mechanical.**
- *Versions once.* A define in `natives.jdn` may name the pin's version instead of spelling it; `build.janet` resolves it from the pin's `:tag` (the dotted number in it) before either the host or the cross build reads the defines. libyaml's four defines, `CHIRP_MD4C_VERSION` and `CHIRP_LEXBOR_VERSION` go this way. Smoke asserts check the shape of `(x/version)`, not a literal. The README table and the three `version` docstrings stop naming a number; the table already points at `pins.jdn`.
- *Mirrors detected.* A `:mirrors` list in `tools/build/config.jdn` names, per mirror, the pin, the upstream file, what part of it is mirrored (a named top-level form for `boot.janet`, the whole file for spork's `src/json.c`), the chirp file that mirrors it and the sha256 of that upstream text at the last comparison. `build.janet` checks each after fetching. A mismatch fails the build with the chirp file to compare and the new hash to record once compared. A whole-file hash of `boot.janet` would fire on every Janet bump and teach people to update it blindly, hence the form.
- *Patches as data.* The three `patch` calls in `build.janet` become a `:patches` list in `config.jdn` (pin, file, why, the backlog item that retires it), which the header of `build.janet` already promises ("pins, options and the native module list live in the .jdn data files"). The behaviour is unchanged: apply, or accept an already-applied tree, or fail.
- *What upstream has released.* `tools/pins/watch.janet` reads `pins.jdn` and, with `git ls-remote`, prints for each tagged pin the tags newer than its `:tag`, and for each untagged pin whether its branch head has moved. It also reads a data list of feeds, which holds llmII's fossil feeds (L-3HL3LQ37XDKWQ6HI) and so absorbs B-DE4OCJCKANMSZ75T. It writes nothing and contacts nobody. It runs from the procedure and from the release preflight.
- *The procedure.* A skill `chirp-pins` beside `chirp-release`, with two procedures: bump a pin, add a bundled component. Bump: `watch`, `$DP find "bumping the <pin> pin"` and `find --backlog`, edit `pins.jdn`, build, act on what the build refuses (patch, mirror, notice), smoke on all targets through CI, changelog. Add: the files in the order the build asks for them, with each step naming the guard that catches its omission. The skill is written last, so it documents guards that exist.

**Finding 3: two guards.**
- `build.janet` fails when a pin that a linked native or `:janet-sources`/`:janet-modules` entry builds from has no `:notices` entry reachable by `:root` or `:pin` for the target.
- `test/smoke/run.janet` runs every `*.janet` beside it except itself, sorted. A check that must not run on a target says so itself, as `tls-connect-wait` does today.

**Finding 4: tests that need no build, and a CI that builds only when it must.**
- *Tests.* Follow the convention the tools already use: `x.test.janet` beside `x.janet`. Tests for the pure logic of `update.janet` (version order, sums parsing, trust resolution), `help.janet` (section split, query grammar), `skills.janet` (relative paths, differences) and `source.janet`. A driver, `tools/test.janet`, finds every `*.test.janet` in the repo, the vendored dev-proc tests too, and runs each with the chirp that runs it. A test reaches a private function only through the module's public ones; a function is made public when it is a real seam, as `resolve-trust` already is.
- *CI checks.* The `leakcheck` job becomes `checks` and runs leakcheck, skillcheck and the driver, so a new test file needs no workflow edit. Whether it runs on the built binary (as now, after 20 minutes) or on a released chirp pinned by version and sha256 (at once, in parallel with the build) is the first open question below.
- *`.work/`-only pushes.* A first job in `ci.yml` decides whether anything outside `.work/` changed in the push. If not, the build, compare, smoke and wasm jobs are skipped and the run is green. A tag, a `workflow_call`, a new branch and a forced push always build. `pages.yml`'s plan job then has to tell a green run that built nothing from one that did, and publish nothing for the first: the site and the `latest` tree keep serving the last built commit, whose binary is byte-identical because nothing under `.work/` reaches the image.

**Finding 5: warnings as data.** A `:repo-cflags` list in `config.jdn` (`-Wall -Wextra -Werror`) is added in the cross build to every source that lives in this repo: the natives' `:repo-sources`, a target's `:repo-sources` and the generated stubs. Both compilers are pinned, so `-Werror` cannot break on a compiler update nobody chose. The host build compiles per native, not per file, and nothing it builds ships, so it stays as it is. A shim that only includes an upstream file (`src/pcre2/chartables.c`) is exempt by data, with the reason.

**Finding 6: one reader.** `tools/build/pin.sh <pin> <key>` prints one value of `pins.jdn`. `container.sh`, `container-inner.sh`, `test/smoke/run-windows.sh` and `build-image.yml` call it. `tools/build/pin.test.janet` runs it for every pin and key and compares with Janet's `parse` of the file, so a layout change that the reader cannot follow fails a test, not a build. It stays shell because the first two callers run before any Janet exists.

**Finding 7: one module.** `src/chirp/paths.janet` holds the OS test, the directory of a path (either separator on windows) and the directory of the file being compiled. `ca`, `update`, `skills`, `repl`, `main` and the https overlay use it. The OS test stays a function (L-J2G76CUIQU4OWGMK). `src/tar/tar.janet` keeps its own copies: it is a public module and takes nothing from chirp's internals. Smoke scripts keep theirs: each stands alone (D-DPSCZ2KCZA4UB7YM).

**Issue #20.** The installer refuses when any directory between the install base and the skill dir is a link, not only the skill dir (extends D-TKUKHE7T3TSZWWSD). It comes after `paths.janet` and the `skills.janet` tests, which it leans on.

**Finding 8: hygiene.** One task, listed step by step in PLAN.md. The stub C source moves to a file under `tools/build/` that `build.janet` reads; that edit does not move hashes.

## Alternatives considered
- **A checklist document alone for pin bumps.** It lost because the review's point is that the obligations are remembered, and a checklist is a longer thing to remember. It survives as the skill, holding only what no guard can.
- **Generate the README table and help text from `pins.jdn`.** More machinery than removing the numbers, and the README is read on GitHub without a build.
- **A separate file of carried workarounds.** The backlog items and the records' `read_if` lines already are that list; a second one would drift. `:patches` and `:mirrors` add only what the build itself consumes.
- **`paths-ignore` on the `ci` workflow for `.work/**`.** The run would not exist at all, so branch rules and the release preflight ("the latest `ci` run on HEAD is green") would have nothing to read, and `pages` would never hear of the commit. A green run that built nothing keeps every reader working.
- **Reuse the previous commit's artifacts for a `.work/`-only push so the site still redeploys.** It moves only the commit in the footer and costs cross-run artifact lookups with retention limits.
- **Unit tests in `test/smoke/`.** Smoke checks are black-box and run on every target by the binary under test; these are white-box and need the source tree, not a target.
- **Warnings on the pinned libraries too.** Their warnings are upstream's to fix, and this milestone asks nothing of upstream.
- **Rewrite the shell `sed` in Janet.** `container.sh` runs on a host with only Docker, and `container-inner.sh` runs before janet is built.
- **A scheduled workflow for `watch` that opens an issue.** Left as an open question; the script comes first and is useful by hand.

## Risks & open questions
- **Open: what "upstream" excludes.** Read here as "no contact": reading tags, feeds and sources is in, filing or offering anything is out. If reading is out too, `upstream-watch` drops and the last success criterion with it.
- **Open: which chirp runs the CI checks.** Built binary (dogfood, late) or a pinned released chirp (early, one more pin and a bootstrap dependency on our own releases). Default if unanswered: keep the built binary and add the driver; move later if the wait hurts.
- **Open: is the `.work/`-only skip wanted.** It changes what a green `ci` run means, and the site's footer would lag behind main's tip for such commits. If not, record the decision and close that child unbuilt; the criterion allows it.
- **Open: which pin proves the procedure.** jsec to `v0.2.0-interim1` (B-6UDB6YVY3NJFAAMU) is wanted anyway and exercises both patches, but its windows behaviour may stall the milestone. A quiet tagged pin (md4c, lexbor) proves less and cannot stall. Default: jsec, falling back to a quiet pin if jsec is not green within its slice.
- **Open: schedule `watch` in CI or run it by hand.**
- **Risk: `-Werror` finds real bugs.** Then the fixes are user-visible and need changelog entries; a fix that changes behaviour gets its own task.
- **Risk: the notices guard is wrong for a pin whose license ships from this repo** (jsec, SQLite). It must match on `:pin` as well as `:root`; the current data is the test.
- **Risk: mirror forms move or are renamed upstream.** The check then fails as "form not found", which is the right outcome, with a message that says so.
- **Risk: the branch rules on main are unknown to the agents' token** (the protection API answers 403). The owner checks that a `ci` run with skipped jobs still satisfies them before the skip merges.
- **Risk: wave B's `pin-guards` and wave C's `c-warnings` both edit `build.janet` and `config.jdn`**, as does wave A's `build-guards`. They are in different waves for that reason.
