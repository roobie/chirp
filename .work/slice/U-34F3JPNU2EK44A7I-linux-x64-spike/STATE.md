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
A Sonnet subagent is implementing the layout above and running the three checks. Added mid-flight: native modules are listed as data, and all of spork's native modules (spork/zip included) are linked, with a zip round-trip check. SQLite waits for U-OPXF3E6S7PBCFAHC.

## Next
- Review the subagent's diff and evidence; commit.
- Fill in refs on D-3GLX6D2RADC6IDG7, D-ZOBE3ZBK764B22JY and D-ANH2OMRLGDIIVVZY once the files exist.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
