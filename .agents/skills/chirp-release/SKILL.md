---
name: chirp-release
description: The full procedure for releasing chirp - preflight, cutting the version with tools/release/cut.janet, the maintainer's tag, monitoring the release, pages and close-milestone workflows, verifying the published release and self-update, and moving main to the next -dev. Use when the user says "release", "cut X.Y.Z", "we're about to publish", "tag a release", "is it ready to tag", "monitor the release", "bump to the next -dev", or when a release run fails.
---

# chirp-release

A release is a `v*` tag pushed by a maintainer. `.github/workflows/release.yml` runs the full CI on the tagged commit, ships those exact bytes, signs `SHA256SUMS` with the key of the `release` environment, creates the GitHub release and closes the milestone. `pages.yml` then rebuilds the site. Every installed `chirp --self-update` picks the release up, so a bad release reaches users. The procedure exists to avoid that.

Read these first; this skill applies them and does not override them:
- D-MB5WIOASYBDI7AEB: the tag is a human step. Tooling edits files only and never tags, commits or pushes a tag.
- D-2UB7VI5YR6ZBQ4FD: main carries `X.Y.Z-dev`; a release drops the suffix, then main moves to the next `-dev`.
- D-DYWSJTLDO6S5DQDR: the release notes are the version's `CHANGELOG.md` section, read from the shipped binary.
- D-44BH6MURMXC5JTOB: self-update trusts only the signed `SHA256SUMS`.

`$DP find "cut a release"` lists them and any newer ones.

```sh
DP="chirp .agents/skills/dev-proc/scripts/dev-proc.janet"
```

Who does what: the agent does every step except **tagging and pushing the tag**, which the maintainer (BR) does. Ask before re-running a failed job or changing anything already published.

## 1. Preflight

All of these must hold before the cut. Report each one; don't stop at the first failure.

