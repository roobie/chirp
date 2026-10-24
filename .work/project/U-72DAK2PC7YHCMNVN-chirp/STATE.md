---
phase: execute
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A single static chirp binary runs HTTPS client and server scripts on a host with nothing else installed
  - Release binaries exist for linux x64/arm64 (static musl), macOS arm64 and windows x64
  - CI builds each target twice and the sha256 hashes match
  - Releases carry GitHub build-provenance attestation
  - README, version output and banner mark chirp as unofficial
---

# project/chirp

## Purpose
Stock Janet has no TLS and no HTTP server. chirp is one static, reproducible binary that includes both, so a script can do HTTPS client and server work with nothing installed except chirp.

## Scope
In: a Janet executable bundling pinned upstream janet and spork, jsec (with static OpenSSL 3) and spork-https; CA root handling; a reproducible multi-platform CI build; releases with provenance.
Out: forks of janet or spork; jsys (D-HCB4FUBWJ2TJFZGI); janet-pm, until B-DZXWHDHHXMIJKCKR is decided.

## Context & constraints
- Decisions: run `$DP find` before acting. The founding set is D-ZBIADZDYXYPWLX5L, D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-2SHG5CGZYE2DZCQG, D-BPDFOMM2OH7HMPZB, D-B2RTYH6CNDO6SRF5, D-URDDGCK3H3MPSCTM, D-Q23RA2EVVN5LYCX7, D-J2C4TCJIQLJGENAG. D-ZBOSG3RYRJVCOMXZ (hash key) is still only proposed.

## Now
Steering slice U-34F3JPNU2EK44A7I (linux-x64-spike), which removes the main risks before the matrix widens.

## Next
- Create the public GitHub repo (D-URDDGCK3H3MPSCTM).
- After the spike: plan the platform matrix and CI.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized from the session handoff; decisions and open questions moved into records
- 2026-10-24 phase initialize → execute
- 2026-10-24 task leak-check (U-IJTQWFAWHMY3VRSB) delivered: commit hooks block host-specific details (D-54W72MHWZBDDVE4V, D-U5B6PF3E3RVNDWFL)
