---
status: accepted
date: 2026-10-24
read_if:
  - adding or changing a smoke check
  - running checks on a new platform
refs:
  - test/smoke/run.janet
  - .github/workflows/ci.yml
---

# D-DPSCZ2KCZA4UB7YM Smoke checks are a Janet script run by the binary under test, with local controls only

## Context
Each target's binary has to be checked on a native machine of its own platform, and the runners differ: windows has no usable POSIX sh by default. The first negative TLS control used an external host (badssl), which resets connections now and then.

## Decision
The smoke driver is a Janet script that the built chirp runs itself, spawning its own executable for each check. Every check whose failure is the point, such as rejecting an untrusted certificate, uses a server on localhost.

## Why
One script then runs unchanged on every OS. The alternatives were a shell driver plus a PowerShell twin, or a separately installed Janet. Two drivers drift apart, and a separate Janet would test something other than the shipped binary. Running the checks with chirp also checks chirp's own process and event-loop support on each platform. Local controls make a failure mean chirp broke, not the network. The positive https-get still needs the internet, because trusting real roots is what it checks.

## Consequences
A check can't depend on tools outside chirp. A check that hangs is killed by the driver so the job log names it. Platform setup that chirp can't do yet (a CA bundle on windows) stays in the workflow until chirp embeds its roots.
