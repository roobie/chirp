---
phase: execute
parent: U-ROTWPYUJJW5Q45E2
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A `v*` tag push runs the full CI (double build, compare, smoke, leakcheck) and publishes a GitHub release only if all of it is green
  - A tag whose version differs from what the built binary reports fails the run before the release step
  - A manual dispatch on main runs the same path, stops before publishing, and leaves the release assets as a run artifact
  - Assets are named as README.md promises, SHA256SUMS covers them, and each one has a build-provenance attestation
  - Release notes say chirp is unofficial (D-J2C4TCJIQLJGENAG)
  - Only the publish job has write, id-token and attestations permissions, and every action is pinned by sha (D-LI565XWPIYOAVEI6)
---

# slice/release-workflow

## Purpose
CI already proves each commit builds reproducibly and runs on every target. A release must ship exactly those bytes, under that proof, without a hand step that could slip a different file in.

## Scope
In: `ci.yml` made callable; a `release.yml` that calls it and then packages, attests and publishes; release notes as an editable template.
Out: the version bump and the real tag (cut-0-1-0); signing beyond provenance (notarization, Authenticode).

## Context & constraints
- Release assets come from copy `a` of each target's CI build; the compare job is what makes copy `a` trustworthy.
- The version gate reads the version from the built binary's identity line, so the check covers the bytes being shipped, not only the config file.
- Attestations in a dry run are real but name no release; that is the cost of proving the attest step works before the tag.

## Now
Dry run 40100593970 is green; it found SHA256SUMS listing itself, now fixed.

## Next
- Prove the version gate: push a scratch tag that mismatches (e.g. `v0.0.0-gate`) and see the run fail in package, then delete the tag.

## Evidence
- Dry run 40100593970 (dispatch on 2844b57) is green in all 16 jobs. Compare listed both chirp and NOTICES.txt as identical for all four targets. package wrote the 4 binaries, 4 NOTICES files and SHA256SUMS under the README names, with notes saying unofficial. publish attested 9 subjects (Rekor entry, repo attestation 59415140), and the API shows the linux-x64 binary's attestation naming release.yml at refs/heads/main. No release was created.
- That run's SHA256SUMS listed itself, so `sha256sum -c` failed on it; fixed by writing it outside the directory first.

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
