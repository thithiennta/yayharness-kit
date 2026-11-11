---
name: test-init
description: Set up PHP unit, PHP integration and JS unit tests for a Yay plugin, scouting the code first. Use when the user says "set up unit tests", "add PHPUnit", "init tests", "test setup", "add Jest/Vitest", or a skill reports no commands.test-unit; run it again later to cover new risky code. Scaffolds or adopts PHPUnit + Brain Monkey, the WordPress/WooCommerce test suite in wp-env's tests site, and the JS runner, installs the dev packages, writes baseline tests for the riskiest units at the right layer, runs them, maps coverage, and opens the PR.
argument-hint: "[--php=tests/php] [--js=tests/js] [--js-runner=vitest|jest|wp-scripts|none] [--no-integration] [--adopt|--fresh] [--depth=quick|full] [--agents=N] [--max-tests=N] [--no-ci] [--no-run] [--no-branch] [--no-pr]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:test-init

Arguments: `$ARGUMENTS`

Give this repo the unit, integration and JS test layers in one pass, with real tests on the code that matters most. The contract is `${CLAUDE_PLUGIN_ROOT}/reference/testing.md`: the layers, the ladder for choosing one, and the writing rules. Read it first. Browser specs are `/yay:e2e-init`'s job.

## Options

| Option | Effect |
|---|---|
| `--php=<dir>` / `--js=<dir>` | Where the PHP and JS tests live. Default `tests/php` and `tests/js`. |
| `--js-runner=<r>` | `vitest`, `jest`, `wp-scripts` or `none`. Default: the runner `package.json` already uses, otherwise Vitest when there is JS source, otherwise none. |
| `--no-integration` | Skip the integration layer (no Docker, no wp-env tests site). |
| `--adopt` / `--fresh` | Force adopting the existing PHPUnit/JS setup, or scaffolding alongside it. Default: adopt when `yayh test detect` finds a phpunit config or a JS runner with tests. |
| `--depth=full` (default) / `quick` | Scout the areas in parallel with `yay:test-scout` agents, or read them yourself (fine for a small plugin). |
| `--agents=N` | Maximum parallel scouts (default 3, maximum 5). |
| `--max-tests=N` | Baseline test classes or files to write (default 8, across all layers). |
| `--no-ci` | Don't write `.github/workflows/tests.yml`. |
| `--no-run` | Write everything, but don't install packages or run anything. Tests are marked **not run**. |
| `--no-branch` | Commit on the current branch instead of creating `test/test-init` (never on the base branch). |
| `--no-pr` | Stop after the commit and print the push and PR commands. |

## Steps

### 1. Preflight
- `yayh config validate` must pass. If there is no config, stop: `/yay:harness-init` comes first.
- `yayh test status` and `yayh test detect`. Note the phpunit configs, the Composer dev packages (Brain Monkey, WP_Mock, wp-phpunit), existing `*Test.php` dirs, the JS runner, test scripts and CI.
- **Already set up** (`unit yes`): this is a re-run. Skip steps 4–5 and read `docs/knowledge/testing.md`'s **Coverage** table and `yayh test list`. Steps 2–3 find risky units the table doesn't cover yet, and steps 6–7 cover only those.
- Branch: if you're on `git.baseBranch`, run `git switch -c "$(yayh git branch-name test "test init")"` (unless `--no-branch`). The tree must be clean, apart from untracked files that aren't yours to commit.

### 2. Map the code (always, yourself)
- `yayh code index`, `docs/knowledge/helpers.md`, `architecture.md` and `known-issues.md`, the project block, and `yayh config get editions`, `requires` and `generatedPaths`.
- `git log --oneline --grep='fix' -60`: files with bug-fix history are where regressions come back.
- Split the code into **2–5 areas** by what it does: rules and pricing, settings and storage, REST and AJAX, WooCommerce integration, admin JS, storefront JS. Leave out generated paths, `vendor/`, and tests.

### 3. Scout (`--depth=full`)
Spawn one `yay:test-scout` per area, **all in one message**, up to `--agents`. Each brief has the area's paths, the repo facts (editions, PHP floor, `requires.wc`, generated paths), and the knowledge docs covering it.

Wait for every report. Treat the reports as claims: before you write a test, open the cited lines of every `critical` unit's `cases`. An expected value you can't confirm becomes an open question, not a test. With `--depth=quick`, do the scout's job yourself, area by area.

### 4. Adopt or scaffold
- **Adopt** (an existing setup):
  - Don't rewrite its files. Map its commands into `.yay/config.json`: `commands.test-unit` (the phpunit run without WordPress), `test-integration` (with the WordPress test suite), `test-js`, and `test`, plus the `tests.*` dirs.
  - An integration suite that runs against a local MySQL or `bin/install-wp-tests.sh` stays as it is. Map it, and list it under **Decided**.
  - An existing WP_Mock setup counts as the unit layer; don't add Brain Monkey alongside it.
- **Fresh:** `yayh test scaffold php=<dir> js=<dir> [js-runner=<r>] [--no-integration] [--no-ci]`. It prints `created`/`exists`/`updated`/`config` lines, never overwrites, and only adds missing config keys. For integration, it turns on wp-env's tests site in `<e2e.dir>/.wp-env.json`, and creates the e2e package if there isn't one.
- Install what its `deps` lines name (skip with `--no-run`). That's `composer require --dev …` for PHP, and the package manager's add command for JS. If `composer.json` has no autoload for the plugin's classes, don't add one; the tests `require_once` what they need.
- **Packaging:** check that the release zip is built with `composer install --no-dev` (commands.package, the build script, or the `.distignore`). If it isn't, fix it, because PHPUnit must never ship. Also check that `tests/` is excluded, as it usually already is. List the change under **Decided**.

