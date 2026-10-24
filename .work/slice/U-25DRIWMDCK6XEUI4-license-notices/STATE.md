---
phase: execute
parent: U-ROTWPYUJJW5Q45E2
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - The repo root has an MIT LICENSE (D-UQZLUV7LGGRXHXPJ)
  - Each target's build writes a NOTICES.txt next to the binary holding chirp's license and the license text of every component linked into that target, taken from the pinned sources where they ship one
  - NOTICES.txt is byte-identical across the two CI copies, and the compare job checks it like the binary
---

# slice/license-notices

## Purpose
A binary release has to carry the license texts of what it contains. Generating them from the pinned sources keeps the notices in step with the pins, instead of a hand-kept file that drifts on every bump.

## Scope
In: LICENSE; the list of notice sources as data in `tools/build/config.jdn`; the build step that writes NOTICES.txt; texts that no pinned source ships (jsec's ISC); the compare job.
Out: embedding the notices in the binary (`chirp --licenses`), which can come later.

## Context & constraints
- Components: Janet and spork (MIT), the miniz copy inside spork (MIT), jsec (ISC, declared but no LICENSE file at the pin), spork-https (ISC), OpenSSL 3 (Apache-2.0), plus zig's runtime pieces: musl on linux, mingw-w64 on windows, and zig's compiler_rt on every target. macOS links libSystem dynamically, so it needs no libc notice.
- Notices are per target, because the runtime pieces differ.

## Now
The notices step is in: `tools/build/notices.jdn` holds the data, and build.janet writes bin/NOTICES.txt. Pushing for CI.

## Next
- Check in CI that compare lists NOTICES.txt as identical for all four targets, then finalize.

## Evidence
- LICENSE at the repo root (MIT).
- Local builds: linux-x64 twice in different directories, with `chirp` unchanged at 484a2667…4a2a15 and NOTICES.txt identical (7a2ad7b1…c3529f). windows-x64 has `chirp.exe` unchanged at e92c21ff…b3d39 and NOTICES.txt at ac039372…e45e6d54. Both NOTICES files have LF line endings only.
- The sections are chirp, Janet, spork, miniz, jsec, spork-https, OpenSSL and Zig (compiler_rt), plus musl on linux and mingw-w64 on windows. Every text except jsec's is read from the pinned checkout or the pinned zig tarball.

## Harvest
- [ ] backlog: ask jsec upstream to add the LICENSE file its README points to
- [ ] backlog: editing config.jdn moves the binary hash even when no key the image uses changes; find out how its content reaches the image (a reproducibility hazard close to the pointer-hash risk)
- [ ] decision: notices data lives in its own notices.jdn rather than config.jdn, so editing it never moves the binary

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
