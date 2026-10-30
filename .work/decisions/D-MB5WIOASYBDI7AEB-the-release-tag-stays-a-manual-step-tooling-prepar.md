---
status: accepted
date: 2026-10-30
read_if:
  - cutting a release or bumping the version
  - automating releases or tagging from CI
refs:
  - tools/release/cut.janet
  - .github/workflows/release.yml
---

# D-MB5WIOASYBDI7AEB The release tag stays a manual step; tooling prepares the release and the move to the next -dev but never tags, commits or pushes

## Context
The release edits (dropping `-dev`, dating the changelog section, the README version example, and afterwards the next `-dev`) were done by hand from notes, so they could drift between hosts and agents. Pushing a `v*` tag is what publishes a release, and a published release is what every `chirp --self-update` installs.

## Decision
A script makes the release edits and the move to the next `-dev`. A maintainer pushes the tag by hand, and the script leaves committing and pushing to whoever runs it.

## Why
The tag push is the one act that ships a signed binary to users, so it stays a deliberate human authorization. The release workflow already runs the full CI before it publishes, so automating the tag would save no checks, only the authorization.
- **A dispatch workflow that tags:** a tag pushed with the workflow's own token starts no other workflow, so it would need a stored personal or app token, or the release jobs restructured as a callable workflow. Both are more to keep up than one tag command.
- **CI committing the next `-dev` after publishing:** that is a bot pushing to main, which races with work pushed in the meantime and bypasses the commit hooks.
- **A script that also commits:** the commit carries the project's `Work:` trailer and STATE.md update, which only the person committing knows.

## Consequences
A release is: run the script, commit and push, tag by hand, check the release, run the script's next mode, then commit and push. A future move to automated tagging supersedes this record and must say where the authorization moved to.
