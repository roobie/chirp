---
phase: execute
parent: U-EP6NS3X66GBL2AQL
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - The CI run builds macos-arm64 twice on linux and both copies hash the same
  - The macos-arm64 binary passes the smoke checks on a native macos-15 runner in that run, verifying TLS against the macOS roots without a manual SSL_CERT_FILE, or the gap is recorded
---

# slice/macos-arm64

## Purpose
Apple silicon Macs are the last of the four targets chirp ships for. This slice finishes the cross-build claim (D-I6U4X6Q5KJD2Y4SM) on the target least like linux.

## Scope
In: a `:macos-arm64` target entry; Mach-O-specific steps in `cross-link`; the CI matrix entries.
Out: notarization and Developer ID signing (releases will be ad-hoc signed); x86_64 macOS.

## Context & constraints
- macOS has no static libc, so the binary links libSystem dynamically. Everything else (OpenSSL, the natives) stays static.
- arm64 macOS runs only signed code. zig ad-hoc signs on link, and the signature hashes the binary, so it stays reproducible if the rest is.
- Mach-O carries an LC_UUID that can vary per build. It must be either deterministic or removed.
- OpenSSL's built-in cert locations do not include the macOS keychain, so trust may need `SSL_CERT_FILE` (e.g. /etc/ssl/cert.pem) until the embedded CA roots land.

## Now
A Sonnet agent is spiking the target entry and the Mach-O steps locally.

## Next
- Review the agent's result, build twice locally, enable it in CI.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
