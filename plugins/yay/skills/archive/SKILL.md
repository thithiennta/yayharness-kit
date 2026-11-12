---
name: archive
description: Clean up finished work a Yay plugin release has shipped, so docs/ stays small over time. Deletes the plans, brainstorms, bugs, backlog notes, designs, roadmap items, empty past sprints and release briefs that were final in the release, and keeps one row each in docs/archive.md (ids stay taken, text is one git show away). Use when the user says "archive", "clean up the roadmap", "clean up old plans", "docs are too big", "tidy the backlog", or after /yay:release --tag-only.
argument-hint: "[--release=<tag>] [--dry-run] [--no-pr]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Read
---

# /yay:archive

Arguments: `$ARGUMENTS`

Finished work piles up in `docs/`: done plans, decided brainstorms, settled notes, shipped roadmap items. This removes what a release has already shipped, on its own branch and PR. Git keeps every removed file. `docs/archive.md` lists each one with the commit that still has it.

## Options

| Option | Effect |
|---|---|
| `--release=<tag>` | Archive what was final in this tag. Default: the latest release tag (`yayh git last-tag`). |
| `--dry-run` | Show what would go and what stays, and stop. |
| `--no-pr` | Commit on the branch, but don't push or open the PR; print the commands. |

## What goes (`yayh artifact archive`)

An artifact goes when all of these hold:
- **It shipped.** Its status was already final in the release tag's tree, and it still is: a plan `done` or `dropped`, a brainstorm `decided` or `dropped`, a bug `fixed`, `wontfix` or `duplicate`, a backlog note that's settled, a roadmap item `shipped:<v>` or `dropped`, a design `dropped` (or `ready` once the plans that built it go).
- **It's committed.** No uncommitted changes.
- **Nothing that stays links to it.** It goes only with every artifact it shares an id link with (front-matter, or a roadmap item's bullets). A plan stays while its roadmap item is still in progress.

A past sprint with no items left goes with its file. A released version's brief goes once none of its items remain. Everything else stays. The dry run says why each finished artifact stays.

## Steps

1. **Preview.** Run `yayh artifact archive [--release=<tag>]` in the main checkout. `archive` lines are what goes; `keep` lines are finished artifacts that stay, with the reason. If nothing would go, say so (and the top `keep` reasons) and stop. With `--dry-run`, show the counts per type and the `keep` reasons, and stop.
2. **Branch.** Don't ask: the PR is the review. `branch="$(yayh git branch-name chore "archive shipped work <tag>")"`, then `wt="$(yayh git worktree "$branch")"`. Run every step below in `$wt`.
3. **Archive.** `yayh artifact archive [--release=<tag>] --yes` in the worktree. It deletes the files, removes the roadmap items and empty past sprints, regenerates the roadmap index, and appends the rows to `docs/archive.md`.
4. **Check.** Run `yayh roadmap check` (when there's a roadmap) and `yayh knowledge check`. A knowledge doc or `CLAUDE.md` that links a removed file points at its `docs/archive.md` row instead, or drops the link. Don't edit other text.
5. **Commit.** Stage by path: `docs/archive.md`, every path on an `archived` line (deleted files stage with `git add -- <path>`), the roadmap files `git status -- docs/roadmap docs/roadmap.md` shows, and any knowledge doc step 4 changed. Then commit `chore(harness): archive work shipped in <tag>`, with one body line per type (`plans: P-3, P-5`).
6. **PR.** Push and open it as `/yay:implement` step 5 does, with the title as the commit header. The body lists what went per type, the `keep` lines that matter, and "How to test": `yayh artifact resolve <one archived id>` names its `git show` command, and `yayh id next P` doesn't reuse an archived id. With `--no-pr`, print the commands.
7. **Report.** Give the counts per type, the PR, and the **Next** line (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`).

## Don'ts
- Never archive in the main checkout or on the base branch.
- Never hand-delete an artifact to make it go. Fix its status, or leave it for the next release.
- Never edit `docs/archive.md` rows. They're how ids stay taken.
