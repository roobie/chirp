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

## Evidence
<!-- One line per success criterion, each naming its newest proof, then the latest release. Earlier lines are in this file's history (dev-proc dig U-72DAK2PC7YHCMNVN), the changelog and the releases page. -->
- Runs HTTPS client and server with nothing else installed: the smoke checks https-get and https-server pass with each release binary on a bare runner of its own platform (linux x64 and arm64, macOS arm64, windows x64), with trust from the OS only; ci run 44917829007 on main, release run 44779178595.
- SQLite, zlib-format compression and TOML in the same binary: the smoke checks sqlite, zip, gzip and toml pass on the same four runners in the same runs.
- Release binaries for linux x64/arm64 (static musl), macOS arm64 and windows x64: v0.13.1 ships the four, with a NOTICES file each, SHA256SUMS and SHA256SUMS.sig (10 assets).
- Each target built twice with matching sha256: the compare job of every ci run, a release's included; run 44779178595 for 0.13.1.
- Build-provenance attestation: the release workflow attests every asset; `gh attestation verify chirp-0.13.1-linux-x64 --repo roobie/chirp` succeeds (checked 2026-11-24).
- Marked unofficial: the README's third paragraph, and the smoke driver's version check requires "unofficial build" in the identity line that `--version` and the REPL banner print.
- Release 0.13.1: https://github.com/roobie/chirp/releases/tag/v0.13.1 (run 44779178595, d74b08e); 10 assets, Latest, notes carry the changelog; #22 closed with Shipped comment, milestone 0.13.1 closed; self-update 0.13.0 -> 0.13.1 on linux-x64 shows the import hint; pages 44784681434 green

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
- 2026-11-10 BR confirmed the agents' push token holds neither Deployments: write nor Administration: write (B-7W2ZOVM433NUASIC done)
- 2026-11-10 cutting 0.11.0: dev-proc status --json detail, the try page, signed builds of main with --self-update --channel main, --force/--output on same-version builds; first release signed in the release environment
- 2026-11-10 0.11.0 published by BR's tag and approval; release run 42887783417 green, no reruns; main moves to 0.12.0-dev
- 2026-11-10 merged main (exit codes) into the refuse-links branch; refused-only roots are reported
- 2026-11-10 new --execute reads back only the new unit, not the root a second time
- 2026-11-10 backlog: B-ZRD2QVEPG55JNVHB, the wasm page test's teardown race
- 2026-11-11 drive: triaged the backlog for bugs and gaps; started task dev-proc-unknown-flags (U-6KHEW3PKWAZMEY2P) and task wasm-page-teardown (U-57IPBB7R7XNWU54A)
- 2026-11-11 drive: merged and closed task dev-proc-unknown-flags (U-6KHEW3PKWAZMEY2P); D-2XADU7R2GPTW35JR, B-NYH6ZSXTHFNZJI42
- 2026-11-11 drive: started task config-jdn-hash-input
- 2026-11-11 drive: merged and closed task wasm-page-teardown (U-57IPBB7R7XNWU54A)
- 2026-11-11 drive: started task omap-marshal-equality (U-6NPPSQ6RM3R2JSNE)
- 2026-11-11 drive: closed task config-jdn-hash-input (U-ILCUNCJK3HY56H64): the cause was collector timing, already fixed on main by 7544abd; notices.jdn's stale reason gated for the owner as B-XVGIPKGVKMLHDM33
- 2026-11-11 drive: started task dev-proc-help-flag (U-Z7VUMCHAJIKFBRVN)
- 2026-11-11 drive: owner released B-XVGIPKGVKMLHDM33 (fold notices back into config.jdn); started task fold-notices-into-config (U-G3O6A66OPIB76WSL)
- 2026-11-11 drive: merged and closed task dev-proc-help-flag (U-Z7VUMCHAJIKFBRVN)
- 2026-11-11 drive: folded notices.jdn into config.jdn (D-MFWFKRO3I2W4SWIR supersedes D-KPP2PSBZKFSROC44); binary and NOTICES.txt unchanged
- 2026-11-11 drive: omap marshal, omap/equal? and per-thread guard merged after Opus review (D-JJECECVXGNYXPGEI)
- 2026-11-11 release prep for 0.12.0: changelog gains the dev-proc unknown-flag entry; CI on main red on the page test's profile removal (U-NLRVSKT5FG5RSCPE)
- 2026-11-12 page test closes Chrome over CDP and waits for its process group; ci green on 1f40e2d (run 43120891764)
- 2026-11-12 cutting 0.12.0: omap marshal and omap/equal?, dev-proc exit codes 3 and 4, unknown-flag rejection and refusal of links and oversize documents
- 2026-11-12 0.12.0 published by BR's tag; release run 43130401158 green, pages 43136013915 green, self-update from 0.11.0 checked; main moves to 0.13.0-dev
- 2026-11-15 dev-proc-vendored: dev-proc is now a vendored copy of the owner's private upstream; installer refuses links out of the install dir
- 2026-11-15 dev-proc-vendored: guard refuses any link at the skill dir (second review)
- 2026-11-20 backlog B-6J3NWA2BAPI47KRS (windows trusts only roots Windows has fetched, seen on real windows with 0.12.0 and 0.13.0-dev) and B-4M5X7UXLRSECYKVJ (smoke dev-proc-install needs forward slashes)
- 2026-11-20 changelog: windows root-fetch known issue for 0.13.0
- 2026-11-20 cutting 0.13.0: jsec 0.2.0 (:ca trusts only that CA), dev-proc status --detail, installer refuses links, leaf-only cursor; windows root-fetch shipped as a known issue
- 2026-11-20 Now and Next folded away per the leaf-only cursor change; the owner's filing to-dos live in their backlog items (B-4XR7XIFFSIWKFM2Z, B-DJQCZSQATWOHTVWU, B-5AUA2Q7IH5DP2ZME, B-RFIP6MFEVGQNJ46S)
- 2026-11-20 0.13.0 published (tag pushed by claude at BR's request, deployment approved by BR); release run 44749283441 green on rerun of a runner-starved macOS smoke; main moves to 0.13.1-dev
- 2026-11-20 task smoke-backslash-path (U-677JJHLNJ7TOTJNU) closed: dev-proc-install smoke splits its path on either separator, for 0.13.1
- 2026-11-20 merged task symbol-hint (U-UCKHQHZ37KFUEWBE) for 0.13.1: an unknown symbol a bundled module exports names the import that works (#22, D-H7CGKNTIHVUM66TC)
- 2026-11-20 cutting 0.13.1: the unknown-symbol import hint (#22)
- 2026-11-20 0.13.1 published from tag v0.13.1; release run 44779178595 green first try; main moves to 0.13.2-dev
- 2026-11-21 2026-11-21 out/ (the build's work tree) is ignored
- 2026-11-24 milestone maintainability (U-HM3MZPOZSVLCXGNP) opened from the 2026-11-24 review; in initialize until the owner answers its open questions
- 2026-11-24 milestone maintainability wave A: pin-reader, repo-tests and build-guards delivered (ci run 45371721511); CI's checks run on a pinned released chirp (D-235CO5X6BG3S743P); merged branches deleted from origin; issue 21 is B-IRCVVXCJX6GVYOES
- 2026-11-24 milestone maintainability wave B: pin-guards, path-helpers and ci-work-only delivered; a .work/-only push no longer builds (D-SBFT5Y7OGHMOVIY6)
