---
name: harness-update
description: Re-sync a repo's kit-owned yay files to the installed plugin version. Use when the session notice says the harness is outdated, after updating the plugin or editing .yay/config.json or .yay/settings.extra.json, or when the user says "update the harness", "resync", "harness drift". Touches only the managed CLAUDE.md block, yay rules, settings, PR template and docs skeleton.
argument-hint: "[--check] [--diff] [--force] [--only=claude-md|rules|settings|github|docs[,…]] [--no-commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, AskUserQuestion
---

# /yay:harness-update

Arguments: `$ARGUMENTS`

Bring this repo's **kit-owned** files in line with the installed yay plugin and the repo's `.yay/config.json`. This skill never writes project knowledge (`/yay:knowledge-update` does that) or workflow docs. Ownership rules: `${CLAUDE_PLUGIN_ROOT}/reference/ownership.md`.

## Options

| Option | Effect |
|---|---|
| `--check` | Report only. Exits non-zero when something would change. Good for CI. |
| `--diff` | Show a unified diff of every pending change. |
| `--force` | Overwrite hand-edited kit files (`skipped-modified`, `conflict`). Ask first, unless the user passed it. |
| `--only=<groups>` | Limit to `claude-md`, `rules`, `settings`, `github` or `docs` (comma-separated). |
| `--no-commit` | Leave the changes uncommitted. |

## Steps

1. **Preflight.**
   - `yayh harness status`. If it says `not-initialized`, stop and suggest `/yay:harness-init`.
   - `yayh config validate`. Fix config errors first, and ask the user when a fix isn't obvious.
   - `git status --porcelain` must show no changes to kit-owned files. Other changes are fine.
2. **Config migration.** Compare `.yay/config.json` with `${CLAUDE_PLUGIN_ROOT}/reference/config.schema.json`. If the kit added keys this repo lacks, list them with their defaults and add them only after the user agrees. Never change an existing value.
3. **Preview.** Run `yayh harness sync --check --diff <--only>` and summarize the actions:
   - `created` / `updated`: will be written
   - `seeded`: a missing skeleton file will be created
   - `up-to-date`: nothing to do
   - `skipped-modified`: someone hand-edited a kit file. Show the diff and explain that the change belongs in a repo rule (a `.claude/rules/` file without the `yay-` prefix), in `.yay/settings.extra.json`, or upstream in the kit. Ask whether to overwrite it.
   - `conflict`: a file exists where a kit file goes, and the kit never wrote it. Same question.
   - `orphaned` / `removed`: the kit no longer ships this file.

   With `--check`, stop here and report.
4. **Apply.** Run `yayh harness sync <--only>`, adding `--force` only if the user approved overwriting. Run `yayh harness sync --check` again to confirm it's clean.
5. **Commit.** Unless `--no-commit` was passed, and only if kit files changed:
   - Branch: if you're on the base branch, `git switch -c "$(yayh git branch-name chore "yay harness $(yayh version)")"`. Otherwise stay where you are.
   - Stage precisely: `git add -- $(yayh harness files)`, never `git add -A`.
   - Commit: `chore(harness): update yay harness to v<version>`. The `harness` scope is always allowed.
   - Mention the PR it needs.
6. **Report.** Give the version change (`<old> -> <new>`), what changed, and what was skipped and why. The repo counts as current only when `yayh harness status` says `current`. That happens once nothing was skipped. Read `${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md` for the versions between old and new, and name any new skills, config keys or behavior changes in one line each.

## Don'ts
- Never edit kit files by hand to "fix" a diff. Change `.yay/config.json` or `.yay/settings.extra.json`, then sync.
- Never touch the `yay:project` block of `CLAUDE.md`, `docs/knowledge/`, or workflow docs (roadmap, plans, bugs…).
