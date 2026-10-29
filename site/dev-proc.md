# dev-proc

dev-proc is how work on chirp is run. People and coding agents work on this repo across many sessions, and neither can rely on remembering the last one. So the state of every piece of work lives in files in the repo, a small CLI reads and checks those files, and every commit says which piece of work it advances.

It is a convention plus a script, not a service. The script is [`dev-proc.janet`](../.agents/skills/dev-proc/scripts/dev-proc.janet), and it runs on chirp. The rules an agent follows are in [`SKILL.md`](../.agents/skills/dev-proc/SKILL.md), reproduced below the line on this page. chirp carries the skill, so `chirp --dev-proc --install` puts it in another project. [Examples](dev-proc-examples.md) shows units from chirp's own history, with links to their commits.

## The ideas

**Units of work, sized by what "done" means.** A *task* is one coherent change. A *slice* is a thin change that can ship on its own. A *wave* groups slices that can run in parallel, a *milestone* is a capability someone outside would notice, and a *project* is the whole purpose. Levels can be skipped, and a lone task is fine.

**Every unit has the same life: initialize, execute, finalize.** Initialize writes down the purpose, scope and success criteria. The CLI will not move a unit to execute without an owner and criteria someone can check. Execute is a loop of plan, act, look at the evidence, adapt and save. Finalize checks the criteria, keeps what is worth keeping and deletes the unit's files.

**State is on disk, not in a chat.** A unit's `STATE.md` holds a cursor (`Now`, `Next`), the evidence against its criteria, and a `Harvest` list. Anyone who picks the work up, human or agent, starts by reading it, not by asking what happened.

**Ephemeral and durable records are kept apart.** Unit files and backlog items say *what* and *how*, and they are deleted when the work ends. Decisions and learnings outlive the work, and they may only say *why*, with pointers into the code (`refs: path#symbol`). Code rarely lies about what it does, but prose copied from it drifts. `dev-proc check` fails a reference that no longer resolves and flags step lists in durable records.

**Harvest is how knowledge survives the deletion.** While working, anything that looks like a decision, a learning or deferred work goes onto the unit's Harvest list the moment it is noticed. Finalize refuses to close a unit until every item is recorded or dropped. Abandoned work is closed too, but always with a decision record that says why. That "why" is the most useful thing it leaves behind.

**Ids, not names, and trailers, not memory.** Every record has an id such as `U-F35YV2DPMJION4EG`, 80 random bits, so parallel branches never collide. Every commit carries a `Work: U-…` trailer. Deleted unit files stay in git history, and `dev-proc dig <id>` finds the commits and prints the last version of the files.

## Why it is shaped this way

The process grew out of handing work between sessions that start from nothing. A plan kept only in the conversation is lost when the conversation ends, and documentation that no command checks goes stale. dev-proc keeps both on disk, small, checked by `dev-proc check` in a commit hook, and tied to commits by the trailer. It costs a few lines per commit. In return, any session can start from `dev-proc status` and know where things stand.
