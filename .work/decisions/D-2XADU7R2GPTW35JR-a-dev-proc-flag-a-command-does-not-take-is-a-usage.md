---
status: accepted
date: 2026-11-11
read_if:
  - adding or changing a dev-proc flag
  - a dev-proc command rejects a flag
refs:
  - .agents/skills/dev-proc/scripts/dev-proc.janet#FLAGS
  - .agents/skills/dev-proc/scripts/dev-proc.janet#COMMANDS
---

# D-2XADU7R2GPTW35JR A dev-proc flag a command does not take is a usage error naming the ones it does

## Context
dev-proc parsed any `--key value` and no command checked its keys, so a mistyped or invented flag was dropped and the command succeeded. In one drive session `record … --section` created about 20 records holding only placeholders, with no warning.

## Decision
Each command lists the flags it takes, one table gives every flag its kind, and the parser rejects anything else with exit 2, naming the flag and the command's valid ones. A test keeps the two tables in step.

## Why
Agents work from memory and invent plausible flags; silence turns that into lost work. Naming the valid flags lets the caller correct itself in one step. Exit 2 is the usage-error code D-3NN3S4SKFDHQPNZN leaves for this. One table per fact (which command, which kind) means adding a flag cannot leave the parser and the check disagreeing.

## Consequences
`<cmd> --help` is now an error on commands that do not list `help`, where before it was ignored.
