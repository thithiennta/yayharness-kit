---
name: test
description: Write, run or triage PHP unit, PHP integration and JS tests for a Yay plugin, choosing the right layer for each risk. Use when the user says "test this", "write a unit test", "add tests for P-4", "regression test for B-7", "run the tests", "why is this test failing". Goes down the ladder (unit, integration, js, e2e, manual), writes tests tagged with the plan or bug they prove, proves they fail without the change, and runs them.
argument-hint: "<P-<n>|B-<n>|<file or Class::method>|\"<behaviour>\"> [--layer=auto|unit|integration|js] [--run[=<layer>]] [--triage] [--commit]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:test

Arguments: `$ARGUMENTS`

Tests at the cheapest layer that proves each risk, tagged with the artifact they prove. The layers, the ladder and the writing rules are in `${CLAUDE_PLUGIN_ROOT}/reference/testing.md`. Read it first; it applies to every test this skill writes.

## Options

| Option | Effect |
|---|---|
| `P-<n>` | Write the tests on the plan's `**Tests:**` line, tagged `P-<n>`. |
| `B-<n>` | Write one regression test at the layer of the bug's root cause, tagged `B-<n>`. It must fail without the fix. |
| `<file>` / `Class::method` | Cover one unit: the risky cases of that code (tag `baseline`). |
| `"<behaviour>"` | A described behaviour: find the code that implements it, then test it. |
| `--layer=<l>` | Force a layer. Default `auto`: the ladder decides. |
| `--run[=<layer>]` | Only run: one layer, or `all` (default). Add `--id=<ID>` to run only that artifact's tests. |
| `--triage` | Run, then classify every failure (step 5) without writing new tests. |
| `--commit` | Commit the tests on the current branch (never the base). `/yay:implement` and `/yay:fix` commit as part of their own flow. |

## Steps

1. **Preflight.** `yayh test status`.
   - If `unit` is `no`, and the ladder will need it, point to `/yay:test-init`. You can still write the test into the plan, marked `(not set up)`.
   - `deps missing` → run `yayh run install`.
   - Integration with the tests site down and Docker running → `yayh e2e env start`.
   - Docker not running → write the integration tests anyway, and mark them **not run**. Never wait.
2. **The risks.**
   - **`P-<n>`:** read the plan's `**Tests:**` line, its Goal, its Approach and its Verify section. Each `[layer]` item is a test.
     - If the line is `none`, apply the ladder to the plan's acceptance criteria. If a risk deserves a test, add it to the plan's `**Tests:**` line first, then write it.
   - **`B-<n>`:** read Root cause and Regression test proposal. Test at the layer where the root cause lives (`reference/testing.md`, "Bugs").
     - If the cause is markup, JS rendering or a click path that only a browser shows, hand over to `/yay:e2e B-<n>`.
   - **A unit or a behaviour:** read the code, its callers and its `git log`. List 2–4 cases (input → expected), each backed by the code, a docblock or history.
   - For each risk, pick the layer by the ladder (or `--layer`). When a risk is browser-only, it goes to `/yay:e2e`, not here.
   - **Existing coverage first:** `yayh test list`, `yayh test list <ID>`, and the **Coverage** table in `docs/knowledge/testing.md`. Extend the existing test class for that unit instead of adding a near-copy.
3. **Write.** Read `TestCase.php` (unit), one existing test from the same layer, and the bootstrap, then write in their style, following `reference/testing.md`:
   - tag every test with its ID
   - one class per unit, mirroring the source path
   - stub only the WordPress calls around the logic
   - assert the outcome the risk names
4. **Run.** `yayh test run <layer> --id=<ID>`. Then:
   - **Regression:** stash the fix (`git stash push -- <fix files>`) and run the test: it must fail. Pop the stash, and it must pass.
   - **New feature test:** it must be able to fail. Run it before the code exists, or break the code with one small change and undo it with `git checkout -- <file>`.
   - **Baseline on existing code:** break the code once, as above. It must fail, and then pass again once the code is restored.
   - Two passing runs in a row is the bar.
5. **Triage** each failure (`--triage`, or any failure in step 4):
   - **Product bug:** the code is wrong, and the evidence says what's right. Report it with the failing assertion and suggest `/yay:debug`. Don't change product code here, and don't weaken the assertion.
   - **Test bug:** a wrong stub, a missing fixture, or state leaking between tests. Fix the test.
   - **Environment:** for example vendor packages missing, the tests site down, or a PHP version mismatch. Fix the environment (`yayh run install`, `yayh e2e env reset`) and re-run once. A pass on the re-run without a change means the test is **flaky**: report it, don't call it green.
6. **Coverage map:** update the unit's row in `docs/knowledge/testing.md`'s **Coverage** table (`tests` = the file and tag), or add a row for a new unit.
7. **Commit** (only with `--commit`): stage the test files, any `TestCase` or bootstrap change, and `docs/knowledge/testing.md`, by path. Commit them as `test: <unit or behaviour>`, with the `Plan: P-<n>` or `Refs: B-<n>` trailer.
8. **Report:**
   - the tests written: file, test names, layer and why that layer
   - each run's result: passed twice, failed and classified, or not run (no Docker)
   - the fail-first evidence
   - anything handed to `/yay:e2e`
   - **Decided:** the layers chosen and the cases picked

## Don'ts
- Don't test at a costlier layer than the ladder picks, and don't assert the same outcome at two layers.
- Don't invent expected values, edit product code, or loosen an assertion to make a test pass.
- Don't add `markTestSkipped`, `.skip` or retries to hide a failure. A skipped test needs a reason and a backlog item.
- Don't run integration tests against the dev site or `site.wpPath`. Use `yayh test run integration`.
