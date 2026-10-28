---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-28
success_criteria:
  - '`chirp site/check.janet <dir|url>` checks every page of a built site or the live site with the same rules: nav present with the GitHub link, exactly one page marked current where the page is in the nav, ids unique, every internal link resolves to a page and, with a fragment, to an id on it, the stylesheet resolves, and the footer names the expected commit and chirp version'
  - the check fails (exit 1, naming page and rule) on a site broken on purpose for each rule
  - the `pages` workflow runs it on `out/site` before upload, and on the live URL after deploy with the deployed commit expected
  - a `pages` run (manual is enough) is green with both checks
---

# slice/site-tests

## Purpose
Structural checks on the Pages site, built and live, with lexbor instead of text matching, so a broken page is a red run rather than something a reader finds.

## Scope
In: `site/check.janet`; wiring into `.github/workflows/pages.yml`; README's site paragraph.
Out: external links (GitHub URLs; commit links are already checked by the build); HTML validity beyond what the rules need; visual checks.

## Context & constraints
- The site is built by chirp from the repo's Markdown (D-ME7B5XOAG245FN65); `site/build.janet` already fails on unresolved relative links and unknown commits, by matching text before rendering. The check works on the rendered output instead.
- Needs a chirp with lexbor (0.4.0+); `pages` runs the release's own binary, which has it.
- Live checks go through spork-https. Pages may serve the previous deploy for a while, so the live check retries until the footer names the expected commit, with a bound.
- Each check names the page and the rule, so a failure is readable in the Actions log.

### Origin
Promoted from backlog: B-VDJWHBDAHVSYULLB Integration tests for the Pages site with lexbor

### Why
The site build checks only links, by matching text. BR wants structural checks on the generated site and on the live site after each deploy, which was the first use named for bundling an HTML parser (D-AYM6G4PAISONUDLK).

## Now
Pushing; then a manual `pages` run.

## Next
- Finalize once the run is green.

## Evidence
- `site/check.janet` passes on a fresh `out/site` (11 pages, HEAD commit, chirp 0.4.0) and on https://roobie.github.io/chirp/ (11 pages, 85a178e). Beyond the criteria it also checks title, `lang`, links that climb out of the site, and, locally, HTML files no link reaches.
- Broken on purpose, once per rule, in a copy of `out/site`: nav missing, GitHub link gone, no page marked current, two marked current, duplicate id, missing page, missing fragment target, link out of the site, no stylesheet link, stylesheet file gone, wrong commit, wrong chirp version, no footer, empty title, no `lang`, orphan page. Each exits 1 and names the page and rule. The out-of-site case first crashed the crawl; fixed.
- `--wait`: against the live site it returns at once when the footer names the commit, and exits 1 after the bound with the commit it does serve.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: site checks read the rendered pages through lexbor and crawl from index.html the same way on disk and live, so one set of rules covers both

## Log
- 2026-10-28 initialized
- 2026-10-28 phase initialize → execute
- 2026-10-28 check written, broken-site cases pass, wired into `pages`
