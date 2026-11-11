---
name: e2e-init
description: Set up end-to-end browser tests for a Yay plugin by scouting the whole plugin first. Use when the user says "init e2e", "set up e2e", "add Playwright", "browser tests", "e2e setup", or a skill reports no commands.e2e; run it again later to map new flows. Maps every surface (admin screens, shortcodes, blocks, My Account, cart and checkout, product pages, emails), writes a flow map, scaffolds or adopts Playwright + wp-env (one site per checkout), seeds the site from what the plugin needs, writes baseline specs for the critical browser-only flows, runs them and opens the PR.
argument-hint: "[--dir=tests/e2e] [--adopt|--fresh] [--depth=quick|full] [--agents=N] [--max-specs=N] [--smoke-only] [--no-ci] [--no-run] [--no-branch] [--no-pr]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:e2e-init

Arguments: `$ARGUMENTS`

Give this repo browser tests that fit the plugin, in one pass: scout every place a user reaches it, write the flow map, set up a seeded wp-env site, and write and pass specs for the flows that matter most. The contract is `${CLAUDE_PLUGIN_ROOT}/reference/e2e.md`. Read it first; its rules apply to every spec written here.

## Options

| Option | Effect |
|---|---|
| `--dir=<path>` | Where the e2e package lives. Default `tests/e2e`. |
| `--adopt` / `--fresh` | Force adopting the existing setup, or scaffold alongside it. Default: adopt when `yayh e2e detect` finds Playwright, otherwise fresh. |
| `--depth=full` (default) | Scout the surface groups in parallel with `yay:e2e-scout` agents. |
| `--depth=quick` | No scouts: read the surfaces yourself. Good for a small plugin (under ~25 surface lines). |
| `--agents=N` | Maximum parallel scouts (default 3, maximum 5). |
| `--max-specs=N` | Baseline spec files to write (default 6). The rest of the flows stay in the map as candidates. |
| `--smoke-only` | Scout and write the flow map, but write only the smoke spec. |
| `--no-ci` | Don't write `.github/workflows/e2e.yml`. |
| `--no-run` | Write everything but don't install, start or run (no Docker needed). Specs are marked **not run**. |
| `--no-branch` | Commit on the current branch instead of creating `test/e2e-init` (never on the base branch). |
| `--no-pr` | Stop after the commit and print the push and PR commands. Default: push and open the PR as `/yay:implement` does. |

## Steps

### 1. Preflight
- `yayh config validate` must pass. If there's no config, stop: `/yay:harness-init` comes first.
- `yayh e2e status` and `yayh e2e detect`. Note the Playwright configs, wp-env files, package scripts and CI workflows that exist.
- **Already set up** (`setup yes`): this is a re-run. Don't scaffold (skip step 5). Read `docs/knowledge/e2e.md`'s **Flows** table and `yayh e2e specs`; steps 2–4 find flows the map doesn't have yet, and steps 6–8 cover only those.
- Branch: on `git.baseBranch`, `git switch -c "$(yayh git branch-name test "e2e init")"` (unless `--no-branch`). The tree must be clean apart from untracked files that aren't yours to commit.

### 2. Map the plugin (always, yourself)
- `yayh e2e surfaces`: every admin page, shortcode, block, REST route, AJAX action, My Account endpoint, Woo settings tab, cart/checkout and product hook, email, gateway, shipping method, widget, meta box and cron job, with `file:line`.
- The project block, `docs/knowledge/` (architecture, settings, front end, `helpers.md`, `known-issues.md`), `yayh config get editions`, `requires` and `generatedPaths`, and the main file's boot code.
- Group the surfaces into **2–5 groups** by who uses them, for example: admin settings screens; storefront (product, cart, checkout classic and block, My Account); blocks and the editor; emails and orders; integrations with other plugins. REST, AJAX and cron lines go with the screen that calls them, not in a group of their own.

### 3. Scout (`--depth=full`)
Spawn one `yay:e2e-scout` per group, **all in one message**, up to `--agents`. Each brief has:
- the group name and its `yayh e2e surfaces` lines
- the repo facts the scout needs: slug, editions, `requires.wc`, PHP floor, generated paths (never read those), and the admin page slug
- the knowledge docs that cover its paths

