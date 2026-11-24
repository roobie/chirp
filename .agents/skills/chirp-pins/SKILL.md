---
name: chirp-pins
description: How to move a pin in pins.jdn to a newer upstream version and how to add a bundled library or module to chirp - what to run, in which order, and which build guard or smoke check catches each thing you could forget. Use when the user says "bump janet", "update openssl", "move the jsec pin", "is anything newer upstream", "what has upstream released", "add a module", "bundle a library", or when a build stops on a patch, a mirror, a notice or a version define.
---

# chirp-pins

Everything chirp is built from is pinned in `pins.jdn`, and nothing else in the repo names a version. Two procedures live here: moving a pin, and adding a bundled component. Most of what either one obliges you to do is held by the build or by a check, which stops and says what to do; each step below names its guard. The steps without a guard are marked **by hand**, and those are the ones to take care over.

Read these first; this skill applies them and does not override them:
- `$DP find "bumping the <pin> pin"` and `$DP find --backlog "<pin>"` list the decisions, learnings and waiting items for that pin. A backlog item often says what to check or drop at the next bump.
- D-235CO5X6BG3S743P: the `:chirp` pin is not a build input. `tools/release/pin-chirp.janet` moves it, in the `chirp-release` skill.
- L-ZI52YKRRPPUHTQEI and L-2H7SFLEMCU2MPRZN: what moves the binary's hash and what must not.
- L-JHSEB5OVK5G34PN6: Janet source is in every target's image, so a license can be limited to some targets only for C that is purely linked.

```sh
DP="chirp .agents/skills/dev-proc/scripts/dev-proc.janet"
```

Nothing here contacts an upstream project. Reading tags, feeds and sources is all a bump needs; whether to report something upstream is the owner's call, and such items wait in the backlog marked `needs: owner`.

## Moving a pin

A bump is a unit of work: a task for a quiet library, a slice when patches, mirrors or behaviour are in play (Janet, spork, jsec, OpenSSL). One pin per unit, so that a red build has one cause.

1. **See what there is.** `chirp tools/pins/watch.janet` prints, for every pin, the tags after the pinned one or whether its branch moved, and the recent items of the feeds in `tools/pins/watch.jdn`. It only reads.
2. **Read upstream's notes** between the old and the new version: its changelog or release notes, and for a branch pin the commits (`git log <old>..<new>` in `out/<dir>/src/<pin>` after a fetch). Build checkouts are shallow: explicitly fetch both commits before comparing (`git fetch origin <old> <new>`); fetch the tag too if using its name. A tag merged onto another branch can include unrelated history: use `git diff <old> <new>` to establish the actual source changes. You are looking for changed behaviour of something chirp documents, removed functions, new source files, and a changed license. **By hand.**
3. **Edit `pins.jdn`**: the pin's `:tag` and `:commit`. The commit is what is fetched and the tag is what the version is read from, and nothing checks that they agree, so take both from one place (**by hand**):
   ```sh
   git ls-remote <url> 'refs/tags/<tag>*'
   ```
   An annotated tag shows twice; the commit is the line ending in `^{}`. A pin without a tag gets only a new `:commit`. zig has a `:version`, a `:url` and the tarball's `:sha256`, which the build checks after the download.
4. **Build one target** and act on what the build refuses. It stops at the first problem, so repeat until it runs through:
   ```sh
   sh tools/build/container.sh linux-x64 out/bump
   ```
   - *"patch … fits neither the pinned nor the patched …"*: a patch under `:patches` in `tools/build/config.jdn` no longer applies. Read its `:until` backlog item. If upstream has the change, delete the patch file, its entry and the item (only once all work in a shared item is settled). Run `$DP check` and update durable `refs` to surviving code or tests when deleting a patch; retain their historical reasoning. If not, redo the patch against the new source (`git diff` in the checkout under `out/bump/src/<pin>`) and keep the entry.
   - *"… is not the text that … was last compared with"*: upstream changed code that a file here carries a changed copy of (`:mirrors` in `config.jdn`). Diff the old and new upstream text, bring the named chirp file in step where the change matters, then record the hash the message gives. Recording the hash without reading the diff defeats the check.
   - *"… has N top-level forms starting with …"*: upstream renamed or moved a mirrored form. Find where it went and correct the entry's `:form`.
   - *"… carries the … pin, but :notices … has no entry"*, or *"notices: …"*: the license file moved or is new. Correct the entry's `:path` under `:notices`.
   - *"… asks for the version of the … pin, but pins.jdn gives it no :tag"*: a define in `tools/build/natives.jdn` reads the version from the tag; a pin that feeds one must keep a tag.
   - *"missing source …"*, or a compile or link error in a pin's file: upstream added, removed or renamed sources. Correct `:sources`, `:skip`, `:includes` or `:defines` for that native in `natives.jdn`.
   - A warning-as-error in a file under `src/`: chirp's own binding no longer matches the library's API. Fix the binding.
