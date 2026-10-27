# Design

## Problem
chirp has no web presence beyond the repo, and the way the repo is run (dev-proc) is visible only to someone who reads `.claude/skills/`. A site should present both, tersely, without becoming a second copy of docs that drifts.

## Approach
- `site/build.janet`, run by chirp itself, renders Markdown with `md4c/to-html {:github true}` into a plain HTML template and writes a static tree (default `out/site/`).
- Sources, so the site cannot drift from the binary or the skill:
  - home: `README.md`
  - help: `src/chirp/help/*.md`, one page each
  - changelog: `CHANGELOG.md`
  - dev-proc: `site/dev-proc.md` (a short intro for humans) followed by `.claude/skills/dev-proc/SKILL.md` as-is (BR, 2026-10-27)
  - dev-proc examples: `site/dev-proc-examples.md`, real units from this repo with links to their commits on GitHub. Commit links are immutable, so the page does not drift; it only ages.
- Links: repo-relative links in the sources (`pins.jdn`, `LICENSE`) become links to the file on GitHub at the built commit; links between pages that are on the site become site links. The build fails on a relative link it cannot resolve.
- Look: one small stylesheet, system fonts, light and dark, no JavaScript.
- Deploy: `.github/workflows/pages.yml` runs on `workflow_run` after a successful tag run of `release`, taking that run's linux-x64 binary (`download-artifact` with `run-id`), so the 8-build CI matrix does not run twice. A manual run builds chirp through `ci.yml` first. Actions are pinned by sha with least permissions (D-LI565XWPIYOAVEI6). The deploy runs on main's ref, which the github-pages environment allows by default.
- No workflow env names a token: leakcheck flags the name of any secret env var set on the committing host, and gh's token variable is set on the dev host. `download-artifact`'s `github-token` input avoids it.

## Alternatives considered
- Jekyll, Hugo or another generator: a second toolchain, and the backlog item asked for chirp to build its own site.
- A private Markdown renderer: replaced by bundling md4c (U-XHNWANHLCDSBMPPJ).
- Publishing from main on every push: the site would describe unreleased features. Manual runs cover dev-proc changes between releases.

## Risks & open questions
- Pages must be switched to "GitHub Actions" in the repo settings, which needs an admin (BR); the current token lacks the Administration permission, as does setting the homepage URL.
- The first tag-triggered deploy needs a release that bundles md4c (0.4.0); until then a manual run on main serves the site.
- SKILL.md is written for agents; the intro has to carry the "why" for a human reader.
