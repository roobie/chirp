---
status: accepted
date: 2026-10-24
read_if:
  - building or upgrading jsec
  - linking OpenSSL
refs:
---

# D-BPDFOMM2OH7HMPZB Build jsec from its sources, not its project.janet

## Context
jsec's `project.janet` expects a system OpenSSL. chirp links its own static OpenSSL (D-GNHGVHYBQ7SLBAIU).

## Decision
Compile jsec's C sources directly in chirp's build, against our OpenSSL.

## Why
Using jsec's build would pull in whatever OpenSSL the build host has installed. The binary would then not be static and not reproducible.

## Consequences
When jsec is upgraded, check whether its source list or compile flags changed, because its `project.janet` is not used.
