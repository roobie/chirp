---
created: 2026-10-25
---

# B-BKFYQS4SYMMLZUSA self-update fails where the binary's directory is not writable

## Why
Updating from 0.3.0-dev to the 0.3.0 release, `chirp self-update --force` stopped with `cannot write /usr/local/bin/chirp.new`. The binary itself was writable by its owner, but its directory was not, which is a common install layout. A plain copy over the file worked, so self-update failed where a simpler method succeeded.

## Notes
- Writing `chirp.new` beside the binary and renaming it is atomic, which is why it was chosen; keep that when the directory allows it.
- Options: fall back to writing over the file in place when the directory is not writable (not atomic, so a crash can leave a broken binary), or fail with a message naming the directory and saying what permission is missing.
