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
The target is one config entry, with no Mach-O steps in `cross-link`. zig's LC_UUID is deterministic, it ad-hoc signs, and `-s` keeps the signature valid. The CI matrix entries are in, so the push shows whether it runs on macos-15.

## Next
- Read the CI run. If TLS fails without `SSL_CERT_FILE`, find where macOS keeps a PEM bundle (the binary's probe list includes /etc/ssl/cert.pem).

## Evidence
- Two local builds in different directories: sha256 fd40031b…d670 for both. Mach-O arm64 with minos 11.0, `libSystem.B.dylib` as the only dylib, LC_UUID 51fd8788…2bfe in both, and an ad-hoc linker signature whose 418 page hashes were recomputed and all match.

## Harvest
- [ ] learning: OpenSSL for macOS without an Apple SDK fails on CommonCrypto headers; `-DOPENSSL_NO_APPLE_CRYPTO_RANDOM` drops the Apple random source instead of needing an SDK

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
