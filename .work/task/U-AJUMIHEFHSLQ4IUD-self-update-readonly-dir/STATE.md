---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-01
success_criteria:
  - With the binary writable but its directory not, chirp --self-update exits 1, leaves the binary unchanged, saves a verified new binary at a printed path and prints a command that installs it
  - With a writable directory the swap is still the atomic rename
  - chirp --self-update --output PATH saves the verified release binary at PATH (or inside PATH when it is a directory) and leaves the running binary alone
  - The self-update smoke check covers the read-only directory and --output, and passes on every native runner in CI
  - CHANGELOG Unreleased names the fix and --output; the commit references GitHub
---

# task/self-update-readonly-dir

## Purpose
Fix GitHub #7: chirp --self-update fails with a raw 'cannot write <exe>.new' when the binary is writable but its directory is not.

## Scope
In: src/chirp/update.janet, its smoke check, its help text, CHANGELOG.
Out: writing over the running binary in place (ETXTBSY on linux); a helper process that copies after chirp exits (BR chose option B, 2026-11-01).

## Context & constraints
Signature and hash checks stay as D-44BH6MURMXC5JTOB says; --output is checked the same way.

### Origin
Promoted from backlog: B-BKFYQS4SYMMLZUSA self-update fails where the binary's directory is not writable

### Why
Updating from 0.3.0-dev to the 0.3.0 release, `chirp self-update --force` stopped with `cannot write /usr/local/bin/chirp.new`. The binary itself was writable by its owner, but its directory was not, which is a common install layout. A plain copy over the file worked, so self-update failed where a simpler method succeeded.

### Notes
- Writing `chirp.new` beside the binary and renaming it is atomic, which is why it was chosen; keep that when the directory allows it.
- Options: fall back to writing over the file in place when the directory is not writable (not atomic, so a crash can leave a broken binary), or fail with a message naming the directory and saying what permission is missing.


## Now
Code, help, smoke check and CHANGELOG done; committing, then CI must pass on all four native runners

## Next
Push; watch ci.yml smoke on linux-x64, linux-arm64, macos-arm64 (read-only case runs) and windows-x64 (skips it); then finalize

## Evidence
<!-- Proof against success_criteria: test runs, commits, measurements. -->
- Local linux-x64 container build (0.7.0-dev, uncommitted tree): test/smoke/run.janet passes, self-update included; its read-only-directory case ran (no skip line), and so did --output DIR and FILE
- Manual run in a 555 directory: exit 1, binary byte-identical, message names the directory, the saved path and 'cp <saved> <exe>'; that cp works in a 555 directory once chirp has exited

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->
- [ ] learning: a running binary cannot overwrite its own file on linux (ETXTBSY); replacing it needs a write to the directory
- [ ] learning: macOS kills a signed binary rewritten in place, so the macOS install hint replaces the file whole (from Apple's guidance, not tested here)

## Log
- 2026-11-01 initialized
- 2026-11-01 Linux 6.12: a running chirp cannot open its own file for writing (ETXTBSY, 'could not open file … with mode wb'), so an in-place fallback is impossible; the reporter's working cp ran after chirp exited
- 2026-11-01 BR chose B: on a read-only directory save a verified binary elsewhere and print the install command; add --output
- 2026-11-01 phase initialize → execute
