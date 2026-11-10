---
created: 2026-11-10
---

# B-DDS77NF4GPLATVIL Let self-update tell one main build from a later one

## Why
Every build from main reports the same X.Y.Z-dev version. `--self-update --force` installs a later main build anyway and `--output` saves it, so taking one works (D-6NWFV37OBOERI3AF). What remains is that a plain `--self-update --check` cannot tell one main build from another, and the running chirp cannot be told apart from the tree's by version. A build identifier in the version (build metadata or a pre-release counter) taken from the commit would let the comparison work, but the version is in the source so that CI's double build stays identical (D-2UB7VI5YR6ZBQ4FD). Needs a design that keeps both.

## Notes
TODO
