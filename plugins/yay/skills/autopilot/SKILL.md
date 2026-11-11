---
name: autopilot
description: Take many Yay roadmap items from idea to built branch in one run - brainstorm, plan and implement each - with a single decision sheet up front instead of a question round per item. Use when the user says "autopilot", "do the whole sprint", "process all of them", "build everything on the roadmap", "run the long-term plan", "plan and implement R-3, R-5 and R-7", or wants to stop giving decisions task by task.
argument-hint: "[R-<n>... | P-<n>...] [--sprint=<n|current|later>] [--ready] [--parallel=N] [--plan-only] [--no-ask] [--no-pr] [--draft] [--dry-run]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Read, Grep, Glob, Write, Edit, AskUserQuestion, Workflow
---

# /yay:autopilot

Arguments: `$ARGUMENTS`

The normal flow is **roadmap item → `/yay:brainstorm` → `/yay:plan` → `/yay:implement`**, one invocation and possibly one question round per step. Autopilot runs that flow for a whole queue: it plans every item first, asks **one** decision sheet for the whole run, then builds every item unattended, one branch per item, through `${CLAUDE_PLUGIN_ROOT}/workflows/autopilot.js`. The steps themselves are the normal skills, followed by workflow agents. Autopilot adds ordering, one decision point and a run report; it doesn't add rules.

## Options

