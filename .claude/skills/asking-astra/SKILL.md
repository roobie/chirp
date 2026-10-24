---
name: asking-astra
description: Ask Astra for an independent read-only code review, diagnosis, or strategic direction check. Use when the user requests Astra, a second opinion is useful, or project instructions require independent review; supports background consultation while other work continues.
---

# Asking Astra

Use Astra as an independent reviewer, not an implementer. Main retains responsibility for decisions, verification and commits.

## Prerequisite

The bundled helper is `scripts/astra-review.sh`, relative to this skill's directory. Resolve its absolute path before invoking it. It requires the authenticated `pi` CLI on `PATH`, with access to provider `openai-codex` and model `gpt-6-astra`. It uses read-only file tools, no shell/write tools, no discovered context and no saved session; extensions, MCP and skills are disabled.

If `pi`, authentication or model access is unavailable, report the limitation; do not silently substitute another model or claim review happened. Read the bundled helper if its behavior is uncertain. No dependency on `~/.pi/agent/lib/astra-review` remains.

## Prepare the brief

State:
- The question: direction check, diagnosis, implementation review or final review.
- The user's objective, relevant constraints and what must remain unchanged.
- Exact **absolute paths** to the relevant source, STATE/design documents and evidence logs. Resolve repo paths from the current project root, not from this skill directory. Astra cannot discover filenames by running shell commands.
- What changed, the comparison baseline, known failures/confounds and tests already run. A diff alone is not enough: provide source paths too.
- Requested output: prioritized findings with file/symbol evidence, blockers versus limitations, and the smallest justified next step. For direction checks, ask explicitly whether to continue, stop or change course.
- Explicit boundaries: read only; no edits, commands, commits or acceptance-bound changes. Ask Astra to disclose unread files and incomplete review.

Keep the scope narrow. For large logs, provide a focused excerpt file with clear case/tick labels and the full log's path. Include every exact documentation path in final review; do not assume a previous invocation's context persists.

## Foreground

Run from the project root, with the actual brief in `prompt`:

```bash
helper="$PWD/.claude/skills/asking-astra/scripts/astra-review.sh"
test -x "$helper" || { printf 'Astra helper unavailable\n' >&2; exit 1; }
log=$(mktemp /tmp/astra-review.XXXXXX)
prompt='Read-only review. Question: ... Exact absolute source/document/log paths: ... Constraints: ... Report findings and blockers; disclose incomplete reads. Do not edit or execute commands.'
if "$helper" "$prompt" >"$log" 2>&1; then
  printf 'Astra completed: %s\n' "$log"
else
  rc=$?
  printf 'Astra failed (exit %s): %s\n' "$rc" "$log" >&2
fi
```

Read the log with the file-read tool. A zero exit status is not evidence that every requested file was inspected.

## Background

When the user requests background consultation, or independent work can proceed safely, use the same helper/prompt with a unique log directory and completion marker:

```bash
helper="$PWD/.claude/skills/asking-astra/scripts/astra-review.sh"
test -x "$helper" || { printf 'Astra helper unavailable\n' >&2; exit 1; }
review_dir=$(mktemp -d /tmp/astra-review.XXXXXX)
prompt='Read-only direction check. Objective: ... Exact absolute source/document/log paths: ... Recommend stop/go and the smallest next step. Do not edit or execute commands.'
(
  if "$helper" "$prompt" >"$review_dir/output.log" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  printf '%s\n' "$rc" >"$review_dir/exit-status"
) &
printf 'Astra job=%s directory=%s\n' "$!" "$review_dir"
```

Retain the printed directory and job PID in the session. Continue only work that does not depend on the verdict. Files may change while Astra reads: avoid changing its review scope concurrently, or identify the reviewed snapshot and request a fresh review of subsequent changes.

To check completion, inspect that directory with shell tools and read `exit-status` and `output.log` with the file-read tool. Missing `exit-status` means completion is unconfirmed; an empty or partial output log is not a verdict. Do not use `wait` in a later unrelated shell or infer completion solely from a PID disappearing. If the user asks whether Astra responded, check the saved files rather than relying on memory.

## Follow through

1. Read the full response. Distinguish findings from speculation, scope limitations and claims Astra did not verify.
2. Independently inspect important findings and rerun relevant tests/evidence. Read-only Astra cannot run tests or see screenshots unless supplied as readable files.
3. Address blockers or explain disagreement using evidence. Never weaken bounds, erase failed cases or treat strategic advice as owner acceptance.
4. If review is incomplete, resend exact missing paths. After material fixes, request a focused final review with current paths and verification evidence.
5. Report the verdict concisely to the user. When working under dev-proc, record the log paths, findings, disposition and your own verification in the active unit's STATE. Do not claim approval beyond the reviewed scope.
