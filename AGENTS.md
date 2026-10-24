# Agents

Instructions for every agent working in this repo. Claude-specific working rules are in `.claude/CLAUDE.md`.

## Tech debt

**Definition of "tech debt"**

The future cost of rework and maintenance that comes from choosing a quick, easy or
temporary fix in place of a complete, high-quality solution. It accrues interest: the
longer the underlying fix waits, the slower, harder and costlier later changes become.

The cost to build something is not tech debt.

**ALWAYS consider tech debt when designing solutions** - low tech debt is always preferrable.

## Nothing host-specific in the repo

The repo is public and used from many machines, so local paths, account names, hostnames
and credential env vars never get committed; keep them in your own notes or memory.
`tools/leakcheck` enforces this in the commit hooks; enable them once per clone with
`git config core.hooksPath tools/hooks`.
