---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - chirp --help query dev-proc, self-update and spork-https each exit 0 and list hits for that name
  - The serve search box answers 200 with hits for a hyphenated name
  - 'FTS5 syntax still works: quoted phrases, NEAR, OR, column filters and prefix *'
  - The help smoke check covers a hyphenated query and passes in CI; CHANGELOG Unreleased names the fix
---

# task/help-query-hyphen

## Purpose
chirp --help query dev-proc (and the serve search box) fails with 'no such column: proc'; a hyphenated name should just be found.

## Scope
In: TODO
Out: TODO

## Context & constraints
TODO: what is already true, what must stay true, resources available.

### Origin
Promoted from backlog: B-F3UWCYQL25PUZXO2 chirp help query fails on a bare hyphenated word

### Why
`chirp help query dev-proc` fails with "invalid query: no such column: proc", because FTS5 reads `-` as an operator. People look up names like dev-proc, self-update and spork-https, so the first query they try fails with an error that makes no sense to them.

### Notes
`chirp help query '"dev-proc"'` works. Options: quote bare terms that contain `-` before the query reaches FTS5, or catch the error and suggest the quoted form.


## Now
Committed; waiting for CI

## Next
Watch ci.yml on the four native runners; then finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local linux-x64 container build: full smoke suite passes, including the new hyphenated-query checks in help and help-serve; chirp --help query spork-https lists spork-https/delete, /get, /head first (before: from rank 12, behind spork/http)
- search checked against a test index: dev-proc*, id:spork-https, NEAR(spork-https get, 5), get OR spork-https and an explicitly quoted phrase all work; a malformed query still reports the FTS5 error

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: the help index's porter stemmer turns https into http, so a phrase like spork-https matches spork/http as well

## Log
- 2026-11-01 initialized
- 2026-11-01 phase initialize → execute
- 2026-11-01 the porter stemmer makes the phrase spork-https also match spork/http, which outranked the name's own entries; entries whose id or title hold a hyphenated term literally now rank first
