---
date: 2026-11-02
read_if:
  - bumping the zig pin
  - changing what windows-x64 links or its notices
  - checking license compliance of a release
refs:
  - tools/build/config.jdn
  - tools/build/build.janet#first-comment
---

# L-A75ZR5MHIETRGB4I mingw-w64's license file does not cover everything the windows link pulls in

## Observation
A component's license file can understate what a static link pulls in. mingw-w64's COPYING is ZPL 2.1 "with exception of certain parts" under other licenses, and the windows-x64 link includes two such parts: gdtoa (Lucent / David M. Gay, through mingw's printf and strtod) and winpthreads' misc.c (MIT). Nothing it links or includes is LGPL. Zig's mingw sources carry no LGPL file at all. The only LGPL texts are in Wine-derived headers chirp does not include, and a grep for "lgpl" also matches wingdi.h's `LOGPALETTE lgpl` field.

## Why it matters
Each zig bump can change which mingw objects are linked, so the windows notices need the same check again. Relink with the zig from the build tree and `ZIG_VERBOSE_LINK=1` to get the `lld-link` line. Rerun it with `-VERBOSE`, take the `Loaded libmingw32.lib(…)` members and match each to its source under `lib/libc/mingw` to read its license. `crt2.obj` is always linked. compiler_rt is zig's own and is covered by the Zig notice. Headers count only if included, so preprocess the sources' system includes with `-M` for the target. A notice that exists only as a source header goes in config.jdn's :notices as `:comments`.
