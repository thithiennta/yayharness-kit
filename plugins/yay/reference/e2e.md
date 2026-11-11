# E2E: browser tests for Yay plugins

Playwright against a throwaway WordPress site that wp-env runs in Docker, from `tests/e2e/` (`e2e.dir`). `/yay:e2e-init` scouts the plugin's flows and creates or adopts it, `/yay:e2e` writes and runs specs, and `/yay:plan`, `/yay:implement`, `/yay:fix` and `/yay:release` use it **in a targeted way**: specs only for what only a browser can prove.

## The setup

| Piece | Where | Owner |
|---|---|---|
| `commands.e2e`, `e2e-install`, `e2e-start`, `e2e-stop`, `e2e-reset` | `.yay/config.json` | team (written once by `yayh e2e scaffold`) |
| `e2e.dir` (default `tests/e2e`), optional `e2e.port`, `e2e.baseUrl`, `e2e.wpEnvArgs` | `.yay/config.json` / `.yay/local.json` | team / developer |
| `package.json`, `playwright.config.ts`, `.wp-env.json`, `bin/setup-env.sh`, `fixtures/`, `specs/` | `tests/e2e/` | team (seeded once, never re-synced by the kit) |
| `.github/workflows/e2e.yml` | repo | team (seeded once) |

- **One site per checkout.** The main checkout uses the plugin's base port (8900–9890, derived from the slug, so CI and every developer agree; `e2e.port` overrides). Each worktree gets its own port (10000–13998, from its path), so parallel branches never share a database. `yayh` exports `WP_ENV_PORT`, `WP_ENV_TESTS_PORT` and `E2E_BASE_URL` for every e2e command; `playwright.config.ts` reads `E2E_BASE_URL`. Never hard-code a port or URL in a spec.
- **Always through `yayh`:** `yayh e2e env start|stop|reset`, `yayh e2e run [playwright args]`, `yayh e2e cli <cmd>`. Running `npx wp-env` by hand in a worktree starts it on the main checkout's port.
- **The site runs the source checkout**, mapped as `wp-content/plugins/<slug>`: all editions' code, with whatever is built. Run `yayh run install` and `yayh run build` first when the plugin has build output (`generatedPaths`). Testing the packaged zip is `/yay:release`'s UI check (`yayh release ui`), which runs the built zip in its own wp-env site, never this one.
- **Seed data lives in `bin/setup-env.sh`**, which runs after every start and reset, so every step must be safe to repeat (`wp user get x || wp user create …`). Data one spec needs goes in that spec (`wp()` in `beforeAll`), not in the seed.
- **`e2e.baseUrl`** points the specs at an external site (Local, branchpress) instead of wp-env. yayh then doesn't start, stop or reset anything, and `wp()` doesn't work; use it only for a one-off check.
- **Docker is required.** When `yayh e2e status` says Docker isn't running, write the specs anyway, mark them *not run*, and say so in the report or PR. Never block on it.

## The flow map

`docs/knowledge/e2e.md` has a **Flows** table: every user flow `/yay:e2e-init` found (from `yayh e2e surfaces` and the `yay:e2e-scout` reports), with its actor, priority (`critical`: money, checkout, data loss or the plugin's main promise; `important`; `minor`), coverage and entry point. Coverage is one of `specs/<file>` with its `@flow-<slug>` tag, `candidate` (browser-only, no spec yet), `unit: <test>` or `manual: <why>`. `/yay:e2e` updates a row when it writes a spec; `/yay:plan` reads the table to see which spec a change touches. Re-running `/yay:e2e-init` adds the flows that are new since.

A baseline spec describes behaviour the plugin has today, so it must pass on the current code, and it must fail when its one precondition is broken (an option turned off, the product deleted). A product bug found by a baseline spec becomes a `B-<n>` artifact and the test is marked `test.fail( true, 'B-<n>: …' )`, which `/yay:fix B-<n>` removes.

## When a flow deserves a spec (targeted)

E2E is the fourth rung of the ladder in `testing.md`. Check the cheaper layers first.

A spec costs minutes per run and breaks on markup changes. Write one only when the acceptance criterion **can only be proved in a browser**, and a unit test can't cover it:
- what a customer sees or does: cart, checkout (classic and block), My Account, product page, emails rendered from a front-end action
- an admin screen rendered by JS (React settings, the block editor), where saving and reloading must keep the value
- the plugin working with WooCommerce or theme markup it doesn't control
- a bug whose repro is a click path, after `/yay:debug` found the cause

Not for: pure PHP logic (unit test), REST shape (unit or integration test), copy changes, or anything `wp` CLI can check. Usually 0–2 specs per plan, and at most one per bug.

## Writing specs

- **One file per user flow** in `specs/`, named for the flow: `specs/my-account-menu.spec.ts`. Extend the existing file for that flow instead of adding a second one.
- **Tag every test with the artifact it proves:** `test( 'shows the Rewards tab', { tag: '@P-4' }, … )`, or `@B-7` for a regression. `yayh e2e specs P-4` finds them, and `yayh e2e run --grep @P-4` runs them. Keep the smoke spec tagged `@smoke`.
- **Import from `../fixtures/test`**, not `@playwright/test`: `test`, `expect`, `wp()` (WP-CLI in the site) and the `customerPage` fixture. Admin is the default storage state.
- **Arrange with `wp()`, act and assert in the browser.** Set options, create products and users through `wp( 'option', 'update', … )` or `wp( 'wc', 'product', 'create', …, '--user=admin' )`, never by clicking through admin screens you're not testing. Restore what you changed in `afterAll`/`afterEach`, because specs share one site.
- **Locators a user would use:** `getByRole`, `getByLabel`, `getByText`, with `exact` when needed. Then the plugin's own stable hooks (`data-*`, ids it renders). Never CSS paths through theme or WooCommerce markup, and never `nth()` without a reason.
- **No sleeps.** `await expect( locator ).toBeVisible()` and the other web-first assertions wait for you. No `waitForTimeout`.
- **Assert the outcome the criterion names** (the menu item is there, the total is 9.00, the setting survives a reload), not just that a page loaded.
- **Code rules still apply** (`code-rules.md`): reuse the fixtures and helpers in `fixtures/`, add a helper there only when two specs need it, and no comments that narrate the steps (`test.step( 'save the settings', … )` names a step better than a comment).

## Running and triage

- Targeted: `yayh e2e run --grep "@P-4|@smoke"`. Full suite: `yayh e2e run`. One file: `yayh e2e run specs/x.spec.ts`. Debugging: `--headed`, `--debug`, `--trace on`.
- **A failure is one of three things.** Find out which before changing anything:
  - **Product bug:** the plugin does the wrong thing (debug.log: `yayh e2e cli tail -n 100 wp-content/debug.log`, the screenshot, the trace in `test-results/`). It goes to `/yay:debug` with the evidence. Never weaken the assertion to make it pass.
  - **Spec bug:** a wrong locator, missing arrange step, or leftover state from another spec. Fix the spec.
  - **Environment:** the site is down, a port is taken, the seed failed, Docker is out of memory. `yayh e2e env reset`, then re-run once. Passing on a re-run without a change means it's **flaky**: say so, with the trace, and don't call it green.
- A spec written for a new feature must fail on the base branch or without the change, at least once, by reasoning or by running it. A spec that can't fail proves nothing.
