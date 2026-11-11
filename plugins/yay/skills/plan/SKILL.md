---
name: plan
description: Write or review a Yay plugin implementation plan. Use when the user says "plan this", "write a plan", "break this down", "review the plan", before any non-trivial change, or when /yay:fix escalates. Turns a brainstorm, roadmap item, bug or request into docs/plans/ P-<n> with goal, approach, tasks naming their files, an agreed Tests line and exact Verify checks. --check reviews one; --trello (optional) adds the tasks to a Trello card.
argument-hint: "<topic|BS-<n>|R-<n>|B-<n>|UX-<n>|P-<n>> [--from=<id>] [--check] [--split] [--type=feat|fix|chore|refactor|perf] [--tests=ask|none] [--edition=<name>|all] [--commit] [--trello]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, mcp__trello__trelloReadBoard, mcp__trello__trelloReadList, mcp__trello__trelloReadCard, mcp__trello__trelloReadChecklist, mcp__trello__trelloReadMember, mcp__trello__trelloWriteCard, mcp__trello__trelloWriteChecklist
---

# /yay:plan

Arguments: `$ARGUMENTS`

A plan is the contract `/yay:implement` follows task by task. The format is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Plan). This skill writes only the plan file (new), or edits a plan that isn't `in-progress` or later.

## Options

| Option | Effect |
|---|---|
| `<topic\|id>` | A topic, or the source artifact: `BS-<n>` (the usual case), `R-<n>`, `B-<n>`, or `P-<n>` to revise an existing plan. |
| `--from=<id>` | The source, when the first argument is a topic. |
| `--check` | Review an existing plan instead of writing one: run the structural check, then do a critical review (see step 6). Doesn't change the plan unless the user agrees. |
| `--split` | If the work is bigger than about 8 tasks or touches unrelated areas, split it into several plans that ship on their own, linked through `from:`. |
| `--type=<t>` | Branch and commit type for `/yay:implement` (default `feat`; `fix` for bugs; `refactor` for no behavior change). |
| `--tests=auto\|none` | `auto` (default; `ask` is accepted as the same): pick the tests yourself, one per risk at the right layer, and ask only if the repo's rules require approval for tests. `none`: write `**Tests:** none` and verify by manual checks. |
| `--edition=<e>` | Which editions the plan touches. Default: inferred from where the code lives. |
| `--commit` | Commit the plan when you're on a non-base branch. |
| `--trello` | Optional. After the plan is written, add its tasks to Trello as a checklist. Off unless given. See step 8. |

## Steps

1. **Source.** Run `yayh artifact resolve <id>` and read it:
   - **Brainstorm:** use its decision. If its `status` isn't `decided`, plan its recommended option, and make "plan option <X>?" a question in step 7's round.
   - **Bug:** use its root cause. If it isn't `root-caused`, suggest `/yay:debug` first.
   - **Design (`UX-<n>`):** plan from the design's own source (its `from:`), and set the plan's `design: UX-<n>`.
   - **Roadmap item:** if there's no brainstorm and the approach isn't obvious, plan the most likely approach, and say in the report that `/yay:brainstorm --from=R-<n>` would compare options.
   - **Open notes:** run `yayh backlog open --for=<source id>` (and `--for=P-<n>` when revising a plan). These are decisions and work an earlier step parked for later. Settle each one now if you can; see "Picking up notes" below.
2. **Ground it.** Read the project block and the relevant `docs/knowledge/` docs. Read **every file the plan will touch**. A plan that names a file you haven't opened is a guess.
3. **Design.**
   - **Goal:** the user-visible outcome and "done means…".
   - **Non-goals.**
   - **Approach:** hooks, storage and option keys, REST, UI, the edition split, compatibility, migration.
   - **Risks** with a rollback.
   - **UI:** when the change adds or changes something people see (an admin screen, tab or modal, a storefront, cart, checkout or My Account element, a block, an email), it follows a design. Use the one that exists (`yayh artifact list design`, or a `UX-<n>` that names this source), else write one now with `/yay:design --quick` (`${CLAUDE_PLUGIN_ROOT}/skills/design/SKILL.md`; the full skill when there are several screens). Set the plan's `design:` with `yayh fm set <plan> design UX-<n>`. A UI that only adds an option to an existing, obvious place needs no design file; give its place, label and default in the Approach.
   - Follow the repo's hard rules and conventions. Cite them where they shape the design.
