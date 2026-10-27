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
Surveying lexbor v3.0.1 sources for the module list.

## Next
- Survey lexbor v3.0.1's source tree: which directories the chosen modules need, and their cross-dependencies.
- Binding: nodes are abstract handles that keep their document alive; `select` works on a document or a node.
- Pin, build locally in the linux-x64 container, measure size.

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] decision: lexbor nodes are abstract handles holding their document (BR, 2026-10-28), not copied plain data

## Log
- 2026-10-27 initialized
- 2026-10-27 phase initialize → execute
