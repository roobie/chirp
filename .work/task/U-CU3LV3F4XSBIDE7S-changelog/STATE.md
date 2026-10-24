---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - CHANGELOG.md at the repo root lists Unreleased, 0.2.0 and 0.1.0 under one `##` heading per version
  - chirp --changelog prints the CHANGELOG.md baked into the binary, with nothing on disk
  - The changelog is a help topic, so chirp help query finds it and chirp help read changelog/0-2-0 prints one version
  - The release workflow puts the released version's changelog section into the release notes, and fails a tag whose version has no section
  - A smoke check covers --changelog and the help topic on every target, and CI is green
---

# task/changelog

## Purpose
A user of a binary they got through self-update has no way to see what changed. The changelog travels inside the binary, so it is readable offline and always matches the build, and the release notes come from the same text so the two never drift.

## Scope
In: curating CHANGELOG.md from history; baking it into the image; `chirp --changelog`; the help topic; release notes taken from the version's section; smoke check; README and help docs.
Out: mdz (BR chose plain Markdown, 2026-10-25); bundling spork/mdz for scripts; `-h`/`--help` (B-WFNM7BIUL5G3FLYG).

## Context & constraints
- D-6MHEZUS5HUJXWV6A: help entries are plain data baked in at build time; a `##` heading becomes a section id.
- D-2UB7VI5YR6ZBQ4FD: main carries `-dev`, so dry runs need a fallback to the Unreleased section.
- Only BR's team uses chirp, so no compatibility concerns.

## Now
Delegating the implementation.

## Next
- Review, local build and smoke, push, CI.

## Evidence

## Harvest

## Log
- 2026-10-25 initialized; BR chose plain CHANGELOG.md over mdz and asked for `chirp --changelog`
- 2026-10-24 phase initialize → execute
