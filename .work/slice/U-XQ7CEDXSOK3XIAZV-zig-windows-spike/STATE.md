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
All criteria pass and D-I6U4X6Q5KJD2Y4SM is accepted.

## Next
- Finalize: harvest, then close.

## Evidence
- (1) `chirp.exe` is PE32+ x86-64 console, about 7.2 MB, built by zig 0.15.2 whose tarball sha256 is checked against `pins.jdn`; OpenSSL 3 static via `Configure mingw64` with asm; every native in `natives.jdn` linked.
- (2) Under Wine 10.7: `chirp 0.0.1-spike (unofficial build, not a Janet release) on Janet 1.43.0-dev-chirp-dc0f243b`; `ok zip 100000 -> 288 -> 100000`; `ok https-get https://example.com/ status 200`. Control: `https://self-signed.badssl.com/` fails with `certificate verify failed`. An empty `SSL_CERT_FILE` is no control (B-IOPVTTA3XW3OKYXQ).
- (3) Four cold builds in `c1`, `c2/nested/deep`, `c3`, `c4/x/y/z` all `f447053019d673a0db11f8c654782c42dccc4b443598658ee2d77ce68b7835b9`. Needed the PE timestamp zeroed, the spork prefix patch (L-NIHSWVXW4SAVWOB4) and the image built in a fresh janet process.
- Linux `test/spike/run.sh` still passes and reproduces: `7e26d244a6c7207599006810b77db6d402ef063a7322bf0391a789b6066f3b42` (changed from `c6ac5b47…` by the patch and the two-stage build).
- Final from-scratch `test/spike/run-windows.sh`: both builds `f4470530…35b9`, all Wine checks and the verify-failure control pass.

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
