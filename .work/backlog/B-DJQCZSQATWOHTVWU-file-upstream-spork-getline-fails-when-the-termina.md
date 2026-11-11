---
created: 2026-11-02
needs: owner
---

# B-DJQCZSQATWOHTVWU File upstream: spork/getline fails when the terminal has no room for the prompt

## Why
spork/getline fails with "bad slot #1, expected non-negative 32 bit signed integer" from rawterm/slice-monowidth when the terminal is narrower than the prompt or reports no width (a fresh pty, as util-linux script gives a piped session). chirp works around it in src/chirp/repl.janet by reading such lines with plain getline (D-MK7YV2MMJT7324MV).

## Notes
Reproduce: `script -qec chirp /dev/null` with stdin a pipe; refresh in getline.janet computes `available-w` as `w - prpt-width`, negative here. File at janet-lang/spork; the repo token cannot, so BR files it. Once fixed and the spork pin moves, the width check in src/chirp/repl.janet can go.
