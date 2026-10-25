---
created: 2026-10-25
---

# B-LVXKY6YPG4V5TXA6 Bundle gzip and tar

## Why
Fetching a release `.tar.gz` and unpacking it is one of the most common scripting jobs, and chirp cannot do it without shelling out to `tar`, which Windows hosts may lack. spork/zip covers zip archives and raw deflate only.

## Notes
- miniz is already linked (spork/zip), so gzip is framing (header, CRC32, trailer) over the deflate it has; no new C library should be needed.
- tar (ustar plus the pax and GNU long-name extensions that real archives use) can be pure Janet.
- Extraction must refuse paths that escape the target directory (`..`, absolute paths, symlinks pointing out).
- Streaming matters: release archives can be large, so avoid reading the whole file into one buffer where possible.
