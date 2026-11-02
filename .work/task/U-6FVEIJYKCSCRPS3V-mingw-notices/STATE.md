---
phase: execute
parent: U-72DAK2PC7YHCMNVN
owner:
  - BR
  - claude
created: 2026-11-02
success_criteria:
  - The mingw-w64 objects linked into windows-x64 are listed and each one's license is known; none is LGPL
  - NOTICES-windows-x64.txt carries the gdtoa and winpthreads notices, read from the zig pin, not copied into the repo
  - CI builds all four targets twice with matching sha256
---

# task/mingw-notices

## Purpose
The windows binary's notices cover every license that applies to the mingw-w64 code statically linked into it, and nothing LGPL is linked.

## Scope
In: the windows-x64 link's mingw-w64 objects and the headers its sources include; notices for what they need.
Out: linux (musl's COPYRIGHT already carries its third-party texts) and macOS (libSystem is dynamic; compiler_rt is under the Zig notice); the jsec LICENSE file (B-5AUA2Q7IH5DP2ZME, needs upstream).

## Context & constraints
Notices are read from pins, never copied into the repo where an upstream file exists (D-KPP2PSBZKFSROC44). notices.jdn is not read by the image build, so the binaries do not move.

### Origin
Promoted from backlog: B-RUMTFN4OUESFIEO7 Check whether LGPL parts of mingw-w64 are linked into windows-x64

### Why
The windows binary ships the mingw-w64 notice, which is ZPL 2.1. That COPYING also says some parts are marked LGPL. If any LGPL file is statically linked into windows-x64, the notice alone may not meet its terms, so releases need to know.

### Notes
- The notice comes from zig's `lib/libc/mingw/COPYING`, at the zig pin.
- Trace which mingw sources zig compiles for the windows-x64 link, and grep them for LGPL headers.


## Now
Done; waiting for CI.

## Next
- CI green, then finalize.

## Evidence
- Relink of windows-x64 with `lld-link -VERBOSE`: 73 libmingw32 members plus crt2.obj. Their sources are public domain, ZPL (no header, or ZPL header), gdtoa (Lucent / Gay, 10 files plus mingw_pformat.c) and winpthreads/misc.c (MIT). No zigc members; one compiler_rt member.
- No file under zig's lib/libc/mingw carries LGPL. The 92 LGPL headers in any-windows-any are none of the 224 that the sources' system includes reach. The one grep hit, wingdi.h, is the `lgpl` field name, and the file is public domain.
- Container builds: windows-x64 NOTICES gains the gdtoa (strtodg.c, strtodnrp.c, mingw_pformat.c) and winpthreads sections; linux-x64 NOTICES byte-identical.

## Harvest
<!-- Candidates found along the way. Finalize promotes or drops every unchecked item:
     - [ ] decision: …   → record decision
     - [ ] learning: …   → record learning
     - [ ] backlog: …    → record backlog
     - [ ] process: …    → retrospective (change the process, or drop it)
-->

- [x] learning: L-A75ZR5MHIETRGB4I how to redo the audit at a zig bump

## Log
- 2026-11-02 initialized
- 2026-11-02 phase initialize → execute
- 2026-11-02 audit done: no LGPL; gdtoa and winpthreads notices added via :comments
