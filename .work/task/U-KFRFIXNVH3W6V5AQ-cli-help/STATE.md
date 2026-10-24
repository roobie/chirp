---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-25
success_criteria:
  - chirp -h and chirp --help print chirp's own commands (help, -, -v, --changelog, self-update) first, then Janet's option list, and exit 0
  - The chirp part is a section of help/chirp.md, so it is also readable with chirp help read and found by chirp help query
  - A smoke check covers -h and --help on every target, and CI is green
---

# task/cli-help

## Purpose
`chirp -h` and `chirp --help` print only Janet's option list, so someone who reaches for `-h` never learns about chirp's own commands or its offline docs.

## Scope
In: `-h`/`--help` as the first argument; a usage section in help/chirp.md; the smoke check.
Out: Janet's exit status 0 on an unknown flag. It lives in Janet's private `cli-main` handlers, and chirp does not patch Janet's core (D-MNNDC6PNBUNZXT7O), so it is an upstream fix, kept as a backlog item. Whether the bundle flags (`-b`, `-u`, `-U`, `-L`, …) make sense for chirp belongs to B-DZXWHDHHXMIJKCKR (janet-pm).

## Context & constraints
- Janet's `-h` handler prints its list and calls `os/exit 0`, so chirp prints its part first and then hands `-h` to `cli-main`.
- D-6MHEZUS5HUJXWV6A: the text is content from help markdown, baked in at build time.
- Like chirp's `-v`, this applies only when the flag is the first argument; later flags go to Janet unchanged.

### Origin
Promoted from backlog: B-WFNM7BIUL5G3FLYG chirp -h and --help point at chirp's own additions (BR, 2026-10-24).

## Now
Implemented: a `## Usage` section in help/chirp.md, printed without its code fences by `-h`/`--help`, then Janet's list. The local linux-x64 smoke run passed (before the fence filter was added).

## Next
- Push and watch CI.

## Evidence

## Harvest
- [ ] backlog: Janet's cli-main exits 0 on an unknown flag; propose an exit status 1 upstream

## Log
- 2026-10-25 initialized from B-WFNM7BIUL5G3FLYG; BR said go ahead
- 2026-10-24 phase initialize → execute
