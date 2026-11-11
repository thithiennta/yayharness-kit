---
name: plan
description: Write or review a Yay plugin implementation plan. Use when the user says "plan this", "write a plan", "break this down", "review the plan", before any non-trivial change, or when /yay:fix escalates. Turns a brainstorm, roadmap item, bug or request into docs/plans/ P-<n> with goal, approach, tasks naming their files, an agreed Tests line and exact Verify checks. --check reviews one.
argument-hint: "<topic|BS-<n>|R-<n>|B-<n>|P-<n>> [--from=<id>] [--check] [--split] [--type=feat|fix|chore|refactor|perf] [--tests=ask|none] [--edition=<name>|all] [--commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
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
| `--tests=ask\|none` | `ask` (default): propose tests and ask. `none`: write `**Tests:** none` and verify by manual checks. |
| `--edition=<e>` | Which editions the plan touches. Default: inferred from where the code lives. |
| `--commit` | Commit the plan when you're on a non-base branch. |

## Steps

1. **Source.** Run `yayh artifact resolve <id>` and read it:
   - **Brainstorm:** use its decision. If its `status` isn't `decided`, say so and ask which option to plan, or suggest finishing `/yay:brainstorm` first.
   - **Bug:** use its root cause. If it isn't `root-caused`, suggest `/yay:debug` first.
   - **Roadmap item:** if there's no brainstorm and the approach isn't obvious, suggest `/yay:brainstorm --from=R-<n>`. Continue only if the user wants to.
2. **Ground it.** Read the project block and the relevant `docs/knowledge/` docs. Read **every file the plan will touch**. A plan that names a file you haven't opened is a guess.
3. **Design.**
   - **Goal:** the user-visible outcome and "done means…".
   - **Non-goals.**
   - **Approach:** hooks, storage and option keys, REST, UI, the edition split, compatibility, migration.
   - **Risks** with a rollback.
   - Follow the repo's hard rules and conventions. Cite them where they shape the design.
4. **Tasks.** Number them `T1…Tn`, in the order they'll be built. Each task:
   - is one commit's worth of change that leaves the tree working
   - names its files in backticks (new files marked `(new)`)
   - says what changes, not how to type it

   Put data and migration first, then server, then UI, then docs. If the work makes a knowledge doc wrong, add a task to update it.
5. **Tests and Verify.**
   - **Tests:** with `--tests=ask`, propose each worthwhile test (its name, file, suite, and the risk it guards) in one AskUserQuestion. Write the ones accepted into `**Tests:**`, or `none`. The repo's test policy is in the project block and `.claude/rules/yay-workflow.md`.
   - **Verify:** exact checks, each with the command or the UI path, the input, and the result that means it passed. Cover every edition the plan touches.
6. **Write it.**
   - `yayh artifact new plan "<title>" from=<id> roadmap=<R-n or empty> type=<type>`, then fill in every section.
   - With `--split`, create one plan per shippable slice, each with `from:` pointing at the source.
   - Run `yayh plan check <P-n>` and fix every `error`. Fix the `warn`s too, unless there's a reason not to.
   - Then **self-review** as a skeptical senior reviewer:
     - Is anything missing: uninstall, i18n, capability checks, nonce/escaping, HPOS, block checkout, Free with Pro absent, upgrades from the last release?
     - Is any task too big?
     - Is the Verify list enough to catch a regression?

   Fix what you find.
7. **Ready?** If the user is around, show the plan's task list and ask whether it's ready. On yes, `yayh fm set <file> status ready`. Otherwise leave it `draft`.
8. **Report.** Give the file, the task count, the Tests line, any open risks, and the next step: `/yay:implement P-<n>`.

### `--check` mode
Run `yayh plan check <plan>`. Then review against the code as it is **now**: do the files still exist, is the approach still valid, and are there tasks the self-review list says are missing? Report blocking issues and suggestions separately. Offer to apply the fixes, but don't edit a plan that's `in-progress` without saying so; changes there must be visible to whoever is implementing it.

## Don'ts
- Don't write code or change anything except the plan file.
- Don't add tests the user didn't accept.
- Don't plan from memory: open the files first.
