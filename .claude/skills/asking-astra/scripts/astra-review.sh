#!/usr/bin/env bash
# One-shot, read-only Astra review. Pass the review prompt as argument(s).
# No shell/write tools, extensions, MCP, discovered context, or saved session.
set -euo pipefail

if (( $# == 0 )); then
  printf 'Usage: %s "review prompt"\n' "${0##*/}" >&2
  exit 2
fi

exec pi \
  --print \
  --provider openai-codex \
  --model gpt-6-astra \
  --thinking low \
  --no-session \
  --no-extensions \
  --no-mcp \
  --no-skills \
  --no-prompt-templates \
  --no-themes \
  --no-context-files \
  --tools read \
  --append-system-prompt 'You are Astra acting as a read-only reviewer, not an implementer. Read files as needed. Do not modify files or execute commands. Report findings and evidence; do not implement fixes.' \
  -- "$@"
