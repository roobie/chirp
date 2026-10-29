---
created: 2026-10-29
---

# B-F3UWCYQL25PUZXO2 chirp help query fails on a bare hyphenated word

## Why
`chirp help query dev-proc` fails with "invalid query: no such column: proc", because FTS5 reads `-` as an operator. People look up names like dev-proc, self-update and spork-https, so the first query they try fails with an error that makes no sense to them.

## Notes
`chirp help query '"dev-proc"'` works. Options: quote bare terms that contain `-` before the query reaches FTS5, or catch the error and suggest the quoted form.
