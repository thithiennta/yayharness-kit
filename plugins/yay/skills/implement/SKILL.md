---
name: implement
description: Build a Yay plugin plan task by task in its own worktree and branch, or plan a requirement first and then build it. Use when the user says "implement P-4", "build this plan", "start on the plan", "continue the implementation", or "implement <a requirement>" / "implement R-12" when no plan exists yet. Implements, verifies and ticks each task, commits with a Plan trailer, runs the full checks, refreshes knowledge it made stale, and opens a PR assigned to its owner.
argument-hint: "<P-<n>|plan-slug|\"<requirement>\"|R-<n>|BS-<n>|B-<n>> [--type=feat|fix|chore|refactor|perf] [--task=T<n>] [--continue] [--explore] [--lane=tiny|small|standard] [--no-worktree] [--base=<branch>] [--no-pr] [--draft] [--no-review]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:implement

Arguments: `$ARGUMENTS`

Implement a plan exactly, in a worktree, with one commit per task. Given a requirement instead of a plan, write the plan first (step 0), then build it. The rules for branches, commits and PRs are in `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Options

| Option | Effect |
|---|---|
| `<P-n\|slug>` | The plan to build. |
| `"<requirement>"` | No plan yet: plan this text first (step 0), then build it. |
| `R-<n>` / `BS-<n>` / `B-<n>` | Build the plan made from this source, or plan it first when there is none (step 0). |
| `--type=<t>` | Branch and commit type for a plan written in step 0 (default `feat`; `fix` for a bug). |
| `--task=T<n>` | Do only this task, then stop (still verify, tick and commit it). |
| `--explore` | For an `R-<n>` or a requirement with no brainstorm: compare two approaches first (a quick brainstorm), then plan and build, all in this session, with one question round. Default: only when the approach isn't obvious. |
| `--lane=tiny\|small\|standard` | How much planning a requirement gets in step 0. Default: you pick (see step 0). |
| `--continue` | Resume an `in-progress` plan in its existing worktree, starting at the first unticked task. |
| `--no-worktree` | Create the branch in the current checkout (`git switch -c`) instead of a worktree. |
| `--base=<branch>` | Branch from here instead of `git.baseBranch`. |
| `--no-pr` | Stop after the last commit, and print the push and PR commands. Default: push the branch and open the PR, assigned to you. |
| `--draft` | Open the PR as a draft. |
| `--no-push` | Same as `--no-pr`. |
| `--no-review` | Skip the reviews (step 4.5). For throwaway branches only. |

## Steps

### 0. No plan yet
When the argument isn't a plan (a requirement, or an `R-`/`BS-`/`B-<n>` with no plan made from it), read `${CLAUDE_PLUGIN_ROOT}/reference/implement-unplanned.md` and follow it. It picks the lane: **tiny** builds with no plan file, **small** and **standard** write the plan and then continue at step 1. Skip this step when the argument is a plan (`P-<n>`, or text `yayh artifact resolve` finds under `docs/plans/`).

### 1. Load and gate
- `plan="$(yayh artifact resolve <arg>)"` (or the plan step 0 found or wrote) and read it in full.
- `yayh plan check "$plan"` must have no errors. If it does, stop and suggest `/yay:plan --check`.
- Check the status:
  - `ready` → go.
  - `draft` → proceed, and say so in the report (a draft that passes `plan check` is buildable).
  - `in-progress` → behave as `--continue`.
  - `done` or `dropped` → stop.
- Read the project block, the knowledge docs the plan touches, and every file the tasks name. When the plan has `design: UX-<n>`, read the design too: UI tasks build its screens, states and copy exactly, with the components it names.
- **Pick up open notes:** run `yayh backlog open --for=P-<n>`. These are decisions and later work that earlier steps parked for this plan, its roadmap item or its source, including notes on other branches. Handle each one as `/yay:plan` describes under "Picking up notes" (`${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`): settle the ones the code, the finished work or this round can now answer, and update the plan to match. That means rewriting the tasks, the `Reuse:` lines and the Tests and Verify items they change, and adding a task where a settled decision differs from what an earlier plan already built. Then run `yayh plan check` again. Also apply any `Settles: BL-<n> …` lines the plan carries under `## Risks`. Plan edits and settles happen in the branch: if there's no branch yet, make them right after step 2. A decision that still can't be made stays open, and the plan follows its default. It never stops the run.
- **Hard questions only, once, now** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`). Include any carried over from step 0. Ask only if the plan leaves a decision that's expensive to undo or that only the user can make (for example, customer-visible behaviour the plan doesn't pin down): at most 3, in one AskUserQuestion. Everything else the plan leaves open, decide in its spirit and list under **Decided** in the PR. Usually that means no questions at all. Never stop mid-task to ask, unless the plan turns out wrong in a way that changes scope or what customers see (step 3.1).

### 2. Branch and worktree (skip with `--continue`)
1. Get the branch name: `branch="$(yayh git branch-name <plan type> "<plan title>")"`.
2. Create the branch in one of two ways:
   - **Worktree (default):** `wt="$(yayh git worktree "$branch" <base>)"`, then `cd "$wt"`. From here on you work **only** in the worktree.
   - **`--no-worktree`:** `git switch -c "$branch" <base>`.
3. Carry the new artifacts into the branch: `yayh artifact carry "$wt" <plan file> <its from: brainstorm/bug file if untracked> <untracked backlog notes from P-<n>>`, run from the main checkout. Skip this with `--no-worktree`, because untracked files follow the switch. Then run `yayh artifact tidy --yes` from the main checkout: it removes only untracked copies whose exact twin is already committed in another worktree, the leftovers of an earlier carry that didn't finish.
4. In the branch:
   - `yayh fm set <plan> status in-progress`
   - `yayh fm set <plan> branch "$branch"`
   - if the plan has `roadmap: R-<n>`, run `yayh roadmap set R-<n> status in-progress`
   - settle the notes step 1 decided (`yayh backlog settle …`) and apply the plan edits they need
5. Run `yayh id conflicts`. If an ID clashes with the base branch, renumber this branch's artifact with `yayh id next`, then update its `id:` and every reference to it.
6. Commit: `docs(plan): start P-<n> <title>` with the trailer `Plan: P-<n>`. Include the settled notes, the carried notes and the roadmap files the status change touched (`git status -- docs/roadmap docs/roadmap.md`).

Install dependencies if the worktree needs them: `yayh run install`, once.

### 3. Task loop
For each unticked task in order (or only `--task`):
0. **Route it.** `yayh model resolve task --plan=P-<n> --task=T<n>`. `{}` (the usual case) means do it inline as below. Anything else means delegate the task to one `general-purpose` agent with that model and effort, briefed as in `${CLAUDE_PLUGIN_ROOT}/reference/models.md` (Per-task delegation). If the command fails, delegate on `opus` with `medium` effort. Then review its diff and carry on from step 2 yourself: verify, tick, commit.
1. **Do exactly the task, reusing what exists.** Read the plan's **Findings** before the first task: they're the facts the plan was built on. Call what the task's `Reuse:` line names. Before adding any function the plan didn't name, run `yayh code find <verb> <noun>` and check `docs/knowledge/helpers.md`. Follow the code rules loaded at session start (`${CLAUDE_PLUGIN_ROOT}/reference/code-rules.md`): small diffs, and no new, grown or reworded comments beyond what WPCS needs. If the plan turns out wrong:
   - In a `strict` repo (`yayh config get workflow.strictness standard`), every plan change is the second case: stop and ask.
   - **Same goal, same scope, same customer-visible behaviour** (a file moved, a hook or API has another name, an approach fails and an equivalent one works, a task needs one more file): adapt. Edit the task text (and its `Reuse:`, Tests or Verify line) in the same commit as the code, and list the change under **Decided** in the PR. Don't stop.
   - **The scope or what customers see would change** (a new setting, different behaviour, another edition, a much bigger change): stop and tell the user what you found and what you propose. With their agreement, edit the plan first, then continue. With nobody to ask, commit what works and report it as blocked.

   Either way, the plan and the code never disagree: no silent drift.
   - **A decision the plan doesn't settle and you can't responsibly make** (customer-visible wording, a behaviour product must choose, an outcome that depends on other work): don't stop. Take the default that fits the plan, write it as a decision note (`yayh artifact new backlog "<question>" kind=decision from=P-<n> default="<what you built>" [affects=…]`), and go on. Any later plan that touches this one finds the note and settles it.
   - **The design doesn't fit the code** (a component it names doesn't exist, a state it missed): build the closest thing in the design's spirit, update the design file in the same commit (its Screens, States or Copy), and list it under "Decided" in the PR.
   - **Work you find that the plan doesn't list** (a follow-up, an adjacent gap, a nice-to-have): don't build it. Write a `kind=deferred` note (`from=P-<n>`, plus `affects=` when you know which item it belongs to).
2. **Verify the task:** run the configured checks that apply to what changed:
   - `yayh run lint`, or the linter on the changed files if the project block says how
   - `yayh run typecheck` for TS changes
   - the tests on the plan's `**Tests:**` line that belong to this task. Write them in the same task, following `/yay:test` steps 3–4: tag them `P-<n>`, put them at the layer the plan names, and prove that they fail without the change. Run them with `yayh test run <layer> --id=P-<n>`. Integration needs this worktree's tests site (`yayh e2e env start`); without Docker, write the tests and mark them **not run**.
   - `yayh code unused <base>`: every symbol this task added has a caller. Delete one that doesn't, unless a later task's `Callers:` line wires it up. A test alone isn't a caller.

   Fix what fails. If something fails that your change can't explain, check whether it also fails on the base branch: `git stash`, or run it in a temporary detached worktree of the base. A pre-existing failure is reported, not fixed.
3. **Risk-3 tasks get a review before the commit** (`yayh plan risk P-<n> T<n>` prints `3`; skipped with `--no-review`). Spawn one read-only `yay:bug-reviewer` with the model and effort from `yayh model resolve review --plan=P-<n>`. Its brief: the worktree path, "review the uncommitted diff (`git diff`, plus untracked files) of task T<n>", the task's text, and the plan's **Goal**, with none of your reasoning. Fix each finding before committing, or answer it with a reason. Either way it goes under "Review" in the PR, marked `T<n>`. The final review (step 4.5) still runs on the whole branch; this one catches a data, money or background-job mistake while it's still one task's diff.
4. **Tick the task:** `yayh plan tick <plan> T<n>`.
5. **Commit** the code and the ticked plan together:
   ```
   git add -- <files you changed> <plan file>
   git commit -m "<type>(<scope>): <task summary>" -m "<why, if not obvious>" -m "Plan: P-<n>"
   ```
   Commit the backlog notes the task wrote along with it. Add `Roadmap: R-<n>` on the commit that completes the item. Stage by path. Never use `git add -A` (other people's untracked files, and the generated paths the hooks guard). If a hook rejects the commit, fix the cause; never use `--no-verify`.

### 4. Finish
1. Run all of `lint`, `typecheck` and `build` that exist in the config (`yayh run <name>`), and the tests with `yayh test run all` (every configured layer: unit, integration when the tests site is up, and js; it falls back to `commands.test`). For `build` with editions, build each edition the plan touches (`edition=<e>`). Report pre-existing failures separately (compare with the base, as in step 3.2).
2. **E2E** (when the plan's `**E2E:**` line isn't `none` and `commands.e2e` is set): follow `/yay:e2e P-<n>` steps 1–5 in this worktree. Write the specs, tagged `@P-<n>`. Run `yayh e2e run --grep "@P-<n>|@smoke"` against this worktree's own site (`yayh e2e env start` gives it its own port). Classify any failure: a product bug is yours to fix now, since it's this branch's code. Commit as `test(e2e): <flow>` with the `Plan:` trailer. Without Docker, write and commit the specs anyway, and list them as **not run** in the PR. When you're done, stop the site with `yayh e2e env stop`.
3. Walk through the plan's **Verify** list (it includes the design's Acceptance checks). Run `yayh verify P-<n> --run`: every ``- `command` → expected`` check runs, and a `fail` is a bug in this branch to fix now (or a wrong check, which you correct in the plan, saying so under **Decided**). Do the other checks you can by hand (WP-CLI against `yayh config get site.wpPath`, reading the output). List the checks only a human can do (browser flows) for the PR, and paste the `verify` result into its Verified section.
4. Run `yayh debug markers`. It must be empty. Then run `yayh code unused <base>` and deal with each symbol it lists: delete it, or call it where the plan needs it. Keep one only when WordPress or WooCommerce calls it by name (an override, a callback named in a string), and say so under **Decided** in the PR.
5. **Review: correctness, then reuse and comments** (skip with `--no-review`):
   - Run `yayh review diff <base> --plan=P-<n>`.
   - Spawn two read-only agents in parallel (one message), each with the model and effort from `yayh model resolve review --plan=P-<n>` (model routing: `${CLAUDE_PLUGIN_ROOT}/reference/models.md`). Don't pass your own reasoning to either, so their reads stay independent.
     - `yay:bug-reviewer`. Its brief: the worktree path, the base branch, and the plan's **Goal** paragraph copied as it is, the tasks `yayh plan risk P-<n>` rates 3 (their text, as "the hard-to-undo parts"), and "review this branch for correctness".
     - `yay:code-reviewer`. Its brief: the worktree path, the base branch, `P-<n>`, and "review this branch".
   - For each finding, either fix it or answer it:
     - **Fix:** the change the finding names. Commit `fix(<scope>): <what>` for a correctness finding, or `refactor(<scope>): reuse <helper>` / `refactor(<scope>): restore comments`, with the `Plan:` trailer, then re-run the checks the change touches. A bug fix gets a test at the cheapest layer that proves it, when it's a real risk.
     - **Answer:** you disagree, with a reason. It goes in the PR under "Review".
   - **A `blocker`** (a security hole, or data lost or corrupted) is fixed before the PR, never answered away. If you can't fix it, open the PR as a draft and put the blocker first in its body.
   - Each reviewer's **Questions**: check the ones you can, and list the rest for the human reviewer.

   Apart from blockers, the reviews flag and never block.
6. Run `yayh knowledge stale --since=<base>`. For each doc this branch made wrong, update it now on this branch, following `/yay:knowledge-update`'s rules. Then `yayh knowledge check` must pass, and you run `yayh knowledge stamp <doc>`. Commit it as `docs(knowledge): …`.
7. Run `yayh fm set <plan> status done`. If the plan has `roadmap: R-<n>` and it's the item's last open plan, also run `yayh roadmap set R-<n> built "$(date +%Y-%m-%d)"` (with `started`, set when the item went in-progress, it's the item's pace record for `yayh roadmap pace`). Commit both as `docs(plan): complete P-<n>`, with the roadmap files (`git status -- docs/roadmap docs/roadmap.md`).

### 5. Push and PR
Do this by default, without asking. With `--no-pr` or `--no-push`, skip it and end the report with the exact commands (`git push -u origin <branch>` and the `gh pr create …` line). If there's no `origin` remote, or `gh` isn't installed or logged in, skip it the same way, and say why (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`).
```
git push -u origin "$branch"
gh pr create --base <base> --head "$branch" --assignee @me [--draft] \
  --title "<type>(<scope>): <plan title, lowercase summary>" --body-file <tmp>
```
Fill the PR body from `.github/pull_request_template.md`:
- link `P-<n>` (and `R-<n>`, `BS-<n>`, `UX-<n>`; with a design, mention its mockup path when one exists, which reviewers can regenerate with `/yay:design UX-<n> --mockup`)
- list what changed
- under "Worth a closer look": the 2–5 places a reviewer should read first (risk-3 tasks first, then the plan's Findings that shaped the code), each as `path:line`: what it does and why it's done that way
- give the exact checks run, with their results (e2e specs by tag: passed, or not run)
- under "Not verified": every check that didn't run here and why (no browser, no Docker, one edition), and what a human must do before merging; "none" when everything ran
- under "How to test": numbered steps for the reviewer, built from the plan's manual Verify items (where to go, the input, what they should see), with one edge case
- name the editions
- write a customer-facing release note line, or "internal"
- under "Decided": the choices you made where the plan was silent
- under "Open decisions and later work": every note this branch wrote or left open (`BL-<n>`, the question, the default built), and every note it settled
- under "Review": the correctness and the reuse and comments findings you fixed (one line each), the ones you answered with your reason, and the open questions

Then record the PR number with `yayh fm set <plan> pr <number>`, and commit and push that.

### 6. Report
Give the plan (and, when step 0 wrote it, that it did, with its task count and any **Decided** planning choices), the notes settled and the notes written or still open (`BL-<n>`, kind, default), the branch, the worktree path, the commits (one line each), the checks and their results, the pre-existing failures, the knowledge updated, the PR URL, and the manual checks left for the reviewer. End with the **Next** line (`reference/asking.md`): `yayh next P-<n>` (the plan is done, so this is the most urgent other work).

The reviews get a section of their own, one line per reviewer, even when a reviewer found nothing. Never merge the two into one list:
```
**Reviews**
- Correctness (`yay:bug-reviewer`, with the risk-3 task reviews): <each finding: fixed, or answered with the reason, or parked as BL-<n>>, or "clean"
- Reuse and comments (`yay:code-reviewer`): <each finding, the same way>, or "clean"
```

## Don'ts
- Don't implement anything the plan doesn't list. Write follow-ups as deferred notes (`yayh artifact new backlog "<what>" kind=deferred from=P-<n>`).
- Don't stop for a decision you can park: build the default and write the decision note.
- Don't add tests beyond the plan's `**Tests:**` line without adding them to that line first (with their layer). Don't move a test to a costlier layer than the plan says.
- Don't work in the main checkout once the worktree exists. Don't commit on the base branch.
