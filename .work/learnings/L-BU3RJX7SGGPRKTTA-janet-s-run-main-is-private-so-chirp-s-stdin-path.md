---
date: 2026-10-24
read_if:
  - bumping the Janet pin
  - changing how chirp runs piped stdin or chirp -
refs:
  - src/chirp/main.janet#run-stdin
---

# L-BU3RJX7SGGPRKTTA Janet's run-main is private, so chirp's stdin path mirrors it

## Observation
Janet's `cli-main` runs a script's `main` through a private helper in boot.janet, so chirp cannot call it when it runs stdin as a script. chirp keeps its own copy of that behaviour instead, without patching Janet (D-MNNDC6PNBUNZXT7O).

## Why it matters
A Janet pin bump can change how `main` is run for script files, for example its fiber, debugger or exit handling, and the stdin path then drifts from the file path without any error. Compare the two on every pin bump. This stops being true if Janet exports that helper.
