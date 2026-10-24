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
Initialized.

## Next
- Delegate the workflow and smoke driver, push, then iterate on the run until it's green.

## Evidence

## Harvest

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
