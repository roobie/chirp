---
phase: execute
parent: U-EP6NS3X66GBL2AQL
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - A push to main runs a GitHub Actions workflow that builds linux-x64 and windows-x64 twice each, in separate jobs and different directories, and fails when a target's two sha256 differ
  - The same run passes the smoke checks on native ubuntu x64 and windows x64 runners using the built binary, and the leakcheck job passes
  - The run is green, and the workflow is written so adding a target is a matrix entry, not new jobs
---

# slice/ci-workflow

## Purpose
Reproducibility and "it runs" have only been checked by hand on one machine. A workflow makes GitHub check both on every push, on the platforms chirp ships for, and adding the remaining targets becomes a data change.

## Scope
In: `.github/workflows/`; a portable smoke driver that chirp itself runs, so windows needs no sh; leakcheck in CI (B-JSN4UWUJCBBNOWEX below).
Out: linux-arm64 and macos-arm64 (the next slices); releases; caching. Every build is cold so the double build stays honest, and caching can come later if build time hurts.

## Context & constraints
- Builds run `tools/build/container.sh <target> <dir>` on ubuntu x64 runners (docker is preinstalled). Native runners only run the binary.
- No embedded CA bundle yet: where a runner's OS store isn't visible to OpenSSL (windows), the smoke job points `SSL_CERT_FILE` at a bundle the runner provides.
- The negative TLS control has to be local, because external hosts like badssl reset connections now and then. The https-server check already rejects an untrusted self-signed certificate on localhost.
- Third-party actions are pinned by commit sha, and the workflow gets read-only `contents` permission.
- GitHub access uses the repo-scoped token, per command.

### Origin
Promoted from backlog: B-JSN4UWUJCBBNOWEX Run leakcheck all and its tests in CI

### Why
Hooks can be skipped (`--no-verify`, or a clone without `core.hooksPath`). A CI run of `leakcheck all` plus `tools/leakcheck/test.janet` catches what gets past them, using the generic rules.

## Now
The first run (40091651644) passed builds, compare, leakcheck and linux smoke. Windows smoke stopped before running chirp because the Git CA bundle was not at the assumed path, so the step now searches the Git install for it. Run 40092342785 checks the fix. The Wine `https-server` failure ("failed to listen for events: Invalid handle") is a jsec bug that also affects real Windows: Janet's completion loop overwrites the accepted socket with a byte count of 0. `tools/build/patches/jsec-iocp-accept-state-padding.patch` reserves that slot. It changes the windows hash only.

## Next
- Push the patch and confirm a fully green run. If unpatched windows smoke hangs instead of failing, give the driver a timeout per check.

## Evidence
- Run 40091651644: both copies of linux-x64 hash 484a2667…2a15 and both copies of windows-x64 hash 78c330ff…cddf, the same hashes as the local builds. leakcheck and linux smoke passed.
- With the jsec patch, local builds give linux-x64 484a2667…2a15 (unchanged) and windows-x64 e92c21ff…3d39. Under Wine that windows build passes all four smoke checks, https-server included.

## Harvest
- [ ] learning: Janet's IOCP loop treats a fiber's ev_state as JanetOverlapped and writes a uint32 byte count right after the OVERLAPPED, so a native's state struct must reserve that slot (cause of the windows TLS server failure)
- [ ] backlog: send the jsec accept-state patch upstream, and check jsec's TLSState and DTLS structs, which put wsa_buf in the slot Janet writes
- [ ] backlog: jsec's `__declspec(thread)` error buffer is ignored by zig, so it is a plain static (harmless while Janet is single-threaded)
- [ ] process: the dev-proc hooks only warn, so a commit with refs broken by a file move went through. Consider making `tools/hooks` run them strict.

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
- 2026-10-24 first CI run: all green except the windows CA bundle lookup