4. **Tasks.** Number them `T1…Tn`, in the order they'll be built. Each task:
   - is one commit's worth of change that leaves the tree working
   - names its files in backticks (new files marked `(new)`)
   - says what changes, not how to type it
   - has an indented `Reuse:` line naming the existing functions, hooks or settings it will call, with their file (`Reuse: Format::price() in includes/Support/Format.php`). Find them before writing the task: `yayh code find <verb> <noun>`, `docs/knowledge/helpers.md`, and how neighbouring code does the same job. If the task really needs a new function, write `Reuse: none, new <name>() because <why the existing ones don't fit>`. For tasks with no code, write `Reuse: n/a`.
   - optionally ends with a tier tag, `[tier: veryfast]` or `[tier: deep]`, but only when the task is clearly mechanical (a rename, copy, config) or clearly hard. `/yay:implement` then hands it to a subagent on that model (`${CLAUDE_PLUGIN_ROOT}/reference/models.md`). Most tasks have no tag.

   A UI task names the design screen it builds (`UX-<n> "<screen>"`) and reuses the components the design names. Put data and migration first, then server, then UI, then docs. If the work makes a knowledge doc wrong, add a task to update it.
5. **Tests and Verify.**
   - **Tests:** list the risks in the change (acceptance criteria, branches of logic, data written, hooks touched). Give each one the **first layer down the ladder** in `${CLAUDE_PLUGIN_ROOT}/reference/testing.md` that can prove it: unit, integration, js, e2e or manual. Add a second layer only for a second, named risk. Check `yayh test status` and the **Coverage** table in `docs/knowledge/testing.md`: extend an existing test class rather than adding a new one, and mark a layer that isn't set up `(not set up: /yay:test-init)`.
     - Write them on the `**Tests:**` line as `[unit] <test_name> (<file>) — <risk>`, separated by `;`. Use `[integration]`, `[js]` or `[manual]` the same way. Browser-only risks go on the **E2E** line instead.
     - A typical plan has 1–4 tests, mostly unit. Decide this yourself. Only when the repo's rules require approval for tests (the project block or `.claude/rules/`) do they become step 7's question.
   - **E2E** (only when `yayh config get commands.e2e` is set): pick the acceptance criteria that **only a browser can prove**, by the test in `${CLAUDE_PLUGIN_ROOT}/reference/e2e.md` ("When a flow deserves a spec"). Usually that's 0–2: a customer-facing flow, or a JS-rendered admin screen that must save and reload. Read the **Flows** table in `docs/knowledge/e2e.md` first: when the change touches a flow that already has a spec, name that flow (its spec gets extended), and a touched `candidate` row is a strong reason to add it. Write them on the `**E2E:**` line as `<flow>: <the outcome to assert>`, separated by `;`, or write `**E2E:** none`. Decide this yourself; it's not a question.
   - **Verify:** exact checks, each with the command or the UI path, the input, and the result that means it passed. With a design, its **Acceptance** checks go here, and the browser-only ones are candidates for the E2E line. Cover every edition the plan touches. A Verify item covered by a test says its layer: `(unit)`, `(integration)`, `(js)` or `(e2e)`.
6. **Write it.**
   - `yayh artifact new plan "<title>" from=<id> roadmap=<R-n or empty> type=<type>`, then fill in every section.
   - With `--split`, create one plan per shippable slice, each with `from:` pointing at the source.
   - Run `yayh plan check <P-n>` and fix every `error`. Fix the `warn`s too, unless there's a reason not to.
   - Then **self-review** as a skeptical senior reviewer:
     - Is anything missing: uninstall, i18n, capability checks, nonce/escaping, HPOS, block checkout, Free with Pro absent, upgrades from the last release?
     - Is any task too big?
     - Does any task re-implement something that already exists (price or date formatting, settings reads, capability checks, a near-copy of a helper)? Search once more for each new function a task adds.
     - Is the Verify list enough to catch a regression?

   Fix what you find.
