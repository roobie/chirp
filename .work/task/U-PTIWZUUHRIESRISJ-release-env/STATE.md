---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - The job that signs a release declares environment release, and only the signing step has the secret
  - A manual run, on a branch or a tag, never touches the release environment or the real key, and proves layout, signing, verify and attestation with a throwaway key
  - A tag run signs with the real secret and verifies against src/chirp/release-key.pem before publish, as before
---

# task/release-env

## Purpose
The release signing key is a repository secret that a workflow on any branch can read; it moves into a release environment that only v* tags can use, and the manual dry run stops using the real key.

## Scope
In: .github/workflows/release.yml, `--throwaway` in tools/release/layout.janet, the records that name the release key.
Out: creating the environment and its rules, deleting the repository secret (the owner's), a tag ruleset, rotating the key.

## Context & constraints
The owner has created the `release` environment (v* tag policy, required reviewer, the key stored in it). A tag run must stay the same in output and sign with the same key; `publish` must stay apart from the key. The pages workflow's per-step env pattern for a key is the model.

### Origin
Promoted from backlog: B-K2J3HVGSJFJM4IFC Keep the release signing key in an environment limited to v* tags

### Why
CHIRP_RELEASE_SIGNING_KEY is a repository secret, so a workflow on any branch can read it: the release workflow's dry run from a branch already signs that branch's build for seven days. The main-build key is in an environment limited to main (D-6NWFV37OBOERI3AF); the key that protects releases is less guarded than the one that protects builds of main. Moving it into a `release` environment whose deployment rule allows only `v*` tags would limit it to real releases. Decide first what the dry run does without it: skip signing, or sign with a throwaway key so the rest of the packaging is still proven.


## Now
Merged; the dry run proved the manual path. The 0.11.0 tag run proves the env secret and the owner's approval.

## Next
- Merge, then the owner's first manual dispatch on a branch and first tag (Harvest).

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- tools/release/layout.test.janet: ok with chirp 0.10.0. The workflow's layout step, extracted and run on fake artifacts: a manual run signs with --throwaway; a tag run signs with a key standing in for the secret and verifies against a pem standing in for release-key.pem; with a different key it fails with 'does not verify against src/chirp/release-key.pem' before publish. The workflow parses as YAML.
- Not provable here: that a job with an empty environment expression runs without an environment; the first manual run on GitHub shows it.
- Review fixes: a manual run on a tag is a dry run (event_name decides; sim dispatch-on-tag signs with --throwaway and names the artifact dry-run-*). layout.test.janet covers --throwaway, including no private key in the output and no mixing with --pub. sim.sh: dry, dispatch-on-tag, tag ok; tag with a wrong secret fails verifying against release-key.pem.
- Second review: the signer is built once in main; layout.test.janet, sim.sh (dry, manual on a tag, tag, tag with a wrong secret), leakcheck, skillcheck pass again.
- Manual dry run 42850689842 on main 235ac89: green; package ran without entering the release environment (no release deployment created), signed with --throwaway, publish attested and skipped the release, close-milestone skipped; artifact dry-run-0.11.0-dev.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [x] decision: D-S23WKXKSMWMABF53 records why v* tags only and why dry runs use a throwaway key
- [ ] backlog: the first manual dispatch on a branch proves the empty environment expression, before the first tag; the first tag proves the secret and the approval; then the owner deletes the repository secret CHIRP_RELEASE_SIGNING_KEY

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
- 2026-11-10 first manual dispatch green (run 42850689842)
