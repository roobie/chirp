---
status: accepted
date: 2026-11-10
read_if:
  - changing who or what may sign with the release key
  - changing the release workflow's dry run, its environment or its triggers
refs:
  - .github/workflows/release.yml
  - tools/release/layout.janet
  - tools/release/sign.janet
---

# D-S23WKXKSMWMABF53 The release key is gated by the owner's approval in a release environment, and a dry run signs with a throwaway key

## Context
The release key was a repository secret, so a workflow on any branch could read it, and a dry run from a branch signed with it (D-6NWFV37OBOERI3AF). The main-build key already had an environment of its own.

## Decision
The key is the secret of a `release` environment. Its deployment rule allows only `v*` tags and its required reviewer is the owner, so each release run waits for an approval before the job can read the key. Only a push of a tag is a release; a manual run, even on a tag, is a dry run, never enters the environment and signs with a key made for that run.

## Why
- **The approval is the gate, the tag rule is not:** a tag push runs the workflow file of the tagged commit, so whoever can push a `v*` tag controls what runs in the environment. The tag rule only narrows which refs can ask; the owner's approval is what keeps the key from a pushed tag. No tag ruleset is planned, so the approval is relied on alone.
- **The approver must not be an agent:** agents push with the owner's fine-grained token. That token must not hold Deployments: write, or an agent could approve its own tag. The owner's review is not blocked from approving their own run (prevent self-review is off) because the owner is the only person who releases.
- **A push, not a ref type, decides a release:** a manual run on a tag has a tag ref but is not a deliberate release; it would otherwise reach the key, the release and the milestone.
- **v* tags and not main:** main already has its own key and environment. Letting main reach the release key would give every merge the key that protects releases, which D-6NWFV37OBOERI3AF rejected for main builds.
- **A throwaway key for dry runs, not skipped signing:** a manual run must not wait on an approval or reach the key, yet skipping signing would leave layout, signing, verify and attestation unproven. The key lives only in the signing process and is never written out, so it cannot appear in a log. What a dry run no longer proves is the stored secret and the approval; a tag run checks the signature against `src/chirp/release-key.pem` before `publish`, so a wrong secret fails before anything is published.
- **One job with a conditional environment, not two jobs:** the layout, signing and notes stay written once. `publish`, which writes and attests, is a job without the environment, so it never has the key.

## Consequences
- A tag cut before this change cannot be released again: its workflow file reads the repository secret, which is deleted once this is proven.
- The first manual run on a branch proves that an empty environment expression means no environment; the first tag proves the secret and the approval.
