---
created: 2026-10-25
---

# B-HFEHNNAUWFDXTAMQ Propose upstream that Janet's cli-main exits 1 on an unknown flag

## Why
`chirp -x` prints "unknown flag -x" and the usage, then exits 0, so a script or CI step with a mistyped flag looks like it succeeded. The handler is private to Janet's boot.janet, and chirp does not patch Janet's core (D-MNNDC6PNBUNZXT7O), so the fix belongs upstream. It came up in task cli-help (2026-10-25).

## Notes
- Check upstream janet-lang/janet issues and PRs first; someone may have raised it already.
- No GitHub issues are to be filed for now (BR), so this waits until that changes.
