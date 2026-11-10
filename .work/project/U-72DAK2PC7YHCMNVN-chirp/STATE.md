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
- Decisions: run `$DP find` before acting. The founding set is D-ZBIADZDYXYPWLX5L, D-MNNDC6PNBUNZXT7O, D-GNHGVHYBQ7SLBAIU, D-2SHG5CGZYE2DZCQG, D-BPDFOMM2OH7HMPZB, D-DGT7DONSVJESO5FV (superseding D-B2RTYH6CNDO6SRF5), D-URDDGCK3H3MPSCTM, D-Q23RA2EVVN5LYCX7, D-J2C4TCJIQLJGENAG. D-ZBOSG3RYRJVCOMXZ (hash key) is still only proposed.

## Now
0.10.0 is published (2026-11-09) and main carries 0.11.0-dev. 0.10.0 makes bundled functionality findable (tasks, modules and surprises help topics, short-name import hint, tarray/new docs) and keeps jsec's error buffers per thread on windows; close-milestone closed #4, #6, #8 and #9.

## Next
- BR files the upstream janet issue (B-4XR7XIFFSIWKFM2Z) and the spork/getline one (B-DJQCZSQATWOHTVWU); noted, not yet filed
- BR files the jsec LICENSE + IOCP accept-state issue; the draft is in B-5AUA2Q7IH5DP2ZME
- BR files the spork tarray/new docs and view-offset issue; the draft is in B-RFIP6MFEVGQNJ46S
- Candidate for 0.11: bundle a CSV reader and writer (B-3U2LXKLBUDLJGUOO)

