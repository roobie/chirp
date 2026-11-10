---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-10
success_criteria:
  - The job that signs a release declares environment release, and only the signing step has the secret
  - A manual run never touches the release environment or the real key, and proves layout, signing, verify and attestation with a throwaway key
  - A tag run signs with the real secret and verifies against src/chirp/release-key.pem before publish, as before
---

# task/release-env

## Purpose
The release signing key is a repository secret that a workflow on any branch can read; it moves into a release environment that only v* tags can use, and the manual dry run stops using the real key.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-K2J3HVGSJFJM4IFC Keep the release signing key in an environment limited to v* tags

### Why
CHIRP_RELEASE_SIGNING_KEY is a repository secret, so a workflow on any branch can read it: the release workflow's dry run from a branch already signs that branch's build for seven days. The main-build key is in an environment limited to main (D-6NWFV37OBOERI3AF); the key that protects releases is less guarded than the one that protects builds of main. Moving it into a `release` environment whose deployment rule allows only `v*` tags would limit it to real releases. Decide first what the dry run does without it: skip signing, or sign with a throwaway key so the rest of the packaging is still proven.

### Notes
TODO


## Now
Done: workflow, decision and amendments committed; waiting for merge

## Next
- TODO

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- tools/release/layout.test.janet: ok with chirp 0.10.0. The workflow's two shell steps, extracted and run on fake artifacts: a manual run signs with an openssl throwaway key and verifies against its public half; a tag run signs with a key standing in for the secret and verifies against a pem standing in for release-key.pem; a tag run with a different key fails with 'does not verify against src/chirp/release-key.pem' before publish. The workflow parses as YAML.
- Not provable here: that a job with an empty environment expression runs without an environment; the first manual run on GitHub shows it.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [x] decision: D-S23WKXKSMWMABF53 records why v* tags only and why dry runs use a throwaway key
- [ ] backlog: delete the repository secret CHIRP_RELEASE_SIGNING_KEY after the first manual run and the first tag run pass

## Log
- 2026-11-10 initialized
- 2026-11-10 phase initialize → execute
