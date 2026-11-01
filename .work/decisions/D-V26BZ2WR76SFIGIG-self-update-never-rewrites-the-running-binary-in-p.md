---
status: accepted
date: 2026-11-01
read_if:
  - changing how chirp self-update replaces or saves the binary
refs:
  - src/chirp/update.janet#self-update
  - src/chirp/update.janet#install-command
---

# D-V26BZ2WR76SFIGIG self-update never rewrites the running binary in place; on a read-only directory it hands over a verified file

## Context
GitHub #7: the binary was writable by its owner but its directory was not, and self-update failed with a raw `cannot write …/chirp.new`. BR chose this on 2026-11-01.

## Decision
The swap stays a new file renamed over the old one. When the directory is not writable, chirp still downloads and verifies the release, saves it in a fresh temporary directory, exits non-zero and prints a command that installs it. `--output PATH` saves a verified release without touching the running binary.

## Why
- **Writing in place:** impossible on linux (ETXTBSY), not atomic anywhere, and unsafe for signed macOS binaries.
- **A helper process that copies after chirp exits:** more moving parts, still not atomic, and it fails the same way without permission.
- **Only a clearer error:** leaves the user to fetch and check the release by hand, losing the signature check that is the point of self-update (D-44BH6MURMXC5JTOB).

## Consequences
- chirp never asks for elevated rights; the printed command may need sudo.
- A read-only-directory update exits 1 even though the release was fetched, so scripts see that chirp itself was not replaced.
- The suggested command differs per OS: `cp` on linux, which needs only the file; `sudo install` on macOS, because rewriting a signed binary in place gets it killed there (Apple's guidance, not tested here); `copy /Y` on windows.
