---
status: accepted
date: 2026-11-10
read_if:
  - changing who or what may sign with the release key
  - changing the release workflow's dry run, its environment or its triggers
refs:
  - .github/workflows/release.yml
  - tools/release/layout.janet
---

# D-S23WKXKSMWMABF53 The release key lives in an environment limited to v* tags, and a dry run signs with a throwaway key

## Context
The release key was a repository secret, so a workflow on any branch could read it, and the dry run of the release workflow from a branch signed that branch's build with it (D-6NWFV37OBOERI3AF). The main-build key was already in an environment limited to main.

## Decision
The key is the secret of a `release` environment whose deployment rule allows only `v*` tags and has no required reviewers. The release job takes that environment on a tag and none on a manual run, and only the step that signs has the secret. A manual run makes an Ed25519 key inside the run, signs with it through `--key-env` naming a variable that is not a secret, and verifies against that key's public half.

## Why
- **Tags only, not main:** a release is made by a tag, so the tag is the one event that should reach the key. Main already has its own key and environment; letting main reach the release key would give every merge to main the key that protects releases, which is what D-6NWFV37OBOERI3AF rejected for main builds. Tags are a release manager's act, and the tag policy holds on any commit, so a `v*` tag on a branch commit still signs and is still checked against the key chirp trusts.
- **No required reviewers:** the tag is already the deliberate step (D-MB5WIOASYBDI7AEB); a second approval per release would only add a click.
- **A dry run without the real key, not skipped signing:** a manual run cannot enter an environment whose rule allows only tags, by design. Skipping signing would leave the layout, signing, verify and attestation paths unproven. A throwaway key keeps them proven with the same code, branching only on where the key and the public key come from. What a dry run no longer proves is the stored secret; a tag run checks it against `src/chirp/release-key.pem` before `publish`, so a wrong secret fails before anything is published.
- **One job with a conditional environment, not two jobs:** the layout, signing and notes steps stay written once. `publish`, which writes and attests, is a separate job without the environment, so it never has the key.

## Consequences
- The first real tag is also the first proof of the stored secret.
- A repository secret of the same name must not be left in place: it would stay readable by any branch.
