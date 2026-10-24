---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - The linux x64 chirp binary completes an HTTPS GET to a real public host with certificate verification on
  - A spork-https server started from the same binary answers an HTTPS request
  - Two builds in different directories produce identical sha256
---

# slice/linux-x64-spike

## Purpose
Prove the three riskiest claims on one platform before paying for the full matrix: TLS works from the static binary, the server path works, and the build is reproducible.

## Scope
In: a local linux x64 build of janet, spork, jsec, spork-https and static OpenSSL 3; a minimal chirp main; three smoke checks.
Out: CI, other platforms, releases, embedded CA bundle polish, the runtime hash key (D-ZBOSG3RYRJVCOMXZ).

## Context & constraints
- Relevant decisions: D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-BPDFOMM2OH7HMPZB, D-2SHG5CGZYE2DZCQG, D-Q23RA2EVVN5LYCX7, D-3GLX6D2RADC6IDG7, D-ZOBE3ZBK764B22JY, D-ANH2OMRLGDIIVVZY.
- The open reproducibility risk is the order of pointer-hashed tables in the marshaled image.
- Host has docker (with network access) and no musl toolchain.

## Layout (spike)
- `pins.jdn`: upstream commits and the Alpine image digest.
- `tools/build/linux.sh`: thin host wrapper that runs the pinned container.
- `tools/build/build.janet`: build logic (fetch, OpenSSL, janet, jsec, link).
- `src/chirp/main.janet`: chirp's main.
- `test/spike/`: the three checks.
- `build/`: output and source cache, gitignored.

## Now
All three criteria pass; the build is committed. BR is weighing zig as the toolchain for every target, which a windows cross-build spike will test before this slice's container decision (D-3GLX6D2RADC6IDG7) is finalized.

## Next
- Fill in refs on D-3GLX6D2RADC6IDG7, D-ZOBE3ZBK764B22JY and D-ANH2OMRLGDIIVVZY.
- Finalize once the zig spike says whether the container path stays.

## Evidence
- `sh test/spike/run.sh`: builds in `build/spike/one` and `build/spike/nested/two` both hash `c6ac5b4741e8850566d6b41cb089d21ac98e97a0fe411e3b9bc8a7309e660424`.
- Same run: `ok https-get https://example.com/ status 200` (verification on, host trust store).
- Same run: `ok https-server https://localhost:27294/spike status 200`, after an untrusted client was rejected.
- Same run: `ok zip 100000 -> 288 -> 100000`.
- `file`: static, stripped x86-64 ELF, 7731040 bytes; `ldd`: not a dynamic executable.

## Harvest
- Learnings: L-AGD7ZVHWYRGFIEDF (peg address in image), L-CPIUGJI6EY2HEID2 (jsec `:trusted-cert`).
- Backlog: B-MKHM34WSTBQOE626 (tasker), B-WMHIKUYY6NBOTTVB (REPL line editing), B-QCZS5VCEMNVARX34 (spork-https `:ca` docs).
- Open: apk packages are not version-pinned (versions are recorded per build). Moot if zig replaces the container.

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
