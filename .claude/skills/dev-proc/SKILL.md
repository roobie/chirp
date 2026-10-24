---
name: dev-proc
description: How work is run in this repo. Work is organised into units (task, slice, wave, milestone, project), each moving through initialize, execute and finalize. Units are tracked in `.work/` documents that are updated in every commit and deleted at finalize, while decision records and learnings are kept. Use when starting, resuming, planning, re-scoping, committing, finishing or scrapping any piece of work; when the user mentions a task, slice, wave, milestone, project, the backlog, a decision or a learning; or before changing code in a repo that has a `.work/` directory.
---

# dev-proc

This skill is the process for working in this repo. It is **modal**: the current mode comes from the `.work/` files on disk, never from memory or chat. Always start by asking the CLI:

```sh
DP="node .claude/skills/dev-proc/scripts/dev-proc.mjs"   # path from the repo root
$DP status                 # tree of active units with their phases
$DP status slice/foo       # one unit (by id U-… or type/name): its mode, success criteria, and the gate to the next phase
```

Then follow the section for that unit's mode below. `$DP help` lists every command.

## Model

| Unit | Done when… |
|---|---|
| project | its purpose is achieved, or it is abandoned |
| milestone | an externally meaningful capability exists |
| wave | a set of slices that don't depend on each other (so they can run in parallel) are all integrated |
| slice | a thin vertical change is shippable on its own |
| task | one coherent change is made, with evidence |

- **Identity:** each unit has an id `U-<ident>` and a kebab-case name; `<type>/<name>` is its label. The id never changes, even when the unit is rescoped or renamed, and names may be reused after a unit is deleted, so history (trailers, `parent`, `dig`) always uses the id. Commands accept the label as a shorthand for active units.
- **Tree:** a unit's `parent` must be a *higher* level, but levels can be skipped (sparse hierarchy). A lone task is fine.
- **Recursion:** every unit runs initialize → execute → finalize. A parent's execute loop mostly spawns, steers and closes its children.
- **Owner:** a person and/or an agent, listed in `owner`.
- **Several roots:** a repo may have several `.work/` directories (e.g. one per project in a monorepo). The CLI uses the nearest one above the current directory (`--root` overrides). `check` covers all of them.

## Files

```
.work/
  <type>/U-<ident>-<name>/STATE.md   required: the unit's front matter and cursor
  <type>/U-<ident>-<name>/DESIGN.md  optional
  <type>/U-<ident>-<name>/PLAN.md    optional
  backlog/B-<ident>-<slug>.md    curated candidate work
  decisions/D-<ident>-<slug>.md  durable
  learnings/L-<ident>-<slug>.md  durable
```

**Ephemeral** (units and backlog) may hold *what*, *how* and *why*. **Durable** (decisions and learnings) may hold **only why plus cues** (`refs: path#symbol`). Code rarely lies about what it does and how; prose copied from code drifts. `check` verifies every ref still resolves and flags code blocks and step-by-step lists in durable docs.

Front matter (restricted YAML: scalars, `[a, b]`, and `- item` lists):
- **Unit `STATE.md`:** `phase`, `parent?` (a unit id), `owner`, `created`, `success_criteria`. The id, type and name come from the path, so they are never repeated.
- **Decision:** `status` (`accepted`/`proposed`), `date`, `read_if`, `refs`, `supersedes?`.
- **Learning:** `date`, `read_if`, `refs`.
- **Backlog item:** `created`.

`read_if` lists the common reasons a future reader would need the document. Before loading durable docs, run `$DP find "<what you're about to do>"` to list the records whose `read_if` matches, and read only those. `$DP status --json` still lists every record's title and `read_if`.

Every id is a kind prefix (`U` unit, `D` decision, `L` learning, `B` backlog) plus 80 crypto-random bits in base32 (RFC 4648, 16 chars), e.g. `D-K7Q2M4XWZ3PB5N6R`. Ids are unique without coordination, so parallel branches never collide and an id is never reused. Refer to things by id; names and slugs are only for humans.

## Modes

### idle (no unit covers the work)
Curate the backlog: merge duplicates, drop stale items, and keep it short. A backlog file is a candidate, not a commitment. To start work: `$DP new <type> <name> [--parent <unit>] [--from B-…] [--with design,plan]`. `--from` consumes the backlog item into `STATE.md`.

