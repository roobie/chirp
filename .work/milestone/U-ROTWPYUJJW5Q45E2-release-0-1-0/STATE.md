---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - The repo carries an MIT LICENSE, and every release ships the license texts of everything linked into the binaries
  - A README says chirp is unofficial, what it bundles, how to verify a download (sha256 and provenance), and that windows needs SSL_CERT_FILE for now
  - A tag push `v<version>` whose version does not match `src/chirp/chirp.jdn` fails before anything is published
  - A dry run of the release workflow on main is green and produces the four binaries, SHA256SUMS and the notices, with provenance attestations, without publishing
  - The version is 0.1.0 and the only step left is BR pushing the tag
---

# milestone/release-0-1-0

## Purpose
CI proves every target builds reproducibly and runs, but nobody can download chirp yet. This milestone makes a tag push publish verifiable binaries, and prepares 0.1.0 so cutting it is a single tag push.

## Scope
In: LICENSE and third-party notices; README; a tag-triggered release workflow that reuses the CI build and gates on it, with SHA256SUMS and GitHub build-provenance attestation (a project success criterion); the version bump to 0.1.0.
Out (BR, 2026-10-24): SQLite and TOML (U-OPXF3E6S7PBCFAHC) wait for 0.2.0; embedded CA roots (D-B2RTYH6CNDO6SRF5) wait too, so windows users set SSL_CERT_FILE. Pushing the tag is BR's call, because a published release is public.

## Context & constraints
- D-J2C4TCJIQLJGENAG: README, release notes and version output say chirp is unofficial.
- D-URDDGCK3H3MPSCTM: releases come from GitHub, with free provenance attestation.
- D-LI565XWPIYOAVEI6: actions pinned by sha; only the publishing job gets write permissions.
- jsec declares ISC in project.janet and its README, but ships no LICENSE file at the pin, so its notice has to be supplied from that declaration.
- Statically linked runtime pieces need notices as well: musl (linux), the mingw-w64 runtime (windows) and compiler-rt from zig.

## Slices (in order)
1. license-notices: LICENSE plus a notices file generated from the pinned sources at build time.
2. readme.
3. release-workflow: a dry run on dispatch, publishing on a tag, and the version gate.
4. cut-0-1-0: the version bump, a green dry run, and the handoff to BR.

## Now
Initializing; build-matrix's last run (macos-arm64) is in flight.

## Next
- Start license-notices.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
