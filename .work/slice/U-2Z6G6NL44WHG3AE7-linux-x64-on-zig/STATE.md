---
phase: execute
parent: U-EP6NS3X66GBL2AQL
owner:
  - BR
  - claude
created: 2026-10-24
success_criteria:
  - Every shipped target, linux-x64 included, is compiled and linked by the pinned zig; the container's own compiler builds only the tooling that writes the image
  - test/spike/run.sh passes, with two linux-x64 builds in different directories giving identical sha256, and the binary is a static, stripped x86-64 ELF
  - test/spike/run-windows.sh still passes and reproduces
---

# slice/linux-x64-on-zig

## Purpose
Under D-I6U4X6Q5KJD2Y4SM every shipped binary comes from one toolchain. linux x64 still comes from the container's gcc, so it takes a separate code path from windows and a different source of drift. Moving it onto zig leaves one path for the matrix to grow on.

## Scope
In: splitting the build machine from the shipped targets in `config.jdn` and `build.janet`; linux-x64 cross-built with `x86_64-linux-musl`; both spike scripts.
Out: other targets; CI; building the tooling itself with zig.

## Context & constraints
- The build machine builds janet, OpenSSL and the natives that the image-building janet loads. That tooling never ships.
- The windows hash may change only if the restructure changes its inputs, and any change has to be explained.

## Now
All criteria pass.

## Next
- Finalize.

## Evidence
- (1) `config.jdn` has only zig targets (`x86_64-linux-musl`, `x86_64-windows-gnu`), plus a `:build-machine` entry for the tooling. `build.janet` has one path: natives for the build machine, the image by `image.janet`, then zig compiles and links for the target.
- (2) `test/spike/run.sh`: both builds `484a2667803e615ae04e767415c4aee82f77493252fe8868680d8362b04a2a15`; zip, https-get and https-server pass; `file`: ELF 64-bit x86-64, statically linked, stripped.
- (3) `test/spike/run-windows.sh`: both builds `78c330ff3422afdd35c28a6c4e5d915ee09bd6a890fced2e5a621e014bdacddf`, and the Wine checks and self-signed control pass. The hash changed from `f4470530…` because the image is now written by a different process, not because of the restructure itself. That restructure alone kept `f4470530…`.
- Decoupling: an extra `or`/`assert` added to `build.janet` left the linux hash at `484a2667…`. Before the split, a single extra `or` changed the windows hash.

## Harvest
- [ ] learning: the image's gensym names depend on everything the image-writing process compiled before the entry, its own script included, so that process must be a small dedicated script.
- [ ] process: two parallel spike builds fill the disk under `build/`; run.sh's workdir argument works around it. Fine for now, since CI runs one build per job.

## Log
- 2026-10-24 initialized
- 2026-10-24 phase initialize → execute
