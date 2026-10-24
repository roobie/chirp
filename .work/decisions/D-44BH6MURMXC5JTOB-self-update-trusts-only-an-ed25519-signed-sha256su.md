---
status: accepted
date: 2026-10-24
read_if:
  - changing how chirp self-update fetches, verifies or picks a release
  - changing release assets or the release signing key
refs:
  - src/chirp/update.janet#verified-sums
  - src/chirp/update.janet#latest-release
  - .github/workflows/release.yml
  - tools/release/sign.janet#main
---

# D-44BH6MURMXC5JTOB self-update trusts only an Ed25519-signed SHA256SUMS in a static release file tree, with the version taken from the signed names

## Context
A command that replaces the running binary is the most valuable thing an attacker could subvert. Release assets can be swapped, mirrors can lie, and TLS only proves who served the bytes, not who built them. BR asked for self-update on 2026-10-24 and chose signed checksums over checksum-only.

## Decision
Only a signature by the release key, which is built into chirp, makes a release trustworthy. Everything chirp acts on (which version is latest, which file to fetch, its expected hash) is read from the signed file and never from an API or a redirect target.

## Why
- **Checksum-only:** rejected. Whoever can replace the binary can also replace SHA256SUMS next to it.
- **The GitHub releases API or a version file:** rejected. Either would let an unsigned answer pick the version, which permits a downgrade or a redirect to another asset.
- **Verifying the provenance attestation inside chirp:** rejected. It ties updates to GitHub's attestation stack and to network services beyond a plain file tree.
- jsec already does Ed25519, so a signature costs no new dependency.
- A static file tree means any plain HTTP mirror works, because the signature, not the transport, carries the trust.

## Consequences
- The release workflow must sign every SHA256SUMS. A release without SHA256SUMS.sig cannot be installed by self-update, which is why 0.1.0 cannot be.
- Rotating the key needs a release signed by the old key that ships the new one. There is no tooling for that yet.
- The private key lives only in the CI secret, so losing it means older binaries can never update again without manual installation.
- Provenance stays a separate, manual `gh attestation verify`.
