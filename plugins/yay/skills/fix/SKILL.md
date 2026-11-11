---
name: fix
description: Fix a diagnosed Yay plugin bug on its own branch and worktree. Use when the user says "fix B-7", "fix this bug", "patch this", "hotfix". Makes the minimal change, agrees a regression test, verifies, commits fix(scope) with a Fixes trailer and opens a PR assigned to its owner. --hotfix branches from the last release tag; grows into /yay:plan when the fix does.
argument-hint: "<B-<n>|bug-slug|description> [--hotfix] [--from=<tag>] [--test|--no-test] [--no-worktree] [--escalate] [--no-pr] [--draft]"
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
| `--test` / `--no-test` | Write the proposed regression test without asking, or skip it and rely on the manual check. Default: write it, unless the repo's rules say tests need approval (then it's one question in step 4's round). |
| `--no-worktree` | Branch in the current checkout instead of a worktree. |
| `--escalate` | Stop and hand off to `/yay:plan --from=B-<n>`. This also happens automatically when the fix outgrows its scope (step 3). |
| `--no-pr`, `--draft`, `--no-push` | As in `/yay:implement`: the PR is opened by default; `--no-pr` stops after the commit. |

## Steps

### 1. The cause
- Resolve the report with `yayh artifact resolve <arg>`.
  - `root-caused` → go.
  - `open` with low confidence → this becomes a question in the single round (step 4): investigate more (`/yay:debug B-<n>`), or proceed.
  - `fixed`, `wontfix` or `duplicate` → stop.
- **No report, only a description:** do a `/yay:debug --quick` pass inline. Create the report with `yayh artifact new bug …`, find the cause with `file:line` evidence, and fill in Root cause and Fix options. If the cause isn't clear within a reasonable read, stop and suggest `/yay:debug`.
- Choose the fix option: the report's recommended one, unless the user says otherwise.
- Run `yayh backlog open --for=B-<n>`. Settle the notes the fix answers (in the branch, step 2), and keep the others open.

### 2. Branch
- `branch="$(yayh git branch-name <fix|hotfix> "<bug title>")"`
- Hotfix: `from="${from_tag:-$(yayh git last-tag)}"`. Otherwise use `git.baseBranch`.
- `wt="$(yayh git worktree "$branch" "$from")"`, then `cd "$wt"`. With `--no-worktree`, `git switch -c "$branch" "$from"` instead.
- Carry the report if it's untracked: `yayh artifact carry "$wt" <report>`.
- `yayh fm set <report> branch "$branch"`.
- For a hotfix, check that the bug exists at the tag: are the root-cause lines present there? If they aren't, it's not a hotfix; say so.

### 3. Fix, minimally
- Change only what the root cause needs, calling the existing helpers the code already has (`yayh code find <verb> <noun>`) rather than writing new ones. Don't touch comments the fix doesn't make wrong. No refactors and no drive-by fixes; write each as a deferred note (`yayh artifact new backlog "<what>" kind=deferred from=B-<n>`). A call the fix can't make (customer-visible behaviour the report doesn't pin down) becomes a decision note with the default you built (`kind=decision default="…"`); it never stops the fix. Commit the notes with the fix.
- **Escalate** if the fix needs a schema or data migration, touches more than about 3 modules, changes a public API or hook, or needs a design decision. Stop, commit nothing to product code, and run `/yay:plan --from=B-<n> --type=fix`. A planned fix is then built by `/yay:implement`.
- Follow the hard rules: PHP floor, editions boundary, escaping and nonces, HPOS.

### 4. Regression test
Read the report's Regression test proposal. Put the test at the layer where the **root cause** lives (`${CLAUDE_PLUGIN_ROOT}/reference/testing.md`, "Bugs"): **unit** for logic, **integration** for hooks, storage, REST or WooCommerce objects, and **js** for front-end logic. Follow `/yay:test B-<n>` steps 3–4. Tag it `B-<n>`. When the bug came from a baseline test marked `markTestIncomplete( 'B-<n>: …' )`, `test.fails` or `test.failing`, remove the mark; that test is the regression test. If the layer isn't set up, use the manual check and suggest `/yay:test-init`.
- With `--test`, write it.
- With `--no-test`, skip it.
- Otherwise write it, unless the repo's rules (the project block or `.claude/rules/`) say tests need approval. Only then ask, in **one** AskUserQuestion round, together with the low-confidence question from step 1 if it applies. Write the test if accepted. It must fail without the fix and pass with it; check both, for example by `git stash`-ing the fix.

Without a test, do the report's manual check exactly and record the result.

**E2E regression** (only when `commands.e2e` is set, the repro is a browser click path, and no unit test can catch it, for example a JS, template or checkout-markup bug): follow `/yay:e2e B-<n>` steps 1–5. Write one spec tagged `@B-<n>`, and prove it fails with the fix stashed and passes with it. It's part of the fix, so don't ask about it. If a unit test covers the cause, write that instead (it's cheaper). When the bug came from a baseline spec marked `test.fail( true, 'B-<n>: …' )`, remove the mark; that spec is the regression test. Without Docker, write it and mark it **not run**.

### 5. Verify and commit
1. Run the configured checks for what changed (`yayh run lint`, `typecheck`, the relevant `test`). Report pre-existing failures as in `/yay:implement`.
2. Run `yayh debug markers`. It must print nothing.
3. **Review for reuse and comments**: run `yayh review diff <base>`. When it reports findings, or the fix is more than about 20 changed lines, also spawn one `yay:code-reviewer` (brief: worktree path, base, "review this branch"), with the model and effort from `yayh model resolve review` (model routing: `${CLAUDE_PLUGIN_ROOT}/reference/models.md`). Fix each finding, or answer it with a reason for the PR's "Reuse and comments review" section. It flags, never blocks.
4. Update the report:
   - append `## Fix` with what changed, why it's enough, and how it was verified
   - `yayh fm set <report> status fixed` (`fixed_in` is set by `/yay:release`)
5. If the bug is a trap others could hit, add an entry to `docs/knowledge/known-issues.md` (with the evidence). `yayh knowledge check` must pass; then stamp it with `yayh knowledge stamp`.
6. Commit, staging by path:
   ```
   git add -- <changed files> <report> [<e2e spec>] [docs/knowledge/known-issues.md]
   git commit -m "fix(<scope>): <what is fixed, user-facing wording>" -m "<root cause in one or two lines>" -m "Fixes: B-<n>"
   ```

### 6. Push and PR
As in `/yay:implement` step 5: by default, unless `--no-pr`; then print the commands. These things differ:
- the title is the fix header
- for a hotfix, the base is `git.baseBranch`, and the body says: "Hotfix from `<tag>`; release with `/yay:release patch --hotfix`"
- record `pr` in the report

### 7. Report
Give the bug ID, the branch, the change (files), the test (or the manual check and its result), the checks run, the PR URL, and end with the **Next** line (`reference/asking.md`): `yayh next B-<n>`. For a hotfix: `/yay:release patch --hotfix` from this branch.

## Don'ts
- Don't fix without a root cause, and don't widen the fix beyond it.
- Don't skip the failing-first check for a regression test.
- Don't hotfix from the base branch. A hotfix contains only released code plus the fix.