5. **Read the license** even when the build is quiet: `git diff <old> <new> -- 'LICENSE*'` in the checkout (quote the glob so the shell does not expand only existing files). A changed license is the owner's decision before anything ships. When upstream adds its own text for the existing license, replace any reconstructed repo notice: set both `:root` and `:path` to the pin's license and remove the obsolete local file and comment. An existing local notice passes the guard, so this migration is **by hand**.
6. **Smoke locally:** `out/bump/bin/chirp test/smoke/run.janet`. Then `chirp tools/test.janet src tools`.
7. **Look for what no check sees** (**by hand**):
   - A chirp help topic or docstring that describes behaviour upstream changed (`rg <function> src/chirp/help`).
   - A workaround that the new version makes unnecessary: `$DP find --backlog "<pin>"`, and `rg -n "<pin>" tools/build/config.jdn` for flags and comments that name a reason.
   - For Janet: `src/chirp/repl.janet` and `src/chirp/main.janet` mirror parts of `boot.janet` (the mirror check covers them), and `tools/build/image.janet` relies on the image's layout.
   - For OpenSSL, zig or the `:image`: these change every byte. Nothing but the double build and smoke on every target tells you it works.
8. **Changelog:** a user-facing line under `## Unreleased` naming the library and both versions, and anything a user would notice. The README's table names no version.
9. **Push the branch and let CI judge.** Five targets are built twice and compared, and smoke runs on the four native runners; a bump is not done on a local linux build. Windows and macOS failures show only here. Watch with `gh run list --branch <branch>` and `gh run watch <id> --exit-status --interval 30`. If a job is cancelled with no steps or logs, inspect its check-run annotations (`gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations`): runner acquisition/capacity failures are infrastructure, not pin failures. Retry those with `gh run rerun <id> --failed`, then watch again; do not change code to mask them.
10. **Record the CI run id and result** in Evidence, and remove any `tkt=` feed in `watch.jdn` and any backlog item the bump has settled. Close the unit through dev-proc only when its criteria and the owner's handoff instructions permit; a branch-only proof may stay in execute for owner review.

Changing `:image` or `tools/build/packages.txt` also needs the `build-image` workflow run by hand and its digest put into `pins.jdn` as `:build-image`; the workflow file says how.

If a bump cannot go green within its unit, put the pin back, and record what stopped it as a backlog item or, if it will keep stopping the next attempt, a learning.

## Adding a bundled component

A component is a native module (C, from a pin or from this repo), a Janet module, or both. Decide first what chirp owns: a binding written here lives under `src/<name>/` and is chirp's to keep; a module taken whole from a pin is upstream's. The order below is the order in which the build asks for things.

1. **The pin**, if the source is upstream's: an entry in `pins.jdn` with `:url`, `:commit` and, when upstream tags, `:tag`.
2. **The build entry.**
   - A native: an entry in `tools/build/natives.jdn` (`:name`, `:pin`, `:sources`, and for a binding here `:repo-sources`). Take a version from the pin with `:pin-version` in `:defines`, never as a number. Files under `:repo-sources` compile with `-Wall -Wextra -Werror`.
   - Janet modules from a pin: `:janet-sources` in `tools/build/config.jdn`, or `:janet-modules` for a single file or a module in this repo.
3. **The module list:** its name in `:modules` in `src/chirp/chirp.jdn`, and in `:import-aliases` any short name people will try.
4. **The license:** an entry under `:notices` in `config.jdn`. *Guard: the build fails for a pin that is compiled or carried without one.* Limit it to some targets only for purely linked C.
5. **The goal:** a section in `src/chirp/help/tasks.md` whose example imports the module. *Guard: the build fails when the goals topic names no goal for a bundled module.* Add a topic of its own under `src/chirp/help/` when the module needs more than one example. Every example in the help is run by the `help-examples` smoke check.
6. **The smoke check:** `test/smoke/<name>.janet`, standing alone and printing `ok …`. *Guard: `run.janet` runs every file beside it, so a new file needs no list; but nothing fails when the file is missing.* **By hand:** write it. A check that cannot run on a target says so itself and exits 0. A version is checked by shape, not by number.
7. **Where people read about it** (**by hand**): the README's "What it bundles" table, without a version; `.github/release-notes.md`, the "It bundles …" sentence; `## Unreleased` in `CHANGELOG.md`; and `:help-source` in `chirp.jdn` when its sources lie somewhere no rule there covers.
8. **Build every target**, not only linux: `for t in linux-x64 linux-arm64 macos-arm64 windows-x64 wasm32-wasi; do sh tools/build/container.sh $t out/$t; done`, or push and let CI do it. A new native often needs a define or a skipped file on one of them (`:targets` on the native, `:pin-cflags` on the target), and the wasm target stubs what it cannot link.
9. **Upstream to watch:** when the source has feeds or tickets worth following, add them to `tools/pins/watch.jdn`.

A component that copies and changes upstream code, instead of building it as it is, also gets a `:mirrors` entry, so that the copy is looked at when upstream changes.