7. **Hard questions only** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`). If the user is around and something hard is open, show the task list and ask **one** AskUserQuestion with at most 3 questions, from these:
   - **Tests to include** (multiSelect, with the proposed tests as options), only when the repo's rules say tests need approval (the project block or `.claude/rules/`). Otherwise decide yourself: keep the tests that guard real risk.
   - **The single biggest open decision**, if one remains (the brainstorm option, or a design choice). Your pick comes first.

   Apply the answers. Then, when `yayh plan check` has no errors and no hard decision is still unanswered, mark it ready yourself: `yayh fm set <file> status ready`. Nothing hard open means no question.

   **Park what's still open.** A decision that can't be made now, and isn't worth the question round, becomes a decision note: `yayh artifact new backlog "<the question>" kind=decision from=P-<n> default="<what the plan does for now>" [affects="<other P-/R-ids>"]`. Plan the default, and add the line `Open: BL-<n> <question> (default: …)` under `## Risks`. Work you leave out of scope that someone will want later becomes `kind=deferred from=P-<n>`; name it under **Non-goals** as `BL-<n>`. Neither one stops the plan or keeps it `draft`.
8. **Trello** (only with `--trello`; contract in `${CLAUDE_PLUGIN_ROOT}/reference/trello.md`). Once the plan is written and checked:
   - If its roadmap item has a card (`yayh roadmap get R-<n> trello`), add a checklist `P-<n> <title>` to that card. Otherwise create a card `P-<n> <title>` in `trello.list` (default `To Do`) with the Goal as its description and a `Tasks` checklist.
   - One check item per task, `T<n> <what>`, in order; tasks already ticked are checked.
   - Save the card URL with `yayh fm set <plan> trello <url>`. Revising a plan that has `trello:` updates that checklist instead of adding one.
   - `--check` never syncs. Trello not connected: say so; the plan is unaffected.
9. **Report.** Give the file, the task count, the Tests and E2E lines, any open risks, the notes settled into the plan, the notes written or left open (`BL-<n>`, kind, default), and the next step: `/yay:implement P-<n>`.

### Picking up notes
For each row of `yayh backlog open --for=<id>`:
- **decision:** decide it now if the code, the source artifact, an answer in this round, or work finished since (its `from:` plan is done, the item it waited on shipped) settles it. Write the answer with `yayh backlog settle BL-<n> decided "<answer>"`, then plan the answer instead of the default. If the default was **already built** by a finished plan and the answer differs, the change is a task in this plan when it touches the same code. Otherwise, write a `kind=deferred` note for the change. A decision that still can't be made stays open: plan its default and reference it under `## Risks` as above. A decision only the user can make, that's expensive to get wrong, can be one of step 7's questions.
- **deferred:** if the work fits this plan's goal, add it as tasks and run `yayh backlog settle BL-<n> planned P-<n>`. If it doesn't fit, leave it open, and say so in the report.

A note that's become pointless (the code it named is gone, the item was dropped) is closed with `yayh backlog settle BL-<n> dropped "<why>"`. Settling edits the note's file. Before a branch exists, that's allowed only for an untracked note. A tracked note is settled by `/yay:implement` on the branch, so here write `Settles: BL-<n> decided "<answer>"` (or `planned P-<n>`) under the plan's `## Risks` for it. List every note you settled, or left open, in the report.

### `--check` mode
Run `yayh plan check <plan>`. Then review against the code as it is **now**: do the files still exist, is the approach still valid, and are there tasks the self-review list says are missing? Report blocking issues and suggestions separately. Offer to apply the fixes, but don't edit a plan that's `in-progress` without saying so; changes there must be visible to whoever is implementing it.

## Don'ts
- Don't write code or change anything except the plan file (and, with `--trello`, its Trello card).
- Don't put the same assertion at two layers, or a test at a costlier layer than the ladder picks.
- Don't plan from memory: open the files first.
