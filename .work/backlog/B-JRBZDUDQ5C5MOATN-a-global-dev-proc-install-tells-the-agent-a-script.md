---
created: 2026-11-08
---

# B-JRBZDUDQ5C5MOATN A global dev-proc install tells the agent a script path that only exists in a project install

## Why
After `chirp --dev-proc --install --global`, the installed SKILL.md (line 11) still says `DP="chirp .claude/skills/dev-proc/scripts/dev-proc.janet"` and tells the agent to run it from the repo root. In a repo with no project install that fails with `could not find file .claude/skills/dev-proc/scripts/dev-proc.janet`, and the agent has to guess `$HOME/.claude/skills/dev-proc/...`. Every agent using a global install hits this.

Repro:
1. `chirp --dev-proc --install --force --global`
2. cd into a repo with `.work/` but no `.claude/skills/dev-proc`
3. Follow SKILL.md: `chirp .claude/skills/dev-proc/scripts/dev-proc.janet status` fails because the file is not there

Expected: the path in a global install works from any directory, e.g. `DP="chirp $HOME/.claude/skills/dev-proc/scripts/dev-proc.janet"`. Alternatively, SKILL.md says to resolve the path against the skill's own directory instead of the CWD.

## Notes
- The installer copies SKILL.md verbatim (`src/chirp/skills.janet#run` only picks the base dir: HOME or cwd), so the fix belongs in the installer (rewrite the path for `--global`) or in the template wording, not in a hand edit. A `--force` install overwrites hand edits.
- `$HOME/.claude/skills/dev-proc` links to `$HOME/.agents/skills/dev-proc`; both show the same line.
- Re-running the installer reports "up to date .claude/skills/dev-proc", so the path never changes.
- Wording that works for both installs (path relative to the skill dir) avoids rewriting at install time; check it against D-WDOKPQ422TKMQ3RO (install never clobbers edits), since a rewritten file must still count as unedited.
- Reported by BR, 2026-11-08.
