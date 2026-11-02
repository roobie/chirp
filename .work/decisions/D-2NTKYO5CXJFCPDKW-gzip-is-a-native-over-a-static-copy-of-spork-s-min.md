---
status: accepted
date: 2026-11-02
read_if:
  - changing the gzip or tar API
  - reading or writing compressed data or archives in chirp
  - updating the spork pin (miniz moves with it)
refs:
  - src/gzip/gzip.c
  - src/tar/tar.janet
  - tools/build/natives.jdn
  - tools/build/config.jdn#janet-modules
---

# D-2NTKYO5CXJFCPDKW gzip is a native over a static copy of spork's miniz, and tar is chirp-owned Janet that refuses escaping entries

## Context
Fetching and unpacking a release `.tar.gz` is a common scripting job, and HTTP bodies and `.gz` files are often gzipped. spork/zip has only zlib framing and zip archives, without streaming, so chirp scripts had to shell out to `gzip` and `tar`, which Windows hosts may lack (B-LVXKY6YPG4V5TXA6, B-5UVS7XT6YY6KDNBH).

## Decision
chirp owns two modules. `gzip` is a native that compiles the pinned spork's `deps/miniz/miniz.c` into its own file with every miniz function static (`MINIZ_EXPORT static`, and `extern` defined away while miniz is read), and frames raw deflate as gzip, whole or through a compressor/decompressor. `tar` is Janet, in `src/tar/`, bundled through a `:janet-modules` entry with `:pin :repo`; it reads ustar, pax and GNU long names, writes ustar with pax only where needed, streams through a source that is a path (string), bytes (buffer) or anything with `:read`, and refuses on extraction any entry that would land outside the directory, including writing through a symlink.

## Why
- A second, static copy of miniz costs about 50 KiB per target and needs no fork or patch of spork (D-ZBIADZDYXYPWLX5L) and no zlib (D-AD6YBCGFHJTVZ7TZ). Linking against spork/zip's miniz symbols instead would leave the image build's `gzip.so` with undefined symbols, because natives are dlopened separately. Raising raw deflate upstream in spork stays possible; this module would then become a thin layer over it.
- Static miniz functions also sidestep L-BVXC557ZOWPP4SN5's global-symbol clashes without renaming miniz's hundred-odd names.
- tar is byte layout and path checks, not compression, so Janet is fast enough: extracting a 140 MB `.tgz` takes about as long as GNU tar, in about 13 MB of memory.
- A string is a path because that is how every other file API in Janet reads; bytes come as a buffer, which is what HTTP bodies and `slurp` return. Guessing from content would make a path that looks binary, or bytes that look like a path, do the wrong thing.
- Refusing (an error) rather than skipping a dangerous entry, as GNU tar does with a warning, means a script never silently gets less than the archive held.

## Consequences
- A miniz update arrives with the spork pin; if miniz.h ever declares other functions `extern`, gzip.c fails to compile rather than clashing at link.
- Links cannot be extracted on Windows, where Janet has no `os/symlink` or `os/link`; hard links become copies there, symlinks an error.
- `tar/create` stores owners as 0 and hard links as copies; neither is an option yet.
- Reading one entry without extracting has no API yet; `tar/list` gives metadata only.
