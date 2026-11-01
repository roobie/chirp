---
date: 2026-11-01
read_if:
  - a janet core feature works on glibc, macOS or windows but not in chirp's linux build
  - adding a janet compile-time define
refs:
  - tools/build/config.jdn
  - tools/build/build.janet#define-flags
---

# L-2XVJIJPBAN5P3IC6 Janet gates some features on libc macros, which musl does not define

## Observation
Janet's os.c turns on os/spawn's `:cd` by libc macro (glibc, macOS ≥ 10.15, FreeBSD; windows always). musl has had the needed `posix_spawn_file_actions_addchdir_np` since 1.1.24 but deliberately defines no identifying macro, so chirp's static musl builds raised "not supported on this system" (#5) while the other targets worked. On musl a failed `:cd` also reports a stale errno ("Not a tty"), because janet reads errno where posix_spawn returns the error.

## Why it matters
A janet feature can be missing only from chirp's linux builds, and a glibc janet on the dev machine will not show it. Such gates usually have an opt-in define, which chirp can set per target without patching janet (D-ZBIADZDYXYPWLX5L).
