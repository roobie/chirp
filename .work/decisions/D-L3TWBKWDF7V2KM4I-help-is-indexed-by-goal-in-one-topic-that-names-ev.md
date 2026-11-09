---
status: accepted
date: 2026-11-08
read_if:
  - adding a bundled module
  - changing how --help query ranks results
  - a goal query does not find its module
refs:
  - src/chirp/main.janet#goal-entry?
  - src/chirp/help.janet#index
  - src/chirp/help/tasks.md
  - test/smoke/help-examples.janet
---

# D-L3TWBKWDF7V2KM4I Help is indexed by goal in one topic that names every bundled module and ranks with a boost

## Context
Issues #4, #6 and #8 asked for things chirp already bundled (a table printer, schema validation, JSON). The help was organised by module, and users arrive with a goal in their own words, which often missed or ranked a changelog entry first.

## Decision
One help topic, `tasks` (`:help-goals` in chirp.jdn), has a section per goal with the module, its import line and an example that runs. The build fails when a module in `:modules` is not named there, a smoke check runs every example on each target, and the topic's entries carry a 1.5 boost on their FTS5 relevance.

## Why
A goal index only helps while it is complete and its examples work, so both are enforced rather than left to review. A boost keeps the ranking one rule over one index: synonym lists would need upkeep per word, and a separate goal search would be a second interface to learn. At 2 the goals outranked topics that match much better (`sqlite`, `tar`); 1.5 puts goal words first and leaves those alone.

## Consequences
A new bundled module needs a goal sentence before it builds. The boost is a tuning constant: a query whose best answer is a reference topic can still lose to a goal section that mentions the same words, and the help smoke check pins the cases that matter.
