---
status: accepted
date: 2026-10-24
read_if:
  - cutting a release or bumping the version
  - changing how self-update treats pre-release builds
refs:
  - src/chirp/chirp.jdn
  - src/chirp/update.janet#pre-release?
---

# D-2UB7VI5YR6ZBQ4FD main carries a -dev version between releases; a release first drops the suffix

## Context
The release workflow ships the exact bytes CI built, so the version cannot be injected at tag time; it has to be in the source. A build from main between releases must not claim to be the last release, or self-update would treat it as current and a user could not tell what they run.

## Decision
Between releases, main's version is the next release plus `-dev`. Cutting a release is one commit that drops the suffix and gets tagged, followed by a commit that moves main to the next `-dev`.

## Why
- **A build-time version flag:** rejected. It would break the double-build comparison and the rule that a release ships CI's bytes.
- **Keeping the last release's number on main:** rejected. It mislabels main builds, and self-update would see them as up to date.
- Semver orders `X-dev` below `X`, so the pre-release compares correctly with no special cases.

## Consequences
- Every release costs two version commits, before and after the tag.
- A `-dev` build refuses to self-update without `--force`, so a test build is never silently replaced.
- The tag must equal the version, so tagging a `-dev` commit publishes a prerelease and not a release.
