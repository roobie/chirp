---
status: accepted
date: 2026-10-24
read_if:
  - adding or bumping a GitHub action
  - changing workflow permissions
refs:
  - .github/workflows/ci.yml
---

# D-LI565XWPIYOAVEI6 CI pins third-party actions by commit sha with read-only permissions

## Context
CI builds and will publish the binaries that users trust for TLS. An action runs with the job's token and sees the build outputs, and a tag such as `v4` can be moved to different code at any time.

## Decision
Every third-party action is referenced by a full commit sha, with its version in a comment. Workflows get read-only `contents` by default and no persisted checkout credentials. A job that needs more, such as publishing a release, asks for it alone.

## Why
A sha can't be repointed, so a compromised or retagged action can't reach chirp's builds unnoticed. The alternatives were tags (mutable) and vendoring the actions (more to maintain). Least privilege limits what any step can do with the token if it is compromised.

## Consequences
Bumping an action is a deliberate change that has to look up the new sha. The pinned runner images (ubuntu-24.04, windows-2025) follow the same idea for the platform, but GitHub still updates those images in place.
