---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - `chirp self-update --check` reports the latest released version and whether this binary is older, and changes nothing
  - `chirp self-update` replaces the running binary with the newer release for its own target, only after the release's SHA256SUMS signature verifies against the public key baked into chirp and the file's sha256 matches
  - A bad signature, a hash mismatch, a missing target file or an unwritable directory leaves the old binary in place, prints why on stderr and exits non-zero
  - A build whose version is a pre-release (`-dev`) refuses to update unless given `--force`
  - The release workflow publishes SHA256SUMS.sig, signed in CI with the release key secret
  - The smoke suite checks update, refusal and tamper cases against a local mirror with a test key on all four targets; CI is green with the double build matching
---

# slice/self-update

## Purpose
Let a chirp user move to a newer release with one command, without trusting the download channel. A signature over the release checksums ties the new binary to the release key, so a tampered mirror or release asset is refused rather than installed.

## Scope
In: a `self-update` command (`--check`, `--force`, and a mirror base plus key for mirrors and tests); finding the running binary's real path; the atomic swap on POSIX and the rename swap on Windows; signing SHA256SUMS in the release workflow; a baked-in public key file; a help topic; smoke checks; a `-dev` version on main.
Out: background or automatic update checks; verifying the GitHub provenance attestation inside chirp (it stays a manual `gh attestation verify`); privilege escalation; key rotation tooling.

## Context & constraints
- BR asked for this on 2026-10-24 and chose signed checksums over checksum-only.
- jsec/crypto already does Ed25519 (`generate-key :ed25519`, `export-public-key`, `sign`, `verify`, `digest`), checked with a throwaway key.
- The release workflow ships the bytes CI built (`release.yml` reuses `ci.yml`), so the version must come from `chirp.jdn`, not from a build flag. A `-dev` suffix between releases marks builds that are not releases.
- Smoke checks use local controls only (D-DPSCZ2KCZA4UB7YM), so the update path is tested against a local mirror and a key generated at test time.
- The private key is created by BR and goes only into a GitHub secret; it never passes through an agent.

## Now
Initialized.

## Next
- Gate to execute, then delegate the implementation. BR creates the key and secret.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
