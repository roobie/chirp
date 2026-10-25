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
chirp is a batteries-included scripting runtime in one static, reproducible binary. Scripts often need one more thing (an API call, a config file, local state), and in most languages that means an install step. Stock Janet cannot even do TLS. chirp bundles HTTPS client and server, SQLite, TOML, JSON and compression, so a script runs with nothing installed except chirp.

## Scope
In: a Janet executable bundling pinned upstream janet and spork (including its native modules, among them spork/zip for compression, D-AD6YBCGFHJTVZ7TZ), jsec (with static OpenSSL 3), spork-https, janet-lang/sqlite3 (D-Z7JOCFPGMOANQFY7) and pyrmont/tomlin (D-DMR3ULVUY2KA72XN); CA root handling; a reproducible multi-platform CI build; releases with provenance.
Out: forks of janet or spork; jsys (D-HCB4FUBWJ2TJFZGI); janet-pm, until B-DZXWHDHHXMIJKCKR is decided.

## Context & constraints
- Decisions: run `$DP find` before acting. The founding set is D-ZBIADZDYXYPWLX5L, D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-2SHG5CGZYE2DZCQG, D-BPDFOMM2OH7HMPZB, D-B2RTYH6CNDO6SRF5, D-URDDGCK3H3MPSCTM, D-Q23RA2EVVN5LYCX7, D-J2C4TCJIQLJGENAG. D-ZBOSG3RYRJVCOMXZ (hash key) is still only proposed.

## Now
0.2.0 is published. Main carries `0.3.0`, ready to tag: CHANGELOG.md's Unreleased section became `## 0.3.0` (D-DYWSJTLDO6S5DQDR), covering `-h`/`--help`, the `yaml` module on libyaml, and `omap` with ordered json and yaml decode and encode.

## Next
- BR tags `v0.3.0` once main CI is green; then main moves to `0.4.0-dev` with a fresh Unreleased section.
- Pick from the backlog with BR.

## Evidence
- Build-matrix (U-EP6NS3X66GBL2AQL): run 40095901156 builds all four targets twice with matching sha256, and smoke-runs each one on its native runner, HTTPS client and server included.
- Release-0-1-0 (U-ROTWPYUJJW5Q45E2): https://github.com/roobie/chirp/releases/tag/v0.1.0 (run 40103776646) ships the four binaries, notices and SHA256SUMS with provenance attestation; the binary and README mark chirp unofficial. This meets the release, reproducibility, provenance and unofficial criteria; SQLite and TOML remain.
- Bundle-sqlite-toml (U-OPXF3E6S7PBCFAHC): run 40107147500 builds all four targets twice with matching sha256, and the new sqlite and toml smoke checks pass on each target's native runner. They are not in a release yet.
- Spork-https-overlay (U-O25BRXG46K5BCRAS): run 40109671483 builds all four targets twice with matching sha256. The overlay smoke check (default User-Agent, explicit User-Agent, client `:ca` trusted) passes on each target's native runner.
- Bundled-help (U-U3CE4WWF4S2GLYDS): run 40112713990 (7dd70c7) builds all four targets twice with matching sha256, and the help smoke check passes on each target's native runner.
- Cli-stdin (U-XFHE3BIPNBP6KNS5): run 40114378370 (5add4ad) builds all four targets twice with matching sha256, and the stdin smoke check passes on each target's native runner.
- Self-update (U-UQ6SLNXUIHLJOPK7): https://github.com/roobie/chirp/releases/tag/v0.2.0 (run 40119267950) ships SHA256SUMS.sig signed in CI; the installed 0.2.0 release runs `chirp self-update` against it and reports it is up to date.
- Changelog (U-CU3LV3F4XSBIDE7S): run 40139405385 (2936169) builds all four targets twice with matching sha256, and the changelog smoke check passes on each native runner. The release-notes step, run locally with that run's linux-x64 binary, fills the notes for a tag and for a dry run, and fails a tag with no section.
- Yaml (U-QTXSX4JL72LYHWD2): run 40144444462 (7544abd) builds all four targets twice with matching sha256, and the yaml smoke check passes on each native runner.

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
- 2026-10-24 slice bundle-sqlite-toml delivered (D-G22LKQURNNTN6A2E, D-2V3JOY5TUAMLRJAE)
- 2026-10-24 slice spork-https-overlay delivered (D-DBGBXVNNTRBBRHMQ)
- 2026-10-24 slice bundled-help delivered (D-6MHEZUS5HUJXWV6A)
- 2026-10-24 slice cli-stdin (U-XFHE3BIPNBP6KNS5) opened; `-h`/`--help` split off as B-WFNM7BIUL5G3FLYG (BR)
- 2026-10-24 slice cli-stdin delivered (L-BU3RJX7SGGPRKTTA)
- 2026-10-24 slice self-update delivered (D-44BH6MURMXC5JTOB, D-2UB7VI5YR6ZBQ4FD, L-OFSXUYK57K7GM4JD); v0.2.0 published (BR authorized)
- 2026-10-25 task changelog delivered (D-DYWSJTLDO6S5DQDR)
- 2026-10-25 task readme-pitch delivered: the README leads with the batteries-included pitch; benchmarks filed as B-QCBMFCPRFJGNUXAH
- 2026-10-25 task cli-help delivered: `-h`/`--help` print chirp's usage, then Janet's options (run 40140931270)
- 2026-10-25 task yaml delivered: `yaml` module on libyaml (D-VOBKZC6H4OPIMPQE, D-FD4ZWTDKYJBQBFRO); image builds hold the collector off so gensym names stay reproducible (L-2H7SFLEMCU2MPRZN)
- 2026-10-25 task dev-proc-chirp delivered: dev-proc runs on chirp, Node gone from the repo's workflow (D-VZIDK5O2VNATQDCP, D-4ACDYH2YT7UK3OC4, D-SEP44EOKHRFGMAWT); gaps in B-IRERZRV2753OHW3R
- 2026-10-25 slice ordered-map delivered: `omap`, an insertion-ordered map, and an ordered flag on json/decode, yaml/decode and yaml/decode-all (D-PYFZFKJPCW3QPOTB, D-ZXXSPKUCZ4IOIQPN, D-YMKKGLNX3IGQPAGJ, L-NYRT2RGVVAXTFIOF)
- 2026-10-25 v0.3.0 tagged (BR authorized); the README says chirp is not stable yet (BR)
