---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-02
success_criteria:
  - A gzip module compresses and decompresses whole buffers and streams in chunks; its output is read by system gzip and system gzip's (multi-member included) by it; corrupt or truncated data is an error
  - A tar module lists, extracts and creates archives, plain or gzipped (ustar, pax and GNU long names read; ustar with pax for long names written), extracting with a :strip option and streaming rather than holding the archive in memory
  - Extraction refuses absolute paths, .. components, links whose target leaves the directory, and writing through a symlink; smoke checks cover each refusal
  - Help topics, README module list and changelog describe both modules; CI builds all four targets twice with matching sha256 and the smoke checks pass on each native runner
---

# slice/gzip-tar

## Purpose
A chirp script can read and write .gz data and .tar / .tar.gz archives with nothing else installed, including on Windows, and extracting an untrusted archive cannot write outside the target directory.

## Scope
In: a `gzip` native (whole and streaming, multi-member, checked), a `tar` Janet module (list, extract with :strip, create, gzipped or not), safe extraction, smoke checks, help topic `archives`, README, changelog, release notes.
Out: other compressors (bzip2, xz, zstd); reading one tar entry without extracting; tar owner or hard-link options on create; upstreaming raw deflate to spork (possible later, D-2NTKYO5CXJFCPDKW).

## Context & constraints
No fork or patch of spork (D-ZBIADZDYXYPWLX5L), no zlib (D-AD6YBCGFHJTVZ7TZ). Native function names carry a prefix (L-BVXC557ZOWPP4SN5). Binaries stay reproducible across checkouts (D-FD4ZWTDKYJBQBFRO). Also consumes B-5UVS7XT6YY6KDNBH (gzip framing alongside spork/zip).

### Origin
Promoted from backlog: B-LVXKY6YPG4V5TXA6 Bundle gzip and tar

### Why
Fetching a release `.tar.gz` and unpacking it is one of the most common scripting jobs, and chirp cannot do it without shelling out to `tar`, which Windows hosts may lack. spork/zip covers zip archives and raw deflate only.

### Notes
- miniz is already linked (spork/zip), so gzip is framing (header, CRC32, trailer) over the deflate it has; no new C library should be needed.
- tar (ustar plus the pax and GNU long-name extensions that real archives use) can be pure Janet.
- Extraction must refuse paths that escape the target directory (`..`, absolute paths, symlinks pointing out).
- Streaming matters: release archives can be large, so avoid reading the whole file into one buffer where possible.


## Now
Implementation committed; waiting for CI on all four targets.

## Next
- CI green on all targets (double build sha256 equal, smoke on native runners), then finalize.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- linux-x64 container build, `chirp test/smoke/run.janet`: all checks pass, gzip read by system gzip, tar output listed by system tar.
- windows-x64 cross build under wine: gzip and tar checks pass (dev-proc-install fails only because the wine harness does not mount .agents).
- Interop by hand: GNU gzip multi-member with FNAME, a handcrafted FEXTRA+FNAME+FCOMMENT+FHCRC member, GNU tar gnu and pax formats, Python tarfile attack archives, GitHub's codeload tarball of this repo (pax global header) extracted with :strip 1 and diffed equal.
- 140 MB .tgz: extract 1.48 s (GNU tar 1.44 s), max RSS 13 MB.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

- [x] decision: D-2NTKYO5CXJFCPDKW gzip native over static miniz, tar in Janet
- [x] learning: L-J2G76CUIQU4OWGMK top-level values are computed on the linux build host
- [ ] backlog: spork-https does not follow redirects (GitHub archive URLs answer 302 with an empty body)

## Log
- 2026-11-02 initialized
- 2026-11-02 phase initialize → execute
- 2026-11-02 implemented gzip native, tar module, smoke checks and docs; linux and wine-windows smoke green
