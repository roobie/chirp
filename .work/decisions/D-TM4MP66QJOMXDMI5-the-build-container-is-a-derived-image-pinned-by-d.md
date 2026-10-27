---
status: accepted
date: 2026-10-27
read_if:
  - changing packages.txt or the base image pin
  - a linux build differs and the base image did not change
  - the build image is missing from GHCR
refs:
  - tools/build/Dockerfile
  - .github/workflows/build-image.yml
  - pins.jdn
---

# D-TM4MP66QJOMXDMI5 The build container is a derived image pinned by digest

## Context
D-3GLX6D2RADC6IDG7 pinned the Alpine base image by digest, but the packages the build installed into it (perl, make, git and others) were fetched at run time. A repository update could change them under a fixed digest. perl generates parts of OpenSSL, so that could change the output hash with nothing in `pins.jdn` to explain it.

## Decision
The build runs in a derived image: the pinned Alpine base plus `packages.txt`. A manual workflow builds it and pushes it to a public GHCR package, and `pins.jdn` pins it by digest as `:build-image`. The build installs nothing at run time.

## Why
Pinning each package with `apk add pkg=ver` goes stale, because Alpine drops old versions from its repositories. Recording the installed versions only explains a changed hash afterwards and prevents nothing. A dated snapshot of the package repository would need a base other than Alpine, since Alpine has none. A pinned derived image fixes every package, including transitive ones.

The image is not itself reproducible, since it is built by `apk add` on the day. It is fixed by digest, so what has to last is the image, not a recipe. Each build therefore also pushes a dated tag that is never moved or deleted, and `tools/build/apk-versions.txt` records the packages in the pinned image.

## Consequences
- Changing `packages.txt` or the `:image` base needs a manual run of the build-image workflow, then a new `:build-image` digest in `pins.jdn` and a new `apk-versions.txt`. The output hashes may change.
- If the image is deleted from GHCR, builds of past releases break, and rebuilding it gives different package versions. `apk-versions.txt` shows what was in it.
- The package must stay public so CI and other machines can pull it without credentials.
- The container is amd64 only. That was already so, because the pinned zig is x86_64-linux.
