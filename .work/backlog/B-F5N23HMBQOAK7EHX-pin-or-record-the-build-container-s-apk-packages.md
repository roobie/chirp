---
created: 2026-10-24
---

# B-F5N23HMBQOAK7EHX Pin or record the build container's apk packages

## Why
The image digest is pinned, but the packages the build installs into it at run time are not. A repository update can change perl, make or git under a fixed digest. perl generates parts of OpenSSL, so a new perl can change the output hash and leave nothing in `pins.jdn` to explain why. zig removes the compiler from this list but not the others.

## Notes
The options are a derived image built once and pinned by its own digest, or versions pinned with `apk add pkg=ver` (Alpine drops old versions, so this goes stale). Either way the versions should end up in the build record.
