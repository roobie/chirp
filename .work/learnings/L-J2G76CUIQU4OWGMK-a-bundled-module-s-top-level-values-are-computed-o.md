---
date: 2026-11-02
read_if:
  - writing a bundled Janet module that checks the OS or environment
  - a bundled module behaves as if on linux on windows or macOS
refs:
  - src/tar/tar.janet#windows?
  - src/chirp/update.janet#windows?
---

# L-J2G76CUIQU4OWGMK A bundled module's top-level values are computed on the linux build host

## Observation
A bundled module's top-level forms run once, when the image is built, and their values are baked in. Every target's image is built on linux, so `(def- windows? (= :windows (os/which)))` in tar was false in chirp.exe, and extraction took the posix paths: `os/symlink`, `os/chmod` and directory mtimes. Janet built with mingw also reports `:mingw`, not `:windows`.

## Why it matters
Any top-level value that depends on the host (OS, environment, cwd, time) is wrong on some target and passes every linux check. Compute such values in a function called at run time, and test for both `:windows` and `:mingw`, as `src/chirp/update.janet` and `src/tar/tar.janet` do. Only the windows smoke run (CI's native runner, or wine locally) catches a miss.
