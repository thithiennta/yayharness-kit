---
name: plan
description: Write or review a Yay plugin implementation plan. Use when the user says "plan this", "write a plan", "break this down", "review the plan", before any non-trivial change, or when /yay:fix escalates. Turns a decided brainstorm, roadmap item, bug or request into docs/plans/ P-<n>: ordered tasks naming their files, sizes and dependencies, and Verify checks. --check reviews one.
argument-hint: "<topic|BS-<n>|R-<n>|B-<n>|UX-<n>|P-<n>> [--from=<id>] [--check] [--split] [--type=feat|fix|chore|refactor|perf] [--edition=<name>|all] [--commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# /yay:plan

Arguments: `$ARGUMENTS`

Converge: turn a chosen direction into work someone can follow without deciding anything new. Exactly what, where, in what order, and how we know it's done. Format: `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Plan). Writes only the plan file, or edits one that isn't `in-progress` yet.

## Options

| Option | Effect |
|---|---|
| `<topic\|id>` | A topic, or the source: `BS-<n>`, `R-<n>`, `B-<n>`, `UX-<n>`, or `P-<n>` to revise. |
| `--from=<id>` | The source, when the first argument is a topic. |
| `--check` | Review an existing plan instead (see below). |
| `--split` | Over about 8 tasks, or unrelated areas: one plan per shippable slice. |
| `--type=<t>` | Branch type for `/yay:implement` (default `feat`; `fix` for bugs). |
| `--edition=<e>` | Editions it touches. Default: from where the code lives. |
| `--commit` | Commit the plan on a non-base branch. |

## Steps

1. **Source.** Run `yayh artifact resolve <id>` and read it.
   - **Brainstorm:** build its decision. Not `decided`: ask its pick in one AskUserQuestion (its Direction first, "(Recommended)"), then `yayh fm set <brainstorm> decision "<name>"` and `status decided`. With "don't ask", plan its Direction and say so.
   - **Bug:** build its root cause; not `root-caused` yet, suggest `/yay:debug`.
   - **Design (`UX-<n>`):** plan from its source, set `design: UX-<n>`; UI tasks build its screens.
   - **Roadmap item or request with no brainstorm:** one sensible way: plan it. Two or more really different ways (hook, storage, UI place, edition split): stop and suggest `/yay:brainstorm --from=<id>`.
   - **Acceptance:** a roadmap item's `acceptance` and brief (`yayh brief path R-<n>`, `${CLAUDE_PLUGIN_ROOT}/reference/briefs.md`) are what done means: the Goal states it, and **every Done when check becomes a Verify check**.
   - **Screenshots:** evidence; keep them as `artifacts.md` (Screenshots) says.
   - **Open notes** (`yayh backlog open --for=<source id>`, and `P-<n>` when revising): settle a decision the code or finished work answers (`yayh backlog settle BL-<n> decided "<answer>"`) and plan it, else plan its default; take deferred work that fits as tasks (`settle BL-<n> planned P-<n>`). For a tracked note, write `Settles: BL-<n> …` under Risks: `/yay:implement` settles it.
2. **Read the code:** the project block, the knowledge docs it touches, and **every file the tasks will name**. Name the existing helpers the work should call (`yayh code find <verb> <noun>`, `docs/knowledge/helpers.md`) in the task text.
3. **Tasks.** `T1…Tn` in build order (data, server, UI, docs). Each task:
   - is one working commit: what changes, its files in backticks, new ones `(new)`
   - ends with `[size: S|M|L]`, and `[after: T<n>]` when it needs a task that isn't the one before
   - ends with `[risk: 3]` when it's hard to undo (stores or deletes data, runs in the background, emails customers, touches money, personal data or permissions), `[risk: 1]` for copy or docs
   - may end with `[tier: veryfast]` or `[tier: deep]` when clearly mechanical or hard (`${CLAUDE_PLUGIN_ROOT}/reference/models.md`)

   A knowledge doc the change makes wrong gets a task.
4. **Verify: the acceptance criteria.** Each check gives the action and the result that passes, across every edition touched.
   - A check a command can make is written ``- `<command>` → <expected>``, which `yayh verify P-<n> --run` runs (recipes: `${CLAUDE_PLUGIN_ROOT}/reference/testing.md`, "Verify checks"). One that writes data cleans up.
   - A check a test should keep guarding ends with its layer: `(unit)`, `(integration)`, `(js)`, or `(e2e)` for what only a browser proves (`${CLAUDE_PLUGIN_ROOT}/reference/e2e.md`, when `commands.e2e` is set): the cheapest layer on `testing.md`'s ladder, one per real risk, usually 1-4.
   - Each risk-3 task gets a command or test-layer check; a command check never ends in a layer.
   - Add the applying checks from `docs/knowledge/conventions.md`.
5. **Self-check.** Can it be built without a new decision? Check uninstall, i18n, capabilities, nonces and escaping, HPOS, block checkout, Free without Pro, upgrades. An open decision goes back to step 1, or is parked (step 6).
6. **Write it.**
   - `yayh artifact new plan "<title>" from=<id> roadmap=<R-n or empty> type=<type>`: fill in Goal, Tasks, Verify and Risks (with the rollback).
   - Run `yayh plan check <P-n>` and fix every `error` and `warn`. Then `yayh fm set <file> status ready`.
   - **Park what's open:** a small decision becomes `yayh artifact new backlog "<question>" kind=decision from=P-<n> default="<what the plan does>"` (and `Open: BL-<n> …` under Risks); later work, `kind=deferred`.
7. **Report.** The file, the tasks with their sizes, the data changes in plain words (each option, meta key, table or column added, changed or removed, its default, what happens to existing sites and on uninstall; or "Data changes: none"), the test-layer checks, the open risks, the notes, and the **Next** line (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`), usually `/yay:implement P-<n>`.

### `--check` mode
Run `yayh plan check <plan>`, then review against the code now: do the files exist, can each task be built without a new decision, does Verify prove the Goal? Report blockers and suggestions apart, and offer fixes.

## Don'ts
- Don't choose between approaches (that's `/yay:brainstorm`) or write code.
