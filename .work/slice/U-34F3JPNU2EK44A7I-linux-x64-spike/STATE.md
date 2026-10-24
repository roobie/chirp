---
phase: initialize
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
- Relevant decisions: D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-BPDFOMM2OH7HMPZB, D-2SHG5CGZYE2DZCQG, D-Q23RA2EVVN5LYCX7.
- Pin every upstream by commit. Pins are content, not logic, so keep them in one place.
- The open reproducibility risk is the order of pointer-hashed tables in the marshaled image.

## Now
Initializing. Pins and build layout are not chosen yet.

## Next
- Choose the build driver and the layout for pins.
- Pin janet, spork, jsec, spork-https and OpenSSL 3.
- Build static OpenSSL, then jsec, then the chirp executable.
- Run the three checks and record the results in Evidence.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
