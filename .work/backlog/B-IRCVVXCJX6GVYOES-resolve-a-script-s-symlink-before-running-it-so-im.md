---
created: 2026-11-24
---

# B-IRCVVXCJX6GVYOES resolve a script's symlink before running it, so ./ imports are found beside the real file

## Why
`chirp path/link.janet` runs a script through a link, and `(import ./helper)` then looks beside the link, not beside the real file. Every tool linked into a PATH directory has to set `*current-file*` to its real path before it imports anything. chirp runs the script, so it could resolve the link once for all of them (issue #21, usage feedback, 2026-11-18).

## Notes
- Janet's own runner behaves the same, so this would be a chirp difference from stock janet: decide whether a script's `./` means beside its real file or beside the name it was run by, and say so in the surprises help topic either way.
- `chirp script` goes through Janet's `cli-main`, which chirp does not patch (D-MNNDC6PNBUNZXT7O); the place to resolve the path is before `main` in `src/chirp/main.janet` hands the arguments over.
- Windows: realpath does not report a link there (see B-GJ36TPGEOECQYDFU).