### 5. Prove the setup
- `yayh test run unit`: the scaffold's `PluginHeaderTest` must pass.
- If integration is on and Docker is running: `yayh e2e env start` (it starts both sites), then `yayh test run integration`. `PluginLoadsTest` must pass; with WooCommerce, it saves a product. Without Docker, mark it **not run** and keep going.
- `yayh test run js` runs once the first JS test exists (step 6).
- Fix any setup failure before writing more tests. It's usually autoload, a missing `ABSPATH` guard, or the main file needing a build. Write the fix down for step 8's traps.

### 6. Write the baseline tests
Pick the units from step 3 by priority (`critical` first, then `important`), up to `--max-tests` test classes or files, at the layer each scout picked by the ladder. Keep them mostly unit; integration only where the risk really is WordPress or WooCommerce.
- Follow `reference/testing.md`'s writing rules: one class per unit, mirroring its path; `snake_case` behaviour names; 2–4 cases from the scout's cited `cases`; stub only the WordPress calls around the logic; add a shared stub or factory to `TestCase` or the bootstrap only when two tests need it.
- Tag the baseline tests `@group baseline` (PHP) or `@baseline` (JS). They describe today's behaviour, so they must pass on the current code.

### 7. Run and prove they can fail (skip with `--no-run`)
- Run each layer twice: `yayh test run unit`, `yayh test run js`, and `yayh test run integration` when its site is up. Both runs must pass.
- **It can fail:** for each test class, break the code it guards with one small change (flip a comparison, return early, change a constant) and run that class: it must fail. Then undo the change with `git checkout -- <file>`. A test that still passes asserts nothing, so fix the test.
- **Product bug** (the code really is wrong today, and the scout's evidence says what's right): run `yayh artifact new bug "<title>" severity=<s>` and fill in its Repro from the test. Keep the test, but mark it as expected to fail:
  - PHP: `$this->markTestIncomplete( 'B-<n>: <title>' )` at the top, followed by the real assertions.
  - JS: `test.fails( … )` in Vitest, or `test.failing( … )` in Jest.

  `/yay:fix B-<n>` removes the mark. Never change the expected value to match the bug.

### 8. Knowledge
Write or update `docs/knowledge/testing.md` as the `testing.md` row of `${CLAUDE_PLUGIN_ROOT}/reference/knowledge.md` describes, with the front-matter `area: testing` and `covers` set to the test dirs:
- How to run each layer, the bootstraps, the shared stubs and factories, the gates (edition or license checks) and how tests get past them, and the traps from steps 5 and 7.
- A **Coverage** table, one row per unit from step 3: `| unit | layer | priority | tests | source |`. In `tests`, put the test file with its tag, `candidate` (not written yet), or `bug: B-<n>`. `/yay:plan` and `/yay:test` read this table.

Add the commands to the project block's **Tests** section in CLAUDE.md (`yayh test run all`; integration needs Docker), and a **Read when** line. `yayh knowledge check` must pass. Then run `yayh knowledge stamp docs/knowledge/testing.md`.

### 9. Commit and PR
Stage by path (never `git add -A`):
- the test dirs
- `phpunit`/JS config files
- `composer.json` and `composer.lock`
- `package.json` and the lockfile
- `<e2e.dir>/.wp-env.json` (and the e2e package, if the scaffold created it)
- `.github/workflows/tests.yml`
- `.yay/config.json`
- `docs/knowledge/testing.md` and `CLAUDE.md`
- new bug artifacts
- the packaging fix

Commit once: `test: set up unit, integration and JS tests` (on a re-run, `test: cover <units>`), with one body line per test file. Push and open the PR as `/yay:implement` does, by default; with `--no-pr`, print the commands instead. The PR body lists the layers, the tests with their results, and any bugs found.

### 10. Report
- which layers were adopted or scaffolded, and the files
- the packages added
- the coverage map in numbers (units found; tested per layer; candidates; bugs)
- each layer's result: passed twice and failed when broken, `markTestIncomplete`/`fails` with its `B-<n>`, or not run (no Docker)
- **Decided:** which units got tests and at which layer, the JS runner, integration on or off, the adopt mappings, the packaging fix
- next steps:
  - `/yay:test "<a candidate>"` for more tests
  - `/yay:fix B-<n>` for a bug found
  - `/yay:e2e-init` if browser tests aren't set up

  From now on, `/yay:plan` picks the layer for each risk, and `/yay:implement` and `/yay:fix` write those tests.

## Don'ts
- Don't overwrite existing test files, configs or hand-tuned `commands.test*`.
- Don't invent expected values. Every case is backed by code, docs or history, or it becomes an open question.
- Don't write tests for trivial getters or glue, and don't go over `--max-tests`; the Coverage table keeps the rest.
- Don't run integration tests in the dev site (`cli`): the WordPress test suite wipes its tables. Use `yayh test run integration` (`tests-cli`).
- Don't edit product code here. A bug you find becomes a `B-<n>`.
