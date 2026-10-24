---
created: 2026-10-24
---

# B-5UVS7XT6YY6KDNBH Offer gzip framing alongside spork/zip

## Why
HTTP `Content-Encoding: gzip` and `.gz` files are the most common compressed data a script meets. spork/zip only does zlib framing (D-AD6YBCGFHJTVZ7TZ), so chirp scripts cannot read or write gzip, even though miniz already has everything needed (raw deflate and crc32).

## Notes
Gzip is a thin wrapper: a 10-byte header, a raw deflate stream, then crc32 and the size. Keep it as a module separate from the zlib-format calls instead of adding a mode flag. Prefer adding raw deflate (or gzip) to spork/zip upstream (D-ZBIADZDYXYPWLX5L). A small chirp native module over the same miniz is the fallback.