1. **Tree:** on `main`, clean, equal to `origin/main` (`git fetch && git status -sb`). `cut.janet` refuses otherwise.
2. **Version:** `src/chirp/chirp.jdn` holds `:version "X.Y.Z-dev"`, and no `vX.Y.Z` tag or release exists yet (`git ls-remote --tags origin vX.Y.Z`, `gh release list`).
3. **Changelog:** `## Unreleased` in `CHANGELOG.md` is non-empty, user-facing, and covers everything merged since the last tag (`git log vPREV..HEAD --oneline`). Merge duplicate or overlapping entries now, in their own commit.
4. **Open work:** `$DP status` shows no slice or task that should be in this release still open. A finalized unit has its closing commit on main.
5. **CI:** the latest `ci` run on HEAD is green (`gh run list -L 5`).
6. **Milestone:** the GitHub milestone is titled exactly `X.Y.Z` (no `v`) and holds **every** issue this release fixes. close-milestone closes only issues *in* the milestone, so a fixed issue left outside stays open (`gh issue edit N --milestone X.Y.Z`). Without a milestone the job closes nothing and still passes.
7. **Release notes boilerplate:** if this release bundles a new library or module, `.github/release-notes.md` names it ("It bundles …").
8. **Users who cannot self-update:** if a fix is to self-update itself (for example #10, windows HTTPS), the changelog entry says those users must download by hand. Repeat it on the issue if useful.

Optional: a manual run of `release` (`gh workflow run release.yml --ref main`) does everything except create the release: it builds, packages, signs and attests, with the Unreleased section standing in for the notes. It signs with a throwaway key made for the run, so it never proves the stored secret.

## 2. Cut

```sh
chirp tools/release/cut.janet            # or: cut.janet X.Y.Z to choose a version other than the -dev one
```

It checks everything before it writes, so a refusal leaves the tree untouched. It:
- drops `-dev` in `src/chirp/chirp.jdn`,
- renames `## Unreleased` to `## X.Y.Z` with `Released <today>.`,
- updates the `# chirp X.Y.Z ` example in `README.md` (paths in `tools/release/cut.jdn`).

Then log it on the project unit (`$DP note <project> log "cutting X.Y.Z: …"`) and commit with the trailers from `$DP trailers`:

```
release: X.Y.Z

<what the release holds and why it ships now>

Work: U-…
```

Push, and wait for that commit's `ci` run to go green.

## 3. Tag (maintainer)

Hand BR the exact commands, with the release commit's sha:

```sh
git tag -a vX.Y.Z -m "chirp X.Y.Z" <sha>
git push origin vX.Y.Z
```

The tag is **annotated, not GPG-signed**: no chirp tag is signed and nothing verifies a tag signature. What users verify is `SHA256SUMS.sig`, signed in CI with the `CHIRP_RELEASE_SIGNING_KEY` secret. Don't suggest `-s`; a host without the gpg key fails with "No secret key".

## 4. Monitor

```sh
gh run list -L 3                                   # find the release run for vX.Y.Z
gh run watch <id> --exit-status --interval 30
gh run view <id> --log-failed                      # on failure
```

The jobs, in order: `ci` (builds every target twice, compares sha256, smoke-tests each on its own runner) → `package` (waits for the owner's approval of the `release` deployment, then checks the tag matches the binary's version, finds the changelog section, writes `SHA256SUMS`, signs and verifies it) → `publish` (attests, then `gh release create --verify-tag`) → `close-milestone`.

Failures and what to do:
- **`tag … does not match the binary's version`, or `CHANGELOG.md has no '## X.Y.Z' section`:** the wrong commit was tagged, or the cut was not done. Nothing is published. The tag has to move. That is BR's call; propose deleting it and tagging the right commit.
- **A 5xx from the GitHub API in `publish`** (seen at 0.8.0: `HTTP 500 …/releases`): GitHub's fault. First check no draft or partial release was left (`gh api repos/{owner}/{repo}/releases --jq '.[]|"\(.tag_name) draft=\(.draft) assets=\(.assets|length)"'`), delete one if it was, then `gh run rerun <id> --failed`. A rerun of failed jobs also reruns the jobs that depend on them.
- **A signing or verify failure in `package` on a tag:** the secret does not match `src/chirp/release-key.pem`. Stop and tell BR; never ship around it. On a manual run it signs with a throwaway key, so the same failure there is a bug in the signing code, not a wrong secret.
- **A `ci` failure on the tag when main's CI was green:** treat it as a real failure (flaky or not), diagnose before any rerun.

After `release` succeeds, `pages` starts on its own (`workflow_run`); watch it too.

## 5. Verify

Record each result; these are the release's evidence.

1. **The release:** `gh release view vX.Y.Z --json name,isDraft,assets,url` gives `chirp X.Y.Z`, not a draft, 10 assets (four binaries, four `NOTICES-<target>.txt`, `SHA256SUMS`, `SHA256SUMS.sig`), marked Latest in `gh release list`. Check that the notes show the changelog section.
2. **Milestone:** each fixed issue is closed with a "Shipped in chirp X.Y.Z" comment, and milestone `X.Y.Z` is closed (`gh api 'repos/{owner}/{repo}/milestones?state=all'`).
3. **Self-update** from the previous release, in a temp dir:
   ```sh
   gh release download vPREV -R roobie/chirp -p chirp-PREV-linux-x64
   chmod +x chirp-PREV-linux-x64
   ./chirp-PREV-linux-x64 --self-update     # updated chirp PREV -> X.Y.Z
   ./chirp-PREV-linux-x64 --version         # chirp X.Y.Z …
   ```
4. **Pages:** the `pages` run after the release is green.

## 6. Next -dev

```sh
chirp tools/release/cut.janet --next     # X.(Y+1).0-dev and an empty ## Unreleased; or --next X.Y.Z
```

In the same commit, update the project unit's `STATE.md` with `$DP note <project> <section> "…"`, not by scripting the file. `now` and `next` replace their section; `evidence` and `log` append one line, and `log` adds today's date.
- **now:** `X.Y.Z is published (<date>) and main carries <next>-dev`, with what it held and what close-milestone closed.
- **next:** the current list without the items the release settled.
- **evidence:** `Release X.Y.Z: <url> (run <id>, <sha>) …` with the checks from step 5 and any rerun.
- **log:** `X.Y.Z published by BR's tag; release run <id> green, …; main moves to <next>-dev`.

Commit `main moves to <next>-dev after the X.Y.Z release` with its `Work:` trailer, run `$DP check`, push. Create the next milestone on GitHub when the first issue is aimed at it.
