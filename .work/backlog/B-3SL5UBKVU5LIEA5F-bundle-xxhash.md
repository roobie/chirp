---
created: 2026-10-25
---

# B-3SL5UBKVU5LIEA5F Bundle xxhash

## Why
Scripts often hash for change detection, deduplication, cache keys and content addressing, where speed matters and cryptographic strength does not. jsec/crypto's SHA family is far slower for that. xxhash is the common choice.

## Notes
- xxhash is BSD-2-Clause and a single header plus one C file; XXH3 64 and 128 bit, XXH64 for compatibility with existing tools.
- Offer one-shot hashing of a string or buffer and a streaming state for files.
- Document that it is not for security; point at jsec/crypto for that.
- Output as integer and hex; mind that Janet numbers cannot hold 64-bit integers exactly, so the default should be hex or a buffer.
