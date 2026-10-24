---
status: accepted
date: 2026-10-25
read_if:
  - cutting a release or bumping the version
  - changing CHANGELOG.md or the release notes
refs:
  - .github/workflows/release.yml
  - src/chirp/chirp.jdn
  - src/chirp/main.janet#extra-topics
  - test/smoke/changelog.janet#main
---

# D-DYWSJTLDO6S5DQDR Release notes take the version's section from the changelog baked into the shipped binary

## Context
BR asked for a curated changelog that ships inside the binary (`chirp --changelog`), so someone who got a build through self-update can see what changed without the network. The release notes on GitHub say the same thing, and two hand-written copies drift.

## Decision
CHANGELOG.md at the repo root is the one source. The image bakes it in as the help topic `changelog`, and the release workflow reads the version's section out of the binary it ships, not out of the checkout.

## Why
- **Notes written by hand per release:** rejected. They would drift from the changelog the binary prints.
- **Parsing CHANGELOG.md in the workflow:** rejected. Reading it back from the shipped binary also proves the changelog that users get is the one released.
- **Authoring it in spork/mdz:** rejected by BR. GitHub would not render it, and the help system already splits Markdown by `##`.
- **A copy under src/chirp/help/:** rejected. The repo-root file is what GitHub readers find, and a copy would drift.

## Consequences
- Cutting a release also renames `## Unreleased` to `## <version>` in the same commit that drops `-dev`. A tag with no section fails, and the smoke check fails a release build without one.
- A dry run from main shows the Unreleased section in place of the version's.
- Each `##` heading in the changelog is a help id, so headings must be version numbers or Unreleased.
