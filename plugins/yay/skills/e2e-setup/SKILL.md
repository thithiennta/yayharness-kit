---
name: e2e-setup
description: Set up end-to-end browser tests for a Yay plugin (Playwright + wp-env in Docker, one site per checkout). Use when the user says "set up e2e", "add Playwright", "browser tests", "e2e setup", or a skill reports no commands.e2e. Scaffolds tests/e2e, seeds the site, writes the e2e config and CI workflow, runs the smoke spec, or adopts an existing Playwright/wp-env setup.
argument-hint: "[--dir=tests/e2e] [--adopt|--fresh] [--no-ci] [--no-run] [--no-branch]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# /yay:e2e-setup

Arguments: `$ARGUMENTS`

Give this repo working browser tests in one pass: a seeded wp-env site, a passing smoke spec, and the config the other skills use. The contract is `${CLAUDE_PLUGIN_ROOT}/reference/e2e.md`. Read it first.

## Options

| Option | Effect |
|---|---|
| `--dir=<path>` | Where the e2e package lives. Default `tests/e2e`. |
| `--adopt` / `--fresh` | Force adopting the existing setup, or scaffold alongside it. Default: adopt when `yayh e2e detect` finds Playwright, otherwise fresh. |
| `--no-ci` | Don't write `.github/workflows/e2e.yml`. |
| `--no-run` | Write everything but don't install, start or run (no Docker needed). |
| `--no-branch` | Commit on the current branch instead of creating `test/e2e-setup` (never on the base branch). |

## Steps

1. **Preflight.**
   - `yayh config validate` must pass. If there's no config, stop: `/yay:harness-init` comes first.
   - `yayh e2e status`. If `setup` is already `yes`, don't scaffold again. Skip to step 5 (run) to check that it still works, and report.
   - `yayh e2e detect`. Note what exists: Playwright configs, wp-env files, package scripts and CI workflows.
   - Branch: if you're on `git.baseBranch`, `git switch -c "$(yayh git branch-name test "e2e setup")"` (unless `--no-branch`). The tree must be clean apart from untracked files that aren't yours to commit.
2. **Learn the flows.** Read the project block, `docs/knowledge/` (especially the architecture, settings and front-end docs) and the main file. Write down, for step 4, what the plugin needs on a fresh site: WooCommerce or not, required settings or a license-free mode, pages or shortcodes, products of a certain type, the admin page slug. Don't ask about any of this; the code answers it.
3. **Adopt or scaffold.**
   - **Adopt** (an existing Playwright setup):
     - Don't rewrite its files. Map its scripts into `.yay/config.json`: `commands.e2e` (runs Playwright), `e2e-install`, `e2e-start`, `e2e-stop` and `e2e-reset`, plus `e2e.dir`. If it uses a named wp-env config, set `e2e.wpEnvArgs` (e.g. `--config=.wp-env.single.json`).
     - Make the commands run binaries from that folder (`cd <dir> && ./node_modules/.bin/playwright test`), or keep the repo's package-manager script when it wraps the same thing.
     - If its `playwright.config.*` doesn't read `E2E_BASE_URL`, put it first in the base URL fallback (`process.env.E2E_BASE_URL ?? <existing>`). That one-line change is what gives every worktree its own site. List it under **Decided**.
     - If it hard-codes ports in package scripts, leave them; `WP_ENV_PORT` overrides them.
   - **Fresh:** `yayh e2e scaffold dir=<dir> [--no-ci]`. It prints `created`, `exists` and `config` lines, never overwrites, and only adds missing config keys.
4. **Fit the starter to this plugin.** Edit only what step 2 showed is needed:
   - `bin/setup-env.sh`: the plugin's seed data under the last comment (settings that must be on, a page with its shortcode, a product type). Each step must be repeatable.
   - `.wp-env.json`: extra plugins the plugin depends on (by wp.org zip URL), and the PHP version only if the plugin needs a different one than 8.2.
   - `specs/smoke.spec.ts`: add one test that the plugin's main admin page renders its root element (`page.goto( '/wp-admin/admin.php?page=<slug>' )` plus one `getByRole` or `data-*` locator). Nothing else; real specs come from `/yay:e2e`.
   - Packaging: make sure the zip excludes `<dir>` (`.distignore`, or the package script's excludes). Most already exclude `tests/`. If not, add it.
5. **Run it** (skip with `--no-run`).
   - If the plugin has build output (`generatedPaths`) that isn't there, run `yayh run install` and then `yayh run build`.
   - `yayh run e2e-install`, then `yayh e2e env start`, then `yayh e2e run`.
   - If Docker isn't running (`yayh e2e status`), skip the run, and say so in the report with the commands to run later. Don't wait for it.
   - If a smoke test fails, triage it as `reference/e2e.md` says. A seed or activation failure is usually step 4's data or a missing build; fix it and re-run. A failure that is a real product bug (a fatal on activation) goes in the report with the debug.log lines. Don't hide it.
   - Leave the site running and report its URL.
6. **Knowledge.** Write `docs/knowledge/e2e.md` as the `e2e.md` row of `${CLAUDE_PLUGIN_ROOT}/reference/knowledge.md` describes: how to run it, the seed, the users, the tags, the fixtures, and the traps you hit in step 5. Use the front-matter `area: e2e` and `covers: [<dir>/]`. Add one line to the project block's **Tests** section in CLAUDE.md ("Browser specs: `yayh e2e run`, see docs/knowledge/e2e.md") and a **Read when** line. Then `yayh knowledge check` must pass, and you run `yayh knowledge stamp docs/knowledge/e2e.md`.
7. **Commit**, staging by path (never `git add -A`): `<dir>/` except what its `.gitignore` excludes (it includes the lockfile, which CI needs), `.github/workflows/e2e.yml`, `.yay/config.json`, `docs/knowledge/e2e.md`, `CLAUDE.md`, and any packaging fix.
   `test(e2e): set up Playwright and wp-env browser tests`. Push and open the PR as in `/yay:implement` (by default; with `--no-pr`, print the commands).
8. **Report:**
   - adopted or scaffolded, and the files
   - the smoke result (passed, failed with the cause, or not run because there was no Docker)
   - the site URL and port
   - **Decided:** the choices you made: seed data, PHP version, CI on or off, the adopt edits, packaging
   - the next step: `/yay:e2e "<a flow>"` for the first real spec. From now on `/yay:plan` marks the flows that need a spec, and `/yay:implement` and `/yay:fix` write them.

## Don'ts
- Don't overwrite existing e2e files or hand-tuned `commands.e2e*`. Scaffolding is fill-in-the-gaps only.
- Don't write feature specs here. One smoke spec proves the setup, and the rest is `/yay:e2e`.
- Don't point e2e at the developer's real local site (`site.wpPath`). Specs change data. `e2e.baseUrl` is the user's choice, never yours.
