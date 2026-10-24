---
status: accepted
date: 2026-10-24
read_if:
  - changing how chirp is built
  - porting the build to macOS or Windows
refs:
---

# D-ANH2OMRLGDIIVVZY Build logic is a Janet script

## Context
The build fetches pins, builds OpenSSL, janet and jsec, and links the chirp executable. Later it has to do the same on macOS and Windows.

## Decision
A Janet script holds the build logic. It runs on a janet that is first built from the pinned source with janet's own build. Host-side wrappers only launch it.

## Why
Janet is the project's language and runs on every target, including Windows, where make and sh are not native. Building janet itself is the one step that needs something else, and janet's own build already covers that on every platform. jpm/janet-pm project files were rejected because they assume system libraries (D-BPDFOMM2OH7HMPZB). A Makefile was rejected because it doesn't port to Windows.

## Consequences
Every build starts by building janet. Wrappers stay thin: the docker invocation on linux, and native equivalents elsewhere.
