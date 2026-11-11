---
name: fix
description: Fix a diagnosed Yay plugin bug on its own branch and worktree. Use when the user says "fix B-7", "fix this bug", "patch this", "hotfix". Makes the minimal change, agrees a regression test, verifies, commits fix(scope) with a Fixes trailer and opens a PR assigned to its owner. --hotfix branches from the last release tag; grows into /yay:plan when the fix does.
argument-hint: "<B-<n>|bug-slug|description> [--hotfix] [--from=<tag>] [--test|--no-test] [--no-worktree] [--escalate] [--pr|--no-pr] [--draft] [--no-push]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:fix

Arguments: `$ARGUMENTS`

Fix one bug, minimally, on its own branch. **No fix without a cause:** the bug report's Root cause must be filled in before product code changes. Git rules are in `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Options

| Option | Effect |
|---|---|
| `<B-n\|slug>` | The bug report to fix. |
| `<description>` | No report yet. Run a quick inline diagnosis (step 1), which creates `B-<n>` first. |
| `--hotfix` | Branch `hotfix/<slug>` from the latest release tag (`yayh git last-tag`), so `/yay:release --hotfix` can ship a patch without unreleased work. |
| `--from=<tag>` | Branch the hotfix from this tag instead. |
| `--test` / `--no-test` | Write the proposed regression test without asking, or skip it and rely on the manual check. The default is to ask. |
| `--no-worktree` | Branch in the current checkout instead of a worktree. |
| `--escalate` | Stop and hand off to `/yay:plan --from=B-<n>`. This also happens automatically when the fix outgrows its scope (step 3). |
| `--pr` / `--no-pr`, `--draft`, `--no-push` | As in `/yay:implement`. |

## Steps

### 1. The cause
- Resolve the report with `yayh artifact resolve <arg>`.
  - `root-caused` → go.
  - `open` with low confidence → ask: investigate more (`/yay:debug B-<n>`) or proceed.
  - `fixed`, `wontfix` or `duplicate` → stop.
- **No report, only a description:** do a `/yay:debug --quick` pass inline. Create the report with `yayh artifact new bug …`, find the cause with `file:line` evidence, and fill in Root cause and Fix options. If the cause isn't clear within a reasonable read, stop and suggest `/yay:debug`.
- Choose the fix option: the report's recommended one, unless the user says otherwise.

### 2. Branch
- `branch="$(yayh git branch-name <fix|hotfix> "<bug title>")"`
- Hotfix: `from="${from_tag:-$(yayh git last-tag)}"`. Otherwise use `git.baseBranch`.
- `wt="$(yayh git worktree "$branch" "$from")"`, then `cd "$wt"`. With `--no-worktree`, `git switch -c "$branch" "$from"` instead.
- Carry the report if it's untracked: `yayh artifact carry "$wt" <report>`.
- `yayh fm set <report> branch "$branch"`.
- For a hotfix, check that the bug exists at the tag: are the root-cause lines present there? If they aren't, it's not a hotfix; say so.

### 3. Fix, minimally
- Change only what the root cause needs. No refactors and no drive-by fixes; note those in the report under a `## Follow-ups` heading, or as backlog ideas.
- **Escalate** if the fix needs a schema or data migration, touches more than about 3 modules, changes a public API or hook, or needs a design decision. Stop, commit nothing to product code, and run `/yay:plan --from=B-<n> --type=fix`. A planned fix is then built by `/yay:implement`.
- Follow the hard rules: PHP floor, editions boundary, escaping and nonces, HPOS.

### 4. Regression test
Read the report's Regression test proposal.
- With `--test`, write it.
- With `--no-test`, skip it.
- Otherwise ask once with AskUserQuestion, giving the test's name, file and what it guards. Write it only if accepted. It must fail without the fix and pass with it; check both, for example by `git stash`-ing the fix.

Without a test, do the report's manual check exactly and record the result.

### 5. Verify and commit
1. Run the configured checks for what changed (`yayh run lint`, `typecheck`, the relevant `test`). Report pre-existing failures as in `/yay:implement`.
2. Run `yayh debug markers`. It must print nothing.
3. Update the report:
   - append `## Fix` with what changed, why it's enough, and how it was verified
   - `yayh fm set <report> status fixed` (`fixed_in` is set by `/yay:release`)
4. If the bug is a trap others could hit, add an entry to `docs/knowledge/known-issues.md` (with the evidence). `yayh knowledge check` must pass; then stamp it with `yayh knowledge stamp`.
5. Commit, staging by path:
   ```
   git add -- <changed files> <report> [docs/knowledge/known-issues.md]
   git commit -m "fix(<scope>): <what is fixed, user-facing wording>" -m "<root cause in one or two lines>" -m "Fixes: B-<n>"
   ```

### 6. Push and PR
As in `/yay:implement` step 5, with these differences:
- the title is the fix header
- for a hotfix, the base is `git.baseBranch`, and the body says: "Hotfix from `<tag>`; release with `/yay:release patch --hotfix`"
- record `pr` in the report

### 7. Report
Give the bug ID, the branch, the change (files), the test (or the manual check and its result), the checks run, the PR URL, and the next step. For a hotfix: `/yay:release patch --hotfix` from this branch.

## Don'ts
- Don't fix without a root cause, and don't widen the fix beyond it.
- Don't skip the failing-first check for a regression test.
- Don't hotfix from the base branch. A hotfix contains only released code plus the fix.