### initialize
Establish **purpose, scope, context, constraints, resources, ownership and success criteria** in `STATE.md` (plus `DESIGN.md`/`PLAN.md` when the unit is big enough to need them). Run `$DP find "<the unit's purpose>"` and read what it lists. The gate to execute requires a non-empty `owner` and observable `success_criteria`: `$DP phase <id> execute`.

### execute (loop)
Repeat: **plan → act → inspect evidence → adapt → persist.**
- Keep `## Now` and `## Next` current; it is a cursor, so rewrite freely.
- Put proof against the criteria in `## Evidence`.
- The moment you notice a decision, a learning or deferred work, add a `- [ ] decision|learning|backlog: …` line to `## Harvest`. Finalize depends on this list. Friction with the way of working itself goes in as `- [ ] process: …` and feeds the retrospective.
- Append notable events to `## Log`, which is always the last section.
- If the unit turns out to be the wrong size or in the wrong place, re-scope (see below) rather than letting it sprawl.

When the criteria hold (or the unit should stop), `$DP phase <id> finalize`.

### finalize
Choose a branch: **deliver** or **scrap**.
1. **Verify:** check each success criterion against the Evidence. For a scrap, verify that nothing half-done is left in a misleading state.
2. **Harvest** every unchecked item in `## Harvest`, ticking each one off:
   - reasoning → `$DP record decision "<title>" --read-if "…" --ref path#symbol`
   - discoveries → `$DP record learning "<title>" …`
   - unfinished or deferred work → `$DP record backlog "<title>"`
   - anything else → the closing commit message
3. **Scrap** always gets a decision record saying why the work was abandoned; that is the most valuable "why" there is. What happens to the code (revert, delete the branch, keep it) is decided case by case with the owner, never automatically.
4. **Package and hand off:** make sure the artefacts are usable and the parent's `STATE.md` reflects the outcome.
5. **Retrospective (optional, never forced):** briefly ask whether anything about *how* we worked should change: the process, this skill, `CLAUDE.md`, tooling, agent roles. Start from any `process:` items in Harvest. Act only on what is genuinely worth changing: make a small change now in its own commit, or record a backlog item for a bigger one. If nothing comes to mind, skip this step and write nothing; ritual reflections are noise.
6. **Remove:** `$DP close <id>` (or `close <id> --scrap --decision D-…`). It refuses while children are open, the phase isn't finalize, or Harvest has unchecked items. Commit the deletion together with the harvested records.

## Every commit

- **Docs are current in the same commit as the code.** If code under an executing unit changes, that unit's `STATE.md` changes too.
- **Trailers** make history searchable. `Work:` takes the unit id, never the label. Use one per unit the commit advances, most specific first:
  ```
  Work: U-Q4M7ZK2XPA3LBN5C
  Supersedes: D-K7Q2M4XWZ3PB5N6R      # when a decision replaces another (record --supersedes deletes the old file)
  Decision: D-3HVN7TQ2ALW5EXKC        # on a scrap commit
  ```
- `$DP hooks install` adds pre-commit and commit-msg checks. They warn by default; `DEV_PROC_STRICT=1` makes them block.
- `$DP check` before you hand off.

## Re-scoping

`$DP rescope <unit> [--type t] [--name n] [--parent <unit>|none]` handles split-outs, promotions, demotions and re-parenting. It moves the directory and logs the change; the id stays, so children and past trailers stay valid. To split a unit: create the new sibling or child units with `new`, move the relevant scope across, then rescope or narrow the original.

## Archaeology

Deleted documents stay in git history. `$DP dig <U-… | D-… | L-… | B-…>` lists commits carrying that id's trailer and prints the last version of the deleted files. A superseded decision is found the same way, through the `supersedes:` field and the `Supersedes:` trailer.

## Skillset contract

dev-proc is the router of a skillset. Sibling skills (e.g. design, decide, review, finalize helpers) must:
- read and change state **through this CLI** (or by editing the documents in the formats above), never through a private format;
- respect the ephemeral/durable split and the trailer convention;
- start from `$DP status` like this skill does.
