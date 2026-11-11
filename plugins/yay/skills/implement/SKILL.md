---
name: implement
description: Build a ready Yay plugin plan task by task in its own worktree and branch. Use when the user says "implement P-4", "build this plan", "start on the plan", "continue the implementation". Implements, verifies and ticks each task, commits with a Plan trailer, runs the full checks, refreshes knowledge it made stale, and opens a PR assigned to its owner.
argument-hint: "<P-<n>|plan-slug> [--task=T<n>] [--continue] [--no-worktree] [--base=<branch>] [--pr|--no-pr] [--draft] [--no-push] [--no-review]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:implement

Arguments: `$ARGUMENTS`

Implement a plan exactly, in a worktree, with one commit per task. The rules for branches, commits and PRs are in `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Options

| Option | Effect |
|---|---|
| `<P-n\|slug>` | The plan to build. |
| `--task=T<n>` | Do only this task, then stop (still verify, tick and commit it). |
| `--continue` | Resume an `in-progress` plan in its existing worktree, starting at the first unticked task. |
| `--no-worktree` | Create the branch in the current checkout (`git switch -c`) instead of a worktree. |
| `--base=<branch>` | Branch from here instead of `git.baseBranch`. |
| `--pr` / `--no-pr` | Push and open the PR without asking, or stop after the last commit. The default is to ask once, at the end. |
| `--draft` | Open the PR as a draft. |
| `--no-push` | Never push (this also means no PR). |
| `--no-review` | Skip the reuse and comments review (step 4.4). For throwaway branches only. |

## Steps

### 1. Load and gate
- `plan="$(yayh artifact resolve <arg>)"` and read it in full.
- `yayh plan check "$plan"` must have no errors. If it does, stop and suggest `/yay:plan --check`.
- Check the status:
  - `ready` → go.
  - `draft` → ask whether to proceed anyway.
  - `in-progress` → behave as `--continue`.
  - `done` or `dropped` → stop.
- Read the project block, the knowledge docs the plan touches, and every file the tasks name.

### 2. Branch and worktree (skip with `--continue`)
1. Get the branch name: `branch="$(yayh git branch-name <plan type> "<plan title>")"`.
2. Create the branch in one of two ways:
   - **Worktree (default):** `wt="$(yayh git worktree "$branch" <base>)"`, then `cd "$wt"`. From here on you work **only** in the worktree.
   - **`--no-worktree`:** `git switch -c "$branch" <base>`.
3. Carry the new artifacts into the branch: `yayh artifact carry "$wt" <plan file> <its from: brainstorm/bug file if untracked>`, run from the main checkout. Skip this with `--no-worktree`, because untracked files follow the switch.
4. In the branch:
   - `yayh fm set <plan> status in-progress`
   - `yayh fm set <plan> branch "$branch"`
   - if the plan has `roadmap: R-<n>`, run `yayh roadmap set R-<n> status in-progress`
5. Run `yayh id conflicts`. If an ID clashes with the base branch, renumber this branch's artifact with `yayh id next`, then update its `id:` and every reference to it.
6. Commit: `docs(plan): start P-<n> <title>` with the trailer `Plan: P-<n>`.

Install dependencies if the worktree needs them: `yayh run install`, once.

### 3. Task loop
For each unticked task in order (or only `--task`):
1. **Do exactly the task, reusing what exists.** Call what the task's `Reuse:` line names. Before adding any function the plan didn't name, run `yayh code find <verb> <noun>` and check `docs/knowledge/helpers.md`. Follow the code rules loaded at session start (`${CLAUDE_PLUGIN_ROOT}/reference/code-rules.md`): small diffs, and no new, grown or reworded comments beyond what WPCS needs. If the plan turns out to be wrong (a file moved, an approach fails), stop and tell the user. With their agreement, edit the plan's task text first, then continue. Never drift silently.
2. **Verify the task:** run the configured checks that apply to what changed:
   - `yayh run lint`, or the linter on the changed files if the project block says how
   - `yayh run typecheck` for TS changes
   - the tests listed in the plan's `**Tests:**` line that touch this task

   Fix what fails. If something fails that your change can't explain, check whether it also fails on the base branch: `git stash`, or run it in a temporary detached worktree of the base. A pre-existing failure is reported, not fixed.
3. **Tick the task:** `yayh plan tick <plan> T<n>`.
4. **Commit** the code and the ticked plan together:
   ```
   git add -- <files you changed> <plan file>
   git commit -m "<type>(<scope>): <task summary>" -m "<why, if not obvious>" -m "Plan: P-<n>"
   ```
   Add `Roadmap: R-<n>` on the commit that completes the item. Stage by path. Never use `git add -A` (other people's untracked files, and the generated paths the hooks guard). If a hook rejects the commit, fix the cause; never use `--no-verify`.

### 4. Finish
1. Run all of `lint`, `typecheck`, `test` and `build` that exist in the config (`yayh run <name>`). For `build` with editions, build each edition the plan touches (`edition=<e>`). Report pre-existing failures separately (compare with the base, as in step 3.2).
2. Walk through the plan's **Verify** list. Do each check you can (CLI, WP-CLI against `yayh config get site.wpPath`, reading the output). List the checks only a human can do (browser flows) for the PR.
3. Run `yayh debug markers`. It must be empty.
4. **Review for reuse and comments** (skip with `--no-review`):
   - Run `yayh review diff <base> --plan=P-<n>`.
   - Spawn one `yay:code-reviewer` agent. Its brief: the worktree path, the base branch, `P-<n>`, and "review this branch". Don't pass your own reasoning, so its read stays independent.
   - For each finding, either fix it or answer it:
     - **Fix:** call the existing helper, delete or restore the comment. Commit `refactor(<scope>): reuse <helper>` or `style(<scope>): restore comments` with the `Plan:` trailer, then re-run the checks the change touches.
     - **Answer:** you disagree, with a reason. It goes in the PR under "Reuse and comments review".

   The review flags, it never blocks.
5. Run `yayh knowledge stale --since=<base>`. For each doc this branch made wrong, update it now on this branch, following `/yay:knowledge-update`'s rules. Then `yayh knowledge check` must pass, and you run `yayh knowledge stamp <doc>`. Commit it as `docs(knowledge): …`.
6. Run `yayh fm set <plan> status done` and commit it as `docs(plan): complete P-<n>`.

### 5. Push and PR
Skip this with `--no-pr` or `--no-push`. Without `--pr`, ask once: "Push `<branch>` and open a PR into `<base>`?"
```
git push -u origin "$branch"
gh pr create --base <base> --head "$branch" --assignee @me [--draft] \
  --title "<type>(<scope>): <plan title, lowercase summary>" --body-file <tmp>
```
Fill the PR body from `.github/pull_request_template.md`:
- link `P-<n>` (and `R-<n>`, `BS-<n>`)
- list what changed
- give the exact checks run, with their results, and the manual checks that are left
- name the editions
- write a customer-facing release note line, or "internal"
- under "Reuse and comments review": the findings you fixed (one line each), and the ones you answered, with your reason

Then record the PR number with `yayh fm set <plan> pr <number>`, and commit and push that.

### 6. Report
Give the branch, the worktree path, the commits (one line each), the checks and their results, the review findings (fixed and answered), the pre-existing failures, the knowledge updated, the PR URL, and the manual checks left for the reviewer.

## Don'ts
- Don't implement anything the plan doesn't list. Note follow-ups in the report, or as a backlog idea (`yayh artifact new backlog …`).
- Don't add tests beyond the plan's `**Tests:**` line without asking.
- Don't work in the main checkout once the worktree exists. Don't commit on the base branch.
