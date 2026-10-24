---
date: 2026-10-24
read_if:
  - building OpenSSL for macOS without an SDK
  - OpenSSL fails on CommonCrypto headers
refs:
  - tools/build/config.jdn
---

# L-ARS76O3UDJQ2JZQB OpenSSL for macOS cross-builds without an Apple SDK once its Apple random source is disabled

## Observation
zig ships libSystem stubs but no Apple SDK headers, so OpenSSL's darwin target fails on its CommonCrypto random source. Disabling that source in the macos-arm64 openssl-flags makes OpenSSL fall back to the getentropy/urandom path, which needs only libSystem.

## Why it matters
Without it, a macOS build would need an Apple SDK in the container, which cannot be redistributed or pinned the way the rest of the toolchain is. This stops applying if zig starts shipping the CommonCrypto headers or if OpenSSL drops the source.
