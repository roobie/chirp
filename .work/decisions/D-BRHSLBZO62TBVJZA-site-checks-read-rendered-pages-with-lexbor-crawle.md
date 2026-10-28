---
status: accepted
date: 2026-10-28
read_if:
  - changing site/build.janet or the site's markup
  - adding a rule to the site check
  - changing how the pages workflow verifies a deploy
refs:
  - site/check.janet
  - .github/workflows/pages.yml
---

# D-BRHSLBZO62TBVJZA Site checks read rendered pages with lexbor, crawled the same way on disk and live

## Context
`site/build.janet` checked links by matching the Markdown text before rendering, so it could not see what readers get: nav state, ids, fragments, footers. A deploy could also fail quietly, with Pages still serving the previous site.

## Decision
One checker reads the rendered HTML through lexbor and finds pages by following links from `index.html`, whether the site is a directory or a URL. `pages` runs it before upload and again on the live site after deploy, waiting until the footer names the deployed commit.

## Why
Regex or text matching on HTML breaks when the markup changes in harmless ways; selectors over a parsed tree do not. Listing files would work only on disk, while crawling works the same way in both places, so the rules are written once. A separate live check (or none) would leave a gap between what was built and what is served.

## Consequences
The site's markup is now a contract: changing the header, nav, `aria-current` or footer in `site/build.janet` means changing the check with it. The checker needs a chirp that bundles lexbor (0.4.0+). The cases that break the site on purpose were run once by hand and are not in CI.
