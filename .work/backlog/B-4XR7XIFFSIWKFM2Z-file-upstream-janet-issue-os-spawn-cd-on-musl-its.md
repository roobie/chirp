---
created: 2026-11-01
needs: owner
---

# B-4XR7XIFFSIWKFM2Z File upstream janet issue: os/spawn :cd on musl, its docstring, and the stale errno

## Why
Janet should enable os/spawn's `:cd` on musl, document `:cd` in the os/execute and os/spawn docstrings, and report posix_spawn's returned status instead of errno (a failed `:cd` on musl says "Not a tty"). Upstream, chirp could drop the linux `:janet-defines` and the stale-errno sentence in src/chirp/help/subprocess.md. Found in slice spawn-cd (#5). The repo's token cannot open issues on janet-lang/janet, so BR files it.

## Notes
- Still present at janet master a2c0d0c8; no existing upstream issue found (searched addchdir, chdir, "Not a tty").
- Repro for the errno part needs musl plus `-DJANET_SPAWN_CHDIR`: `(os/execute ["pwd"] :p {:cd "/etc/passwd"})` gives "Not a tty"; glibc gives "Not a directory" because glibc also sets errno.
- Draft title: "os/spawn :cd: unavailable on musl, undocumented, and a failed :cd reports a stale errno". Suggested fixes: enable for all `__linux__` with `JANET_SPAWN_NO_CHDIR` as the opt-out, or a meson `has_function` check; use the posix_spawn return value in the error.
