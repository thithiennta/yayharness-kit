---
name: knowledge-update
description: Bring stale Yay plugin knowledge back in line with the code. Use when the user says "update the docs", "refresh knowledge", "CLAUDE.md is out of date", after merges, before a release, or when yayh knowledge stale or another yay skill reports drift. Re-verifies only the CLAUDE.md project block and docs/knowledge/ parts whose covered files changed, fixes them, and re-stamps.
argument-hint: "[--since=<ref|tag|YYYY-MM-DD>] [--doc=<docs/knowledge/x.md|CLAUDE.md>] [--all] [--check] [--agents=N] [--no-commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:knowledge-update

Arguments: `$ARGUMENTS`

Fix only what drifted. The writing rules are in `${CLAUDE_PLUGIN_ROOT}/reference/knowledge.md`; read its ground rules before editing.

## Options

| Option | Effect |
|---|---|
| `--since=<ref\|tag\|date>` | Diff every doc from this point, instead of from each doc's own `updated_ref`. Useful after merging a long branch, or before a release (`--since=$(yayh git last-tag)`). |
| `--doc=<file>` | Only this doc (`CLAUDE.md` means the project block). |
| `--all` | Full audit: re-verify every claim in every doc, not just those near changed files. Use it occasionally, or when the docs feel wrong. |
| `--check` | Report the drift and stop, changing nothing. Exits non-zero when something is stale. Good for CI and pre-release. |
| `--agents=N` | Parallel scouts when several docs are stale (default 3). |
| `--no-commit` | Leave the changes uncommitted. |

## Steps

### 1. Find the drift
- If there's no project block content or `docs/knowledge/` is empty, suggest `/yay:knowledge-init` and stop.
- Run `yayh knowledge stale [--since=…]` and group the output by doc:
  - `stale  <doc>  <file>`: the files changed since the doc was verified
  - `never` / `bad-ref`: the doc was never stamped, or its ref was rewritten away. Treat the doc as `--all` for that doc.
  - `uncovered  <file>`: changed code that no doc covers. Maybe a new area?
- Run `yayh knowledge check`. Broken paths and links are drift too.
- With `--check`, report the counts per doc plus the check issues, then stop.

### 2. Understand each change
For each stale doc, read what actually changed: `git log --oneline <ref>..HEAD -- <files>` and `git diff <ref>..HEAD -- <files>`. Sort each change into one of three kinds:
- **Irrelevant to the doc** (internal refactor, wording, tests): no edit, just re-stamp.
- **Changes a stated fact** (a renamed class, a moved file, a new option key, a changed command, a removed hook): edit that fact.
- **Adds something the doc should know** (a new subsystem, integration, gotcha or decision): add it, keeping to the doc's budget.

When several docs are stale with large diffs, spawn `yay:knowledge-scout` agents in parallel, one per doc. Brief each with the doc's current text, the commit range, the changed files, and the instruction to report only facts that are now wrong, missing or new. Spot-check what they bring back.

### 3. Edit
- Make the smallest edits that make each doc true. Keep its structure and voice, and don't rewrite sections that are still right.
- The CLAUDE.md project block: edit only between its markers. If a command, layout dir or hard rule changed, it must change here too. Stay within 90 lines.
- `uncovered` files: widen a doc's `covers`, add a section, or (rarely) create an area doc. If a whole new area appeared, ask the user before creating a doc.
- Changes that conflict with what the doc says, where you can't tell which is right: ask with AskUserQuestion. Don't guess.

### 4. Verify and stamp
- `yayh knowledge check` must pass.
- Stamp every doc you verified, including stale-but-unchanged ones: `yayh knowledge stamp <doc>` / `yayh knowledge stamp CLAUDE.md`.
- `yayh knowledge stale` (with the same `--since`, if one was given) should now say `fresh` for the docs you handled.

### 5. Commit
Unless `--no-commit` was passed:
- If you're on the base branch, create `$(yayh git branch-name docs "knowledge update")`.
- `git add -- CLAUDE.md docs/knowledge`
- `git commit -m "docs(knowledge): update project knowledge" -m "<doc>: <what changed>, one line each"`

When this runs inside a feature or fix branch (suggested by `/yay:implement` or `/yay:fix`), commit on that branch, so the docs ship with the change.

### 6. Report
Per doc: one of `updated (<what>)`, `re-verified, no change` or `skipped (<why>)`. Then the open questions, and the uncovered areas you didn't document.
