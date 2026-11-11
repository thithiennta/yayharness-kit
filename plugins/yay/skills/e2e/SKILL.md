---
name: e2e
description: Write, run or triage end-to-end browser specs for a Yay plugin. Use when the user says "e2e test this", "write a Playwright test", "add a browser test for P-4", "regression spec for B-7", "run e2e", "why is e2e failing". Writes specs tagged with the plan or bug they prove, runs them against this checkout's wp-env site, and sorts failures into product bug, spec bug or environment.
argument-hint: "<P-<n>|B-<n>|\"<flow>\"> [--run[=<grep>]] [--all] [--triage] [--headed] [--commit]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:e2e

Arguments: `$ARGUMENTS`

Specs that prove what only a browser can prove, tagged with the artifact they prove. Rules for when, how and what are in `${CLAUDE_PLUGIN_ROOT}/reference/e2e.md`. Read them first; they apply to every spec this skill writes.

## Options

| Option | Effect |
|---|---|
| `P-<n>` | Write specs for the plan's `**E2E:**` line, tagged `@P-<n>`. |
| `B-<n>` | Write one regression spec from the bug's repro, tagged `@B-<n>`. It must fail without the fix. |
| `"<flow>"` | Write a spec for a described flow (no artifact; tag it `@flow-<slug>`). |
| `--run[=<grep>]` | Only run: the tagged specs of the given ID, a grep (`--run="@P-4\|@smoke"`), or with no value the smoke spec. |
| `--all` | With `--run`: the whole suite. |
| `--triage` | Run, then classify every failure (step 5) without writing new specs. |
| `--headed` | Pass `--headed` to Playwright (local debugging only). |
| `--commit` | Commit the specs on the current branch (never the base). `/yay:implement` and `/yay:fix` commit as part of their own flow. |

## Steps

1. **Preflight.**
   - `yayh e2e status`. If `setup` is `no`, stop and point to `/yay:e2e-init`.
   - `deps missing` → `yayh run e2e-install`.
   - `env down` with Docker running → `yayh e2e env start`.
   - Docker not running → you can still write specs (steps 2–3), but mark them **not run** in the report. Never wait.
2. **What to prove.**
   - **`P-<n>`:** read the plan's `**E2E:**` line and its Goal and Verify sections. Each item on the E2E line becomes a test. If the line is `none`, say so and stop, unless the user named a flow: then add it to the plan's E2E line first.
   - **`B-<n>`:** read Repro and Root cause. One test that walks the repro and asserts the correct behaviour. If a unit test can cover it (the cause is pure PHP logic), say so and stop: that belongs to `/yay:fix`'s regression test.
   - **`"<flow>"`:** the outcome the user described, at one level of detail: one spec file, one to three tests.
   - Check existing coverage first: the **Flows** table in `docs/knowledge/e2e.md`, `yayh e2e specs` and `yayh e2e specs <ID>`. Extend the flow's existing file instead of adding a near-copy. For a `"<flow>"` that is a `candidate` row, use its slug, locators source and `needs`.
3. **Write.** Read `fixtures/test.ts`, `bin/setup-env.sh` and one existing spec, then write in their style, following `reference/e2e.md`'s rules:
   - tag every test with `{ tag: '@<ID>' }`
   - arrange with `wp()`, act and assert in the browser, clean up what you changed
   - use role, label and text locators, with no sleeps
   - assert the outcome the criterion names

   Read the plugin's templates and JS for the real labels, roles and `data-*` hooks. A spec written from guessed markup fails for the wrong reason.
4. **Run** what you wrote or what `--run` named: `yayh e2e run --grep "@<ID>"` (add `--headed` if asked). Then:
   - **New feature spec:** it must be able to fail. If you're on a feature branch, reason about why it fails on the base, or run it there in a temporary detached worktree when that's cheap.
   - **Regression spec:** run it with the fix stashed (`git stash push -- <fix files>`): it must fail. Then pop the stash and run again: it must pass.
   - Re-run a passing new spec once more. Two greens in a row, with no retries used, is the bar.
5. **Triage** each failure (`--triage`, or any failure in step 4). Read the error, the screenshot and trace in `<e2e.dir>/test-results/`, and `yayh e2e cli tail -n 100 wp-content/debug.log`. Then classify it:
   - **Product bug:** report it with the evidence and suggest `/yay:debug`. Don't change product code here. Don't weaken the assertion.
   - **Spec bug:** fix the spec and re-run.
   - **Environment:** `yayh e2e env reset` and re-run once. Passing on the re-run without a change means **flaky**. Report it with the trace; it isn't green.
6. **Flow map:** update the flow's row in `docs/knowledge/e2e.md`'s **Flows** table (coverage `specs/<file>` with the tag), or add a row for a new flow, so `/yay:plan` sees it.
7. **Commit** (only with `--commit`): stage the spec files, `docs/knowledge/e2e.md`, and any fixture or seed change by path. Commit them as `test(e2e): <flow>` with the `Plan: P-<n>` or `Refs: B-<n>` trailer. Never commit on the base branch.
8. **Report:**
   - the specs written: file, test titles and tags
   - each run with its result: passed twice, failed and classified, or not run (no Docker)
   - the fail-first evidence for regression specs
   - flaky tests, with their trace paths
   - **Decided:** any choice the plan didn't pin down (which flow got a spec, the seed data you added)

## Don'ts
- Don't write a spec for something a unit test or `wp` can check (see "When a flow deserves a spec").
- Don't edit product code, and never loosen an assertion to make a spec pass.
- Don't add `waitForTimeout`, retries, or `test.skip` to hide a failure. A skipped test needs a reason and a backlog item.
- Don't run e2e against `site.wpPath` or `site.url`. Specs change data.
