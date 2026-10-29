---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-29
success_criteria:
  - chirp's own commands are all `--` flags; `chirp --help query <words>`, `chirp --help read <id>` and `chirp --self-update [--check] [--force]` do what `chirp help …` and `chirp self-update` did
  - chirp -h / --help alone prints the usage, the help topic list, then Janet's options
  - a script file named `help` or `self-update` runs with `chirp help` / `chirp self-update`; no fallback or hint for the old words
  - help text, README, site, release workflow and release notes use only the new forms; CHANGELOG has a Changed entry saying the old words are gone
  - smoke tests cover the new flags and a script named help, and pass on a CI build
---

# slice/cli-flags

## Purpose
GitHub issue #3: `chirp help` and `chirp self-update` take bare words a script could be named, so such a script cannot be run. Every chirp-owned entry point becomes a `--` flag, like `--changelog` and `--dev-proc` already are.

## Scope
In: `--help` taking `query`/`read`; `--self-update`; the topic list folded into `--help`; every doc, test and workflow that names the old forms.
Out: renaming Janet's own single-letter options; the FTS5 hyphen problem (B-F3UWCYQL25PUZXO2).

## Context & constraints
- BR (2026-10-29): `--help` takes the words (not a separate `--docs`, not top-level `--query`/`--read`). Clean break: only BR ever used 0.2.0–0.4.0, so no hint or deprecation for the old words.
- Janet's cli-main treats any `--…` as end of options, and its options are single letters, so `--` names are free for chirp.
- release.yml runs the binary it just built (`help read`), so it must change in the same commit.

## Now
Change made (Sonnet subagent, reviewed); waiting on CI.

## Next
- CI green on every target, then finalize

## Evidence
- 2026-10-29 local linux-x64 container build: smoke all checks pass, incl. new script-names (files `help` and `self-update` run as scripts), help (bare --help = usage + topics + Janet's options; `--help bogus` exits 2), cli-help, changelog and self-update on the new flags. Site build: 11 pages.

## Harvest
- [ ] decision: chirp's own entry points are `--` flags, bare words are always scripts; --help takes query/read

## Log
- 2026-10-29 initialized
- 2026-10-29 phase initialize → execute
