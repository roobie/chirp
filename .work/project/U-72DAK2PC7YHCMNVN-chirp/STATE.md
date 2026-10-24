---
phase: execute
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A single static chirp binary runs HTTPS client and server scripts on a host with nothing else installed
  - The same binary offers SQLite, zlib-format compression and TOML parsing with nothing else installed
  - Release binaries exist for linux x64/arm64 (static musl), macOS arm64 and windows x64
  - CI builds each target twice and the sha256 hashes match
  - Releases carry GitHub build-provenance attestation
  - README, version output and banner mark chirp as unofficial
---

# project/chirp

## Purpose
Stock Janet has no TLS and no HTTP server. chirp is one static, reproducible binary that includes both, plus SQLite and compression, so a script can do HTTPS client and server work and keep local data with nothing installed except chirp.

## Scope
In: a Janet executable bundling pinned upstream janet and spork (including its native modules, among them spork/zip for compression, D-AD6YBCGFHJTVZ7TZ), jsec (with static OpenSSL 3), spork-https, janet-lang/sqlite3 (D-Z7JOCFPGMOANQFY7) and pyrmont/tomlin (D-DMR3ULVUY2KA72XN); CA root handling; a reproducible multi-platform CI build; releases with provenance.
Out: forks of janet or spork; jsys (D-HCB4FUBWJ2TJFZGI); janet-pm, until B-DZXWHDHHXMIJKCKR is decided.

## Context & constraints
- Decisions: run `$DP find` before acting. The founding set is D-ZBIADZDYXYPWLX5L, D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-2SHG5CGZYE2DZCQG, D-BPDFOMM2OH7HMPZB, D-B2RTYH6CNDO6SRF5, D-URDDGCK3H3MPSCTM, D-Q23RA2EVVN5LYCX7, D-J2C4TCJIQLJGENAG. D-ZBOSG3RYRJVCOMXZ (hash key) is still only proposed.

## Now
0.1.0 is published. Slice U-OPXF3E6S7PBCFAHC (bundle-sqlite-toml) is the next work, for 0.2.0.

## Next
- bundle-sqlite-toml for 0.2.0.

## Evidence
- Build-matrix (U-EP6NS3X66GBL2AQL): run 40095901156 builds all four targets twice with matching sha256, and smoke-runs each one on its native runner, HTTPS client and server included.
- Release-0-1-0 (U-ROTWPYUJJW5Q45E2): https://github.com/roobie/chirp/releases/tag/v0.1.0 (run 40103776646) ships the four binaries, notices and SHA256SUMS with provenance attestation; the binary and README mark chirp unofficial. This meets the release, reproducibility, provenance and unofficial criteria; SQLite and TOML remain.

## Harvest

## Log
- 2026-10-24 initialized from the session handoff; decisions and open questions moved into records
- 2026-10-24 phase initialize → execute
- 2026-10-24 task leak-check (U-IJTQWFAWHMY3VRSB) delivered: commit hooks block host-specific details (D-54W72MHWZBDDVE4V, D-U5B6PF3E3RVNDWFL)
- 2026-10-24 public GitHub repo created and pushed by BR
- 2026-10-24 scope amended by BR: SQLite and compression are in (D-Z7JOCFPGMOANQFY7, D-AD6YBCGFHJTVZ7TZ), then TOML (D-DMR3ULVUY2KA72XN)
- 2026-10-24 slice linux-x64-spike (U-34F3JPNU2EK44A7I) delivered: static, reproducible linux chirp with TLS client and server
- 2026-10-24 slice zig-windows-spike (U-XQ7CEDXSOK3XIAZV) delivered: reproducible windows chirp cross-built by zig; D-I6U4X6Q5KJD2Y4SM accepted
- 2026-10-24 milestone build-matrix (U-EP6NS3X66GBL2AQL) opened
- 2026-10-24 milestone build-matrix delivered: full matrix green on GitHub
- 2026-10-24 milestone release-0-1-0 (U-ROTWPYUJJW5Q45E2) opened; SQLite and TOML moved to 0.2.0 (BR)
- 2026-10-24 milestone release-0-1-0 delivered: v0.1.0 published