| Option | Effect |
|---|---|
| `R-<n>… \| P-<n>…` | The items to run. A plan stands for its roadmap item. |
| `--sprint=<n\|current\|later>` | Every item in that section. |
| `--ready` | Every `ready` plan. |
| `--parallel=N` | Build up to N independent items at once (each in its own worktree). Default 1: one at a time, in dependency order. |
| `--plan-only` | Stop after the decision sheet: plans written and marked ready, nothing built. |
| `--no-ask` | Skip the sheet: take every recommendation and list it under **Decided**. Also the behaviour when nobody is there to answer. |
| `--no-pr` / `--draft` | By default each finished branch is pushed and its PR opened (stacked PRs base on their dependency's branch). `--no-pr` keeps everything local and the report lists the commands. |
| `--dry-run` | Show the queue and the agent count, and change nothing. |

With no scope at all, use `--sprint=current`.

## Steps

**Wait for every workflow.** The Workflow tool returns at once and runs in the background. Don't end your turn while a prepare or build workflow is running: wait for its completion notification, then go on to the next step. In a non-interactive run (`claude -p`, CI), ending the turn ends the session, and that kills the workflow half-built.

1. **Queue.** `yayh roadmap queue <ids> [--sprint=…] [--ready]` prints the build order as TSV: `id stage artifact after waits title`.
   - `stage` is where each item is: `brainstorm`, `decide` (open brainstorm), `plan` (decided brainstorm), `implement` (draft or ready plan), `continue` (in progress), `review` (built by an earlier run that stopped before its reviews: the plan is `done` with `reviewed: pending`), `done`, `dropped`. Re-running autopilot on the same scope therefore resumes where the last run stopped.
   - `after` are dependencies inside the run (built first; the dependent's branch stacks on theirs). `waits` are unmet dependencies outside it (another plugin, an item not in scope): those items are planned but not built. Say which.
   - A dependency cycle is an error: report it and stop.
   - Check `git status`: the main checkout must have no tracked changes (`yayh artifact carry` refuses tracked, modified artifacts). Run `yayh artifact tidy --yes` first, so leftover copies from an interrupted run don't count. `yayh artifact where <id>` shows where any artifact's copies are.
2. **Show the queue** as a table (order, id, title, stage, after/waits), with the agent count: about 1 per item to prepare, plus about 3 per item to build (implement, review, resolve), and 1 more per revised item. With `--dry-run`, stop here. Don't ask whether to start: the user asked for the run. Only when the run is over 10 items **and** `--parallel` > 3, make "start N agents?" one question of step 4's round.
3. **Prepare.** Run the Workflow tool with `scriptPath: ${CLAUDE_PLUGIN_ROOT}/workflows/autopilot.js` and
   ```json
   { "mode": "prepare", "kit": "<yayh root>", "repo": "<repo root>", "base": "<yayh git base>", "today": "YYYY-MM-DD",
     "parallel": 1, "models": { /* yayh model table --json */ },
     "items": [{ "id": "R-3", "stage": "decide", "artifact": "BS-1", "after": [], "waits": [], "title": "…", "size": "M" }] }
   ```
   Map the TSV's `-` to `""` or `[]`, and split `after`/`waits` on commas. Take each item's `size` from `yayh roadmap get <id> size`, and `models` verbatim from `yayh model table --json`. The workflow picks each agent's model and effort from these (`${CLAUDE_PLUGIN_ROOT}/reference/models.md`). Pass `parallel` from `--parallel` (`yayh artifact new` locks ids, so parallel prepare is safe). Each agent brainstorms (when needed) and plans its item in the main checkout, settles the open backlog notes the evidence now answers (`yayh backlog open --for=<id>`), marks the plan `ready` unless it hit a hard call, and returns at most 2 hard questions. Calls it can't make and that aren't worth a question become decision notes with a default; they never keep an item from building.
4. **The decision sheet: the one stop of the run** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`).
   - Collect every returned question, plus every open decision note on the queue's items that no agent asked about (`yayh backlog open --kind=decision --for=<id>` per item). Rank them by cost of a wrong call (customer-visible, hard to undo, wide blast radius).
   - Ask the top ones in **one** AskUserQuestion (up to 4 questions; each names its item and puts the plan's current option first, marked "(Recommended)"). Every question that doesn't fit takes its recommendation; say so under **Decided** in the sheet.
   - With `--no-ask`, or with no questions at all, ask nothing.
   - Write the sheet to `.yay/runs/<today>-autopilot.md` (gitignored): the queue, every item's plan and option, each question with its answer (or "recommended, not asked"), every agent's **decided** list, and the decision notes still open with the default each build follows.
   - An answered decision note goes into that item's `answers` entry as `BL-<n>: <answer>`, so the revise step settles it. A note that isn't asked stays open, and the build follows its default. Items prepare **blocked** are listed with their reason and are not built.
   - With `--plan-only`, report and stop. The plans are ready for `/yay:implement` or a later `/yay:autopilot --ready`.
5. **Build.** Run the Workflow tool again with the same `scriptPath` and
   ```json
   { "mode": "build", "kit": "…", "repo": "…", "base": "…", "today": "…", "parallel": 1, "pr": true, "draft": false, "models": { /* as in prepare */ },
     "items": [ /* the queue again, from a fresh `yayh roadmap queue`, so each artifact is now the P-<n>; with size */ ],
     "answers": { "R-3": "Option B (no free-text coupon field); include test X" } }
   ```
   For a `review` item, add `branch` (`yayh fm get <plan> branch`), `worktree` (`yayh git worktree <branch>`, which reuses the existing one) and `base` (the branch it was built on, from its first commit's parent or `git.baseBranch`). The workflow runs only the reviewers and resolve on it.
   `answers` holds every item that returned a question, with its answer (or its recommendation, when it wasn't asked), written so an agent can apply it: the revise step records the decision, clears the plan's "Open (autopilot sheet)" risks and marks it ready. Per item the workflow:
   - waits for its `after` items (a blocked dependency skips it, with the reason)
   - applies its answer to the brainstorm and plan (revise)
   - follows `/yay:implement` in its own worktree, branched from `base` or, when stacked, from the dependency's branch (other dependencies are merged in)
   - runs `yay:bug-reviewer` (correctness) and `yay:code-reviewer` (reuse and comments) in parallel, then fixes or answers each finding (a security or data-loss blocker is fixed, or the PR goes up as a draft)
   - unless `--no-pr`, pushes and opens the PR (based on the dependency's branch for a stacked item)

   A blocked item leaves its branch with whatever was committed, and the run goes on with everything that doesn't depend on it. Nothing in this step asks the user.
6. **Report.** Append the results to the run sheet, then show:
   - one row per item: id, title, result (done / blocked / skipped), branch, base, commits, checks (pre-existing failures marked)
   - every decision and deferred note the run wrote or left open (`BL-<n>`, item, default), so the next run, or the next plan on the same item, picks them up
   - every blocker, with what a human must do, and the command that resumes after it's fixed (`/yay:autopilot <ids>` again, or `/yay:implement P-<n> --continue`)
   - the review findings fixed and answered, and every **Decided** line, grouped per item
   - the manual checks left for a human
   - the PR links, in stack order (dependencies first), or with `--no-pr` the push and `gh pr create` commands in that order
   - the run sheet's path
   - the **Next** line (`reference/asking.md`): the resume command when something blocked, else `yayh next`

## Don'ts
- Don't ask anything outside step 4. A question that turns up later is decided in the plan's spirit, written as a decision note with its default, and listed under **Decided**. A real blocker blocks only its item.
- Don't build an item whose plan prepare blocked, whose dependency didn't finish, or that waits on work outside the run.
- Don't push with `--no-pr`, and never push tags. Never force-push, never `--no-verify`, never commit on the base branch.
- Don't plan past what the roadmap item and its evidence support. Scope growth becomes a deferred note, as in `/yay:implement`.