## Evidence
- Os-trust-stores (U-OWEKBTPLIF7KEK7U): run 41942352002 builds all four targets twice with matching sha256; every smoke passes, macOS https-get example.com from 153 keychain roots and windows from 417 store roots with no SSL_CERT_FILE; a start without TLS takes 14 ms on both.
- Windows-tls-connect (U-W5VAIQLMMBMTPTQ2): run 41898980038 (dcf6c0f) builds all four targets twice with matching sha256; windows smoke passes, tls-connect-wait included, which fails with #10's WSA error 10057 on the unpatched build (real windows A/B).
- Build-matrix (U-EP6NS3X66GBL2AQL): run 40095901156 builds all four targets twice with matching sha256, and smoke-runs each one on its native runner, HTTPS client and server included.
- Release-0-1-0 (U-ROTWPYUJJW5Q45E2): https://github.com/roobie/chirp/releases/tag/v0.1.0 (run 40103776646) ships the four binaries, notices and SHA256SUMS with provenance attestation; the binary and README mark chirp unofficial. This meets the release, reproducibility, provenance and unofficial criteria; SQLite and TOML remain.
- Bundle-sqlite-toml (U-OPXF3E6S7PBCFAHC): run 40107147500 builds all four targets twice with matching sha256, and the new sqlite and toml smoke checks pass on each target's native runner. They are not in a release yet.
- Spork-https-overlay (U-O25BRXG46K5BCRAS): run 40109671483 builds all four targets twice with matching sha256. The overlay smoke check (default User-Agent, explicit User-Agent, client `:ca` trusted) passes on each target's native runner.
- Bundled-help (U-U3CE4WWF4S2GLYDS): run 40112713990 (7dd70c7) builds all four targets twice with matching sha256, and the help smoke check passes on each target's native runner.
- Cli-stdin (U-XFHE3BIPNBP6KNS5): run 40114378370 (5add4ad) builds all four targets twice with matching sha256, and the stdin smoke check passes on each target's native runner.
- Self-update (U-UQ6SLNXUIHLJOPK7): https://github.com/roobie/chirp/releases/tag/v0.2.0 (run 40119267950) ships SHA256SUMS.sig signed in CI; the installed 0.2.0 release runs `chirp self-update` against it and reports it is up to date.
- Changelog (U-CU3LV3F4XSBIDE7S): run 40139405385 (2936169) builds all four targets twice with matching sha256, and the changelog smoke check passes on each native runner. The release-notes step, run locally with that run's linux-x64 binary, fills the notes for a tag and for a dry run, and fails a tag with no section.
- Yaml (U-QTXSX4JL72LYHWD2): run 40144444462 (7544abd) builds all four targets twice with matching sha256, and the yaml smoke check passes on each native runner.
- Release 0.3.0: https://github.com/roobie/chirp/releases/tag/v0.3.0 (run 40199982635) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig; the installed 0.3.0 reports it is up to date.
- Release 0.4.0: https://github.com/roobie/chirp/releases/tag/v0.4.0 (run 40610869384, 85a178e) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig; the downloaded linux-x64 binary matches SHA256SUMS and reports it is up to date. `pages` (run 40612260604) ran after `release`, and the live footer names 85a178e, so the tag path of U-F35YV2DPMJION4EG works.
- Md4c (U-XHNWANHLCDSBMPPJ): run 40588497160 (1d4ad8c) builds all four targets twice with matching sha256, and the md4c smoke check passes on each native runner. Released in 0.4.0.
- Lexbor (U-NNSKUDFMCFLCHBCG): run 40606736380 (ea95bef) builds all four targets twice with matching sha256, and the lexbor smoke check passes on each native runner; about 0.9 to 1.1 MB per target. Released in 0.4.0.
- Site-tests (U-7XS4EUR6DWMHLA5H): `pages` run 40615172598 (c56c109) checks the built site and the live one with lexbor, and both pass.
- Release 0.5.0: https://github.com/roobie/chirp/releases/tag/v0.5.0 (run 40981408317, c25063d) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig; the downloaded linux-x64 binary matches SHA256SUMS and reports it is up to date.
- Release 0.6.0: https://github.com/roobie/chirp/releases/tag/v0.6.0 (run 40984863210, 2aab8b8) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig; the downloaded linux-x64 binary matches SHA256SUMS and reports it is up to date.
- Release 0.8.0: https://github.com/roobie/chirp/releases/tag/v0.8.0 (run 42127782352, e71e94d) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig; the first publish attempt got an HTTP 500 from the GitHub API with no draft left, and a rerun of the failed jobs succeeded. The downloaded 0.7.0 linux-x64 binary self-updates to 0.8.0.
- Gh-pages-site (U-F35YV2DPMJION4EG): https://roobie.github.io/chirp/ is generated by chirp from the repo's Markdown (pages run 40592941083, 2ded17a), with a dev-proc section and examples linking to commits.
- Help-query-punctuation (U-IFCBDDBONSRACOXV): run 41359381161 (30c2e76) builds all four targets twice with matching sha256, and the help smoke check passes on each native runner.
- Repl-line-editing (U-7DWRIEYIJVLADLTE): run 41360301722 (ceb79f2) builds all four targets twice with matching sha256; the repl check drives a pty on both linux runners and passes.
- Help-snippets (U-7NTYGOQFXGEEDBHL): run 41359062211 (9c289e3) builds all four targets twice with matching sha256, and the help and help-serve smoke checks pass on each native runner.
- Spawn-cd (U-ADROWBCLHGO3WS3X): run 41356904368 (d319217) builds all four targets twice with matching sha256, and the spawn-cd smoke check passes on each native runner.
- Janet-1-43 (U-UJ6VC4JRORZAL3L5): run 42423791827 (7373448) builds all four targets twice with matching sha256 on the v1.43.0 janet pin; every smoke check passes on each native runner.
- Release 0.9.0: https://github.com/roobie/chirp/releases/tag/v0.9.0 (run 42465115915, e2e4785) ships the four binaries, notices, SHA256SUMS and SHA256SUMS.sig, each binary with one provenance attestation; the downloaded linux-x64 binary matches SHA256SUMS and reports Janet 1.43.0-chirp-e4b50456. pages (run 42466083349) ran after release and the live footer names e2e4785. Self-update from 0.8.0 is unverified: github.com/…/releases/download returned HTTP 504 for every release (0.8.0 too) at publish time.
- Self-update 0.8.0 -> 0.9.0 verified by BR on linux-x64 after the 504s cleared: the updated binary reports chirp 0.9.0 on Janet 1.43.0-chirp-e4b50456.
- Release 0.10.0: https://github.com/roobie/chirp/releases/tag/v0.10.0 (run 42551719483, 22443b2): not a draft, 10 assets, Latest, notes from the changelog section; milestone 0.10.0 closed with #4 #6 #8 #9 each commented 'Shipped in chirp 0.10.0'; 0.9.0 linux-x64 --self-update -> 0.10.0, which gives the json import hint and lists 54 modules; pages run 42552919062 green, help/tasks.html serves 200.

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
- 2026-10-27 slice md4c delivered: `md4c` module, Markdown to HTML (D-UCQGXYU3CLHRAYIT)
- 2026-10-27 slice gh-pages-site delivered: https://roobie.github.io/chirp/ (D-ME7B5XOAG245FN65, L-QMATIVF5W37HM6U4, L-EGSSVSI3WKR7ORNR); homepage URL is B-YHXYPFVYVAOKLA2Z
- 2026-10-28 slice lexbor delivered: `lexbor` module, HTML parsing and CSS selectors (D-AYM6G4PAISONUDLK); site tests in B-VDJWHBDAHVSYULLB
- 2026-10-28 slice site-tests delivered: `site/check.janet` checks the built and live site in `pages` (D-BRHSLBZO62TBVJZA)
- 2026-10-30 task sqlite-help-rows-structs delivered: the sqlite help says query rows are structs, not tables
- 2026-10-30 v0.5.0 tagged (BR) and released (run 40981408317); main moves to 0.6.0-dev
- 2026-10-30 slice dev-proc-ergonomics delivered: one-command units and records, `note`, `trailers`, local dates; `--` terminator in B-DDPZPOA7SAX5D6LX, stale-ref hints in B-PC45JD26WTVBOKGI
- 2026-10-30 v0.6.0 tagged (BR) and released (run 40984863210); main moves to 0.7.0-dev; self-update gap filed as #7
- 2026-10-30 slice release-cut delivered: tools/release/cut.janet makes the release edits and the move to the next -dev; the tag stays manual (D-MB5WIOASYBDI7AEB)
- 2026-11-01 task self-update-readonly-dir delivered: a read-only install directory gets a verified release and an install command, plus --output (D-V26BZ2WR76SFIGIG, L-YVDCKE6OQ563NH7P); refs #7, which closes with the release
- 2026-11-01 task help-query-hyphen delivered: hyphenated names search as phrases and rank their own entries first (L-BRH7VAMIKGUSTHKF)
- 2026-11-01 slice spawn-cd (U-ADROWBCLHGO3WS3X) opened for #5; milestone 0.7.0 created on GitHub with #7
- 2026-11-01 task note-terminator delivered: -- ends dev-proc's options, so note text can start with --
- 2026-11-01 slice spawn-cd delivered: os/spawn and os/execute :cd on linux, help topic subprocess (L-2XVJIJPBAN5P3IC6); upstream report in B-4XR7XIFFSIWKFM2Z; refs #5, which closes with the release
- 2026-11-02 task help-snippets delivered
- 2026-11-02 task release-closes-milestone delivered; first live run at v0.7.0
- 2026-11-02 tasks help-query-punctuation and repl-line-editing delivered
- 2026-11-02 milestone 0.5.0 closed by BR
- 2026-11-02 slice gzip-tar done: gzip native and tar module, CI green on all targets
- 2026-11-02 cutting 0.7.0: merged the two help-query changelog entries
- 2026-11-02 0.7.0 published by BR's tag; release run 41373678975 green, close-milestone closed #5, #7 and the milestone, self-update 0.6.0 -> 0.7.0 verified; main moves to 0.8.0-dev
- 2026-11-02 task mingw-notices done: B-RUMT answered (no LGPL), gdtoa and winpthreads notices added
- 2026-11-02 jsec still has no LICENSE upstream; issue draft given to BR
- 2026-11-05 slice os-trust-stores delivered: TLS trusts the macOS keychain and the windows store, exported when TLS is first needed; no trust ships in the binary (D-DGT7DONSVJESO5FV supersedes D-B2RTYH6CNDO6SRF5, D-3IC4LK7ZRJETEVVU). An embedded-roots attempt was rejected by BR and dropped
- 2026-11-05 cutting 0.8.0: cut.janet dropped -dev and dated the changelog; the tag is BR's
- 2026-11-05 0.8.0 published by BR's tag (annotated; no tag is GPG-signed); release run 42127782352 green after rerunning a GitHub HTTP 500 in publish, close-milestone closed #10 and the milestone, self-update 0.7.0 -> 0.8.0 verified; main moves to 0.9.0-dev
- 2026-11-06 chirp-release skill written: the full release procedure, preflight to the next -dev, from the 0.7.0 and 0.8.0 releases
- 2026-11-06 asking-astra skill deleted; every repo skill lives in .agents/skills with a .claude/skills link (D-HLIOIUOA4NCCKNJI supersedes D-RFOFYVBEDCXF6BZW)
- 2026-11-06 skillcheck added to pre-commit and CI: enforces D-HLIOIUOA4NCCKNJI's skill layout on the index
- 2026-11-08 slice janet-1-43 (U-UJ6VC4JRORZAL3L5) delivered: janet pinned at the v1.43.0 tag
- 2026-11-08 cutting 0.9.0: Janet moves to the v1.43.0 tag (U-UJ6VC4JRORZAL3L5)
- 2026-11-08 0.9.0 published; main moves to 0.10.0-dev
- 2026-11-08 0.9.0 self-update from 0.8.0 verified
- 2026-11-08 Skill-script-path-relative (U-W65HNFYGPTVNQ5ID): dev-proc's SKILL.md names its script relative to the skill dir, so a -g install works (B-JRBZDUDQ5C5MOATN); unreleased.
- 2026-11-08 Version-homepage (U-WNR4AN6LILGRPYGJ): --version names the project site, closing B-YHXYPFVYVAOKLA2Z (the repo homepage was already set); unreleased.
- 2026-11-08 ca-roots smoke fixed for the two-line -v (CI on fb31723 failed on macOS and windows).
- 2026-11-08 pages.yml reads the version from the first line of --version.
- 2026-11-08 Help-by-goal (U-UQ43QSH4RXEYEAAX) delivered: the tasks help topic, goal-ranked queries, a build guard and a smoke check (D-L3TWBKWDF7V2KM4I); unreleased.
- 2026-11-09 Import hint for short names (U-LF7MVZMNU7JQHUD5) delivered, unreleased; #8 fully addressed on main.
- 2026-11-09 Milestone 0.10.0 created with #4, #6, #8; each got a comment pointing at chirp --help read tasks.
- 2026-11-09 tarray/new docs overlay (U-B4RZB3IGUELBCSVF) delivered for #9; upstream draft in B-RFIP6MFEVGQNJ46S for BR.
- 2026-11-09 0.10.0 scope finished: modules topic (U-HZVT), surprises topic (U-3PZS), jsec TLS buffers per thread on windows (U-DYQL, L-MMOQJTXSQIJQ4CCS).
- 2026-11-09 0.10.0 preflight: changelog notes that scripts reading --version take its first line.
- 2026-11-09 cutting 0.10.0: help by goal (tasks, modules, surprises), short-name import hint, tarray/new docs, windows jsec thread-local buffers; closes #4, #6, #8, #9.
- 2026-11-09 0.10.0 published by BR's tag; release run 42551719483 green, no reruns; main moves to 0.11.0-dev
- 2026-11-10 0.11.0 preflight: dry run 42850689842 green; changelog self-update entries merged
- 2026-11-10 task main-builds delivered: builds of main on the site, signed, installable with --channel main
