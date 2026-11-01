---
date: 2026-11-01
read_if:
  - replacing or patching a running executable
  - self-update fails to write in an install directory
refs:
  - src/chirp/update.janet#can-create?
---

# L-YVDCKE6OQ563NH7P A running binary cannot open its own file for writing on linux, so replacing it needs the directory

## Observation
On linux 6.12, a running chirp that opens its own path for writing gets ETXTBSY, which Janet reports as `could not open file … with mode wb`. Another process writes the same file fine once chirp has exited, which is why `cp` over the binary worked for the reporter of #7 while self-update failed. The only replacement a running binary can do itself is a new file renamed over the old one, and a rename needs write permission on the directory.

## Why it matters
Any "write in place when the directory is read-only" fallback for self-update cannot work on linux, so the choice is between a directory write and handing the file to the user.
