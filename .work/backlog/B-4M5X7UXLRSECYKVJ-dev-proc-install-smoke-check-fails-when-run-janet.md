---
created: 2026-11-20
---

# B-4M5X7UXLRSECYKVJ dev-proc-install smoke check fails when run.janet is called with backslashes

## Why
On windows, `chirp .\test\smoke\run.janet` fails the dev-proc-install check before it tests anything: the check finds its own directory by the last `/` in its path, and a path typed with backslashes has none. CI calls the script with forward slashes, so only a local windows run shows it, and it hides a real failure of that check.

## Notes
`test/smoke/dev-proc-install.janet` `main`, the `here` binding: `(last (string/find-all "/" f))` is nil for `test\smoke\…`. `run.janet` already has a `dir-of` that takes either separator.
