---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-29
success_criteria:
  - every documented binding whose definition chirp can locate (Janet forms in boot.janet, spork, spork-https and chirp's overlays; C functions in Janet core) carries its source text, baked into the binary at build time with nothing read at runtime
  - /read/<id> in chirp --help serve shows the source under the docstring, with its file and line, escaped; e.g. default-peg-grammar and os/spawn
  - chirp --help read <id> --source prints the source after the docstring; without --source the output is unchanged
  - an entry with no locatable source says nothing extra and nothing fails; the a/b builds stay byte-identical; no host path is baked in
  - binary growth stays near the measured ~560KB
  - smoke covers both the web and CLI paths and passes on CI; help topic and CHANGELOG mention it
---

# slice/help-source

## Purpose
BR asked to see the code behind a docstring (e.g. /read/default-peg-grammar): the definition explains what the docstring leaves out. It must work offline, like the rest of the help.

## Scope
In: source text for Janet-defined bindings and Janet core C functions; showing it in serve and via `--help read --source`.
Out: source for bindings from chirp-owned C natives beyond what falls out for free; search indexing of source text; syntax highlighting.

## Context & constraints
- BR (2026-10-29): bake both Janet forms and C bodies in, fully offline (~220KB + ~340KB on an 11MB binary); also a CLI `--source` flag.
- Measured: 501 Janet forms resolve by source-map; 31 do not (macro-generated defs, overlay paths); 364 core C functions extract from source-map line to the closing `}` line.
- D-6MHEZUS5HUJXWV6A: help text is baked in at build time; D-Q23RA2EVVN5LYCX7: builds must be reproducible; AGENTS.md: no host paths in the repo or binary.
- Source-map paths vary: `boot.janet`, `src/core/*.c` (janet tree), `src/spork/...`, `src/spork-https/...`, and absolute container paths for chirp's overlays.

## Now
Implemented and reviewed; pushing to CI.

## Next
- CI green (a/b identical on all targets), install, finalize

## Evidence
- coverage: 544 Janet forms, 384 C functions in janet core and spork zip.c, plus the five chirp-owned natives (md4c, pcre2, lexbor, omap, yaml) through a `./src/` rule; 0 misses among the scanned bindings
- binary 10,960,440 → 11,681,336 bytes (+720KB; the jsec/tomlin/zip.c/natives rules add ~160KB over the 560KB estimate)
- local a/b builds byte-identical (3b80b574…, before the natives rule); no new host paths (the only extra `/chirp-src` is the container mount prefix in config)
- local linux-x64 smoke: all checks passed, incl. --source for default-peg-grammar, os/spawn, spork/sh/exec-slurp; no source without --source; serve shows it escaped

## Harvest
- [ ] decision: binding source is baked at image build from the fetched sources, located by source-map prefix rules held as data; C bodies end at the first line that is just `}`
- [ ] learning: source-map paths differ by origin (boot.janet bare, core relative to the janet tree, modules relative to the out dir, overlays absolute at the container mount, natives `./src/`); builds outside the container get no overlay source

## Log
- 2026-10-29 initialized
- 2026-10-29 phase initialize → execute