Wait for every report. Treat it as claims: open the cited lines for every **critical** flow's `outcome` and `locators` yourself before you write a spec from them. With `--depth=quick`, do the scout's job yourself, group by group, in the same report format.

### 4. The flow map
Merge the reports into one list: drop duplicates and join flows that are one user goal. For each flow, decide its coverage, by `reference/e2e.md`'s targeted rule:
- **spec:** browser-only, `critical` first, then `important`, up to `--max-specs` files (one file per flow; a flow's tests can cover two or three outcomes). The first spec is always the plugin's main admin screen saving a setting and keeping it after a reload, when it has one.
- **candidate:** browser-only but over the cap, or `minor`. `/yay:e2e "<flow>"` writes it later.
- **unit:** PHP logic, REST shape, or something `wp` can check. Name the unit test that covers it, or `none yet`.
- **manual:** needs what wp-env can't give (a real payment gateway, an external API without a sandbox, a licence server). Say what.

Edition gates: wp-env runs the source checkout, so Pro code is present. Use the license-free or dev mode the scout found (a `define` in `.wp-env.json`'s `config`, or an option in the seed). If there is none, Pro-only flows become **manual** with that reason. Don't ask about any of this; the code answers it. Use AskUserQuestion only for something that changes which flows get specs and the code can't settle (at most one question), and put the rest under **Decided**.

### 5. Adopt or scaffold
- **Adopt** (an existing Playwright setup):
  - Don't rewrite its files. Map its scripts into `.yay/config.json`: `commands.e2e` (runs Playwright), `e2e-install`, `e2e-start`, `e2e-stop` and `e2e-reset`, plus `e2e.dir`. If it uses a named wp-env config, set `e2e.wpEnvArgs` (e.g. `--config=.wp-env.single.json`).
  - Make the commands run binaries from that folder (`cd <dir> && ./node_modules/.bin/playwright test`), or keep the repo's package-manager script when it wraps the same thing.
  - If its `playwright.config.*` doesn't read `E2E_BASE_URL`, put it first in the base URL fallback (`process.env.E2E_BASE_URL ?? <existing>`). That one-line change is what gives every worktree its own site. List it under **Decided**.
  - If it hard-codes ports in package scripts, leave them; `WP_ENV_PORT` overrides them.
  - Its existing specs count as coverage: put them in the flow map (`yayh e2e specs`) before choosing new ones.
- **Fresh:** `yayh e2e scaffold dir=<dir> [--no-ci]`. It prints `created`, `exists` and `config` lines, never overwrites, and only adds missing config keys.

### 6. Fit the site to the plugin
- **`bin/setup-env.sh`:** the scouts' **Seed candidates** that two or more flows need, under the last comment: settings that must be on, a page with the plugin's shortcode or block, a product of the type the flows use, the license-free mode. Each step must be safe to repeat (`wp post list --name=x --format=ids` before creating). Data only one flow needs goes in that spec's `beforeAll`, not here.
- **`.wp-env.json`:** plugins the flows depend on (by wp.org zip URL), `config` constants the gates need, and the PHP version only if the plugin needs a different one than 8.2.
- **`specs/smoke.spec.ts`:** add one test that the main admin page renders its root element (`page.goto( '/wp-admin/admin.php?page=<slug>' )` plus one cited `getByRole` or `data-*` locator).
- **Packaging:** make sure the zip excludes `<dir>` (`.distignore`, or the package script's excludes). Most already exclude `tests/`. If not, add it.

### 7. Write the baseline specs (skip with `--smoke-only`)
For each **spec** flow, one file `specs/<flow-slug>.spec.ts`, written as `/yay:e2e` step 3 says: import from `../fixtures/test`, tag every test `{ tag: '@flow-<slug>' }`, arrange with `wp()`, act and assert in the browser, use the cited locators, assert the scout's `outcome`, and restore what the spec changed. They describe the behaviour the plugin has today, so they must pass on the current code. Read `fixtures/test.ts`, the seed and the smoke spec before the first one, and reuse a helper in `fixtures/` once two specs need it.

### 8. Run (skip with `--no-run`)
- If the plugin has build output (`generatedPaths`) that isn't there, `yayh run install`, then `yayh run build`.
- `yayh run e2e-install`, `yayh e2e env start`, then `yayh e2e run`. If Docker isn't running (`yayh e2e status`), skip the run, mark every spec **not run**, and say so with the commands to run later. Don't wait for it.
- **Two greens:** run each new spec file twice; both must pass with no retries used.
- **It can fail:** for each spec, break the one precondition it depends on (turn the option off with `yayh e2e cli wp option update …`, delete the seeded product) and run it once: it must fail. Restore with `yayh e2e env reset` or the inverse command. A spec that still passes asserts nothing; fix the assertion.
- **Triage** every failure as `reference/e2e.md` says. A spec bug or seed gap: fix it and re-run. Environment: `yayh e2e env reset`, re-run once; a pass without a change is **flaky** (report it with the trace, it isn't green). A **product bug** (the plugin really does the wrong thing today): `yayh artifact new bug "<title>" severity=<s>`, fill its Repro from the spec, keep the spec and mark that test `test.fail( true, 'B-<n>: <title>' )` so it turns red when the bug is fixed and `/yay:fix B-<n>` removes the mark. Never weaken the assertion.
- Leave the site running.

### 9. Knowledge
Write or update `docs/knowledge/e2e.md` as the `e2e.md` row of `${CLAUDE_PLUGIN_ROOT}/reference/knowledge.md` describes, with front-matter `area: e2e` and `covers: [<dir>/]`:
- how to run it, the seed, the users, the tag convention, the fixtures, the gates and how the site bypasses them, and the traps you hit in step 8
- a **Flows** table, one row per flow from step 4: `| flow | actor | priority | coverage | source |`, where coverage is `specs/<file>` with its tag, `candidate`, `unit: <test or none yet>` or `manual: <why>`, and source is the `path:line` of its entry point. `/yay:plan` and `/yay:e2e` read this table.

Add one line to the project block's **Tests** section in CLAUDE.md ("Browser specs: `yayh e2e run`, flows in docs/knowledge/e2e.md") and a **Read when** line, unless they're there. `yayh knowledge check` must pass; then `yayh knowledge stamp docs/knowledge/e2e.md`.

### 10. Commit and PR
Stage by path (never `git add -A`): `<dir>/` except what its `.gitignore` excludes (it includes the lockfile, which CI needs), `.github/workflows/e2e.yml`, `.yay/config.json`, `docs/knowledge/e2e.md`, `CLAUDE.md`, new bug artifacts, and any packaging fix. One commit: `test(e2e): map flows and add browser tests` (on a re-run, `test(e2e): cover <flows>`), with one body line per spec file. Push and open the PR as in `/yay:implement` (by default; with `--no-pr`, print the commands). The PR body lists the flow map's spec rows with their run result and the bugs found.

### 11. Report
- adopted or scaffolded, and the files
- the flow map in numbers (flows found, spec / candidate / unit / manual), and the spec files with their tags
- each spec's result: passed twice and failed when broken, failed and classified, `test.fail` with its `B-<n>`, or not run (no Docker)
- the site URL and port
- **Decided:** which flows got specs and why, the seed data, the gates and how the site bypasses them, PHP version, CI on or off, the adopt edits, packaging
- the next step: `/yay:e2e "<a candidate>"` for the next flow, `/yay:fix B-<n>` for a bug found. From now on `/yay:plan` marks the flows a change needs, and `/yay:implement` and `/yay:fix` write them.

## Don'ts
- Don't overwrite existing e2e files or hand-tuned `commands.e2e*`. Scaffolding is fill-in-the-gaps only.
- Don't write a spec for a `unit` or `manual` flow, and don't go over `--max-specs`; the map keeps the rest.
- Don't write a locator you haven't read in the code, and don't edit product code here. A bug you find becomes a `B-<n>`.
- Don't point e2e at the developer's real local site (`site.wpPath`). Specs change data. `e2e.baseUrl` is the user's choice, never yours.
