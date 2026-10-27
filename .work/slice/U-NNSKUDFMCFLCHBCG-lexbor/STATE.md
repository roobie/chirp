---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-27
success_criteria:
  - chirp bundles lexbor v3.0.1 as a `lexbor` module that parses an HTML document and answers CSS selectors (all and first match), with text content, attributes and outer HTML of a node
  - the lexbor smoke check (a selector over a parsed document) passes on all four targets' native runners, and CI's double build is sha256-identical
  - only lexbor's needed modules are built, and the binary-size cost per target is measured and noted in Evidence
  - README, CHANGELOG, chirp help topic, release notes and NOTICES (Apache-2.0 with lexbor's NOTICE) name lexbor
---

# slice/lexbor

## Purpose
Real HTML parsing with CSS selectors in chirp, so scripts can fetch a page over spork-https and assert on its structure instead of matching raw text.

## Scope
In: pin lexbor v3.0.1 (commit 7e278c0); a chirp-owned binding with parse, select-all, select-first, text, attribute(s), outer HTML, version; build only core, html, dom, tag, ns, css and selectors; notices, smoke check, docs.
Out: DOM mutation; serialising edited documents; the site's integration tests themselves (first user, follow-up once this lands); exposing lexbor's tokenizer or CSS parser beyond selectors.

## Context & constraints
- Follows the md4c/pcre2/libyaml pattern: pin data (D-ZOBE3ZBK764B22JY), repo-owned binding beside the pinned library (D-FD4ZWTDKYJBQBFRO), entry in `tools/build/natives.jdn`, notice in `notices.jdn` (D-KPP2PSBZKFSROC44).
- Every C symbol lands in one binary (L-BVXC557ZOWPP4SN5): binding functions are `chirp_lexbor_fn_*`. lexbor's own globals are already `lexbor_`/`lxb_`-prefixed; check `nm` for any that are not.
- lexbor is Apache-2.0; chirp's binary is MIT (D-UQZLUV7LGGRXHXPJ), so NOTICES must carry its licence and NOTICE file.
- lexbor builds with CMake upstream; chirp's build compiles listed sources directly, so the source list per module must be worked out.
- Node lifetime: Janet values that wrap nodes must keep their document alive (GC), and freeing the document must not leave dangling nodes.

## Now
Binding, build wiring and docs done; linux-x64 builds and passes smoke locally. Next is CI on all four targets.

## Next
- Push; CI on all four targets (double build identical, smoke on native runners). Record each target's size delta in Evidence.
- If green, finalize.

## Evidence
- Modules: core, tag, ns, dom, html, css, selectors plus the ports allocator (188 C files). They compile clean under `-std=c99 -Wall -pedantic`; html needs no encoding module.
- `nm`: all 1671 lexbor globals already carry `lexbor_`/`lxb_`, so no `:defines` renames; the binding exports only `chirp_lexbor_fn_*` and `janet_module_entry_lexbor`.
- Binding plus smoke test run clean under ASan+UBSan against a local janet, with no leaks reported (bad selectors included; lexbor state is freed before raising).
- Local linux-x64 container build: every smoke check passes, lexbor included; `chirp help query lexbor` lists all ten functions; NOTICES.txt carries lexbor's LICENSE and NOTICE.
- Size, linux-x64: 9,767,304 → 10,862,136 bytes (+1,094,832, +11.2%) for lexbor alone; 10,866,232 with the docs embedded.
- Real pages: the generated `out/site` pages (nav present, ids unique) and the live https://roobie.github.io/chirp/ over spork-https parse and select as expected.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: lexbor is a chirp-owned binding over html, dom and selectors only; nodes are abstract handles holding their document (BR, 2026-10-28), not copied plain data; matches come once each in document order (MATCH_FIRST); a bad selector is an error carrying lexbor's log
- [ ] backlog: integration tests for the Pages site with lexbor, on out/site and on the live site after deploy (the first user named in the slice's origin)

## Log
- 2026-10-27 initialized
- 2026-10-27 phase initialize → execute
- 2026-10-28 binding, wiring and docs; linux-x64 local build green
