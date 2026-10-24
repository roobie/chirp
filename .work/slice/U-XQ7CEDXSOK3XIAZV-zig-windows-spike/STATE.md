---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A chirp.exe for x86_64-windows-gnu, with static OpenSSL and every native module from the linux build, is built on linux by a pinned zig whose tarball sha256 is checked
  - Under Wine, chirp.exe prints its identity line, passes the zip round-trip, and completes an HTTPS GET with certificate verification on
  - Two windows builds in different directories produce identical sha256
---

# slice/zig-windows-spike

## Purpose
Test D-I6U4X6Q5KJD2Y4SM on the hardest target before we commit to it: if zig can cross-build a working, reproducible windows chirp from linux, one toolchain can build every target.

## Scope
In: a pinned zig; a target dimension in the build data (zig triple, OpenSSL target, link libs, exe suffix); building the image on the build machine and linking a windows binary; Wine-based checks.
Out: macOS and arm64; moving linux x64 onto zig (it follows if this passes); the spork-https server check on windows; embedded CA roots (the Wine check points SSL_CERT_FILE at a bundle).

## Context & constraints
- Builds on the linux spike (U-34F3JPNU2EK44A7I): the same build.janet, pins.jdn and natives.jdn, extended with a target dimension rather than forked.
- The image is built by a janet for the build machine, which loads natives built for the build machine. The windows link uses natives built for windows.
- Host has docker, with no zig or Wine installed.

## Now
A Sonnet subagent is implementing and running the checks.

## Next
- Review and commit; accept or reject D-I6U4X6Q5KJD2Y4SM based on the evidence.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
