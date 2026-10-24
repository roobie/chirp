---
created: 2026-10-24
---

# B-RUMTFN4OUESFIEO7 Check whether LGPL parts of mingw-w64 are linked into windows-x64

## Why
The windows binary ships the mingw-w64 notice, which is ZPL 2.1. That COPYING also says some parts are marked LGPL. If any LGPL file is statically linked into windows-x64, the notice alone may not meet its terms, so releases need to know.

## Notes
- The notice comes from zig's `lib/libc/mingw/COPYING`, at the zig pin.
- Trace which mingw sources zig compiles for the windows-x64 link, and grep them for LGPL headers.
