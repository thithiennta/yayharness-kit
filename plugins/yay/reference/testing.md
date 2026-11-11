# Testing: which layer proves what

Four automated layers, plus a manual check when none of them fits. `/yay:test-init` sets up the first three, and `/yay:e2e-init` sets up the fourth. For each task, `/yay:plan`, `/yay:implement`, `/yay:fix` and `/yay:test` decide which layer each risk gets. **The agent decides; it doesn't ask**, unless the repo's own rules say tests need approval.

| Layer | Runs | Cost | Lives in | Tag | Run |
|---|---|---|---|---|---|
| **unit** | PHPUnit + Brain Monkey, no WordPress, host PHP | ~1 s | `tests/php/unit/*Test.php` (`tests.php`) | `@group P-4` | `yayh test run unit` |
| **integration** | PHPUnit + the WordPress (and WooCommerce) test suite in wp-env's **tests** site (port+1, its own database) | ~10–60 s, needs Docker | `tests/php/integration/*Test.php` | `@group P-4` | `yayh test run integration` |
| **js** | Vitest, Jest or wp-scripts (`tests.jsRunner`) | ~1–5 s | `tests/js/**/*.test.{js,ts,tsx}` (`tests.js`), or the repo's own location | `@P-4` in the `describe`/`test` name | `yayh test run js` |
| **e2e** | Playwright against wp-env's dev site | minutes, needs Docker | `tests/e2e/specs/` | `{ tag: '@P-4' }` | `yayh e2e run --grep @P-4` |
| **manual** | a person, following an exact check | — | the plan's Verify section | — | — |

`yayh test run all` runs every configured layer except e2e. When the tests site is down, integration is reported as *skipped*, not passed. `--id=P-4` runs only the tests tagged with that ID. `yayh test list P-4` finds them.

## Choosing the layer (the ladder)

For each **risk** in the change (an acceptance criterion, a bug's root cause, a branch of logic that can go wrong), go down the ladder and stop at the **first layer that can prove it**:

1. **unit:** the code decides something from its inputs: calculations (prices, discounts, fees, points), validation and sanitizing, parsing, formatting, eligibility rules, state machines, mapping settings to behaviour. WordPress calls around it can be stubbed (`Functions\when`, `Filters\expectApplied`) without faking the thing being tested.
2. **integration:** the risk lives in how the code meets WordPress or WooCommerce:
   - hooks registered and firing in the right order
   - options, meta, custom tables, migrations and upgrades
   - HPOS order storage
   - REST routes (permission, request in, response out)
   - capabilities and nonces
   - cron and Action Scheduler jobs
   - real `WC_Product`/`WC_Order`/cart totals
   - emails being triggered
   - uninstall

   If a unit test would need more than about three stubs to get there, it belongs here.
3. **js:** front-end logic: reducers and stores, formatters, hooks, data transforms, and a component's behaviour (render with props, click, see the result). Use `jsdom` and Testing Library for components.
4. **e2e:** only what a browser alone can prove (`reference/e2e.md`, "When a flow deserves a spec"): what a customer sees in cart, checkout or My Account, a JS admin screen that must save and reload, and markup from WooCommerce or a theme that the plugin doesn't control.
5. **manual:** none of the above can reach it: a real payment gateway, an external API without a sandbox, how something looks visually. Write the exact check: where to go, what to do, and what you should see.

**Two layers only for two risks.** Add a second layer when it guards a *different* risk, and name that risk. For example, a tiered discount gets a **unit** test for the tier math, plus an **e2e** spec because the block checkout must show the discounted total. A REST endpoint gets an **integration** test for permissions and the response, plus a **js** test for the settings screen that turns the response into state. Never assert the same outcome at two layers.

**Bugs:** test at the layer where the **root cause** lives, not where the symptom showed. A wrong total caused by the PHP math gets a unit test, even though it was seen at checkout. Add an e2e spec only when the cause itself is markup, JS or a click path.

**How many:** a test per risk, not per function. A typical plan has 1–4 tests, mostly unit. A pure refactor proves "no change" with the tests that already exist; add one only where coverage is missing around the code it moves. No tests for copy changes, trivial getters, WordPress core behaviour, or code the change doesn't touch.

**Missing layer:** if the right layer isn't set up here (`yayh test status`), still pick it, and write the test into the plan as `[unit] … (not set up: /yay:test-init)`. Don't drop down to a worse layer. Then use the manual check until the layer exists.

## Writing tests

- **One test class per unit under test**, mirroring the source path: `includes/Rules/Tier.php` → `tests/php/unit/Rules/TierTest.php`. Use `snake_case` test methods that state the behaviour: `test_rounds_the_discount_to_cents`.
- **Tag with the artifact:** `@group P-4` (or `B-7`) in the class or method docblock for PHP, and `@P-4` in the `describe`/`test` name for JS.
- **Unit:** extend `YayTests\Unit\TestCase`. Translation and escaping functions already return their input. Stub the WordPress functions the code calls with `Brain\Monkey\Functions\when( 'get_option' )->justReturn( … )`, and assert hooks with `Functions\expect`, `Filters\expectApplied` and `Actions\expectDone`. Never mock the class under test. Load the code through Composer's autoload, or `require_once` the file in the test.
- **Integration:** extend `WP_UnitTestCase`. Build data with `self::factory()->post|user|term->create()`, and with WooCommerce objects (`new WC_Product_Simple()`, `wc_create_order()`). Every test runs in a transaction that is rolled back, so it leaves nothing behind. Call `update_option` and the like directly: you're testing the plugin, not the admin screen.
- **JS:** test behaviour through the module's public exports. For components, use Testing Library queries by role or label, the same as the e2e rules. Mock network calls (`apiFetch`) at the boundary.
- **Fail first:** a new test must fail without the change. For a fix, stash it (`git stash push -- <fix files>`) and run the test to see it fail. For a feature, run it before the code exists, or reason about why it would fail. A test that can't fail proves nothing.
- **Code rules apply** (`code-rules.md`): reuse helpers in the test bootstrap or `TestCase`, add one only when two tests need it, and no comments that narrate the steps.

## The setup

| Piece | Where | Owner |
|---|---|---|
| `commands.test-unit`, `test-integration`, `test-js`, `test` (unit + js, what `/yay:release` and CI run first) | `.yay/config.json` | team (written once by `yayh test scaffold`) |
| `tests.php` (default `tests/php`), `tests.js` (default `tests/js`), `tests.jsRunner` | `.yay/config.json` | team |
| `unit.xml.dist`, `integration.xml.dist`, `unit/bootstrap.php`, `unit/TestCase.php`, `integration/bootstrap.php` | `tests/php/` | team (seeded once, never re-synced by the kit) |
| `.github/workflows/tests.yml` | repo | team (seeded once) |

- **Dev packages:** `phpunit/phpunit ^9.6` (the WordPress test suite doesn't support 10 yet), `yoast/phpunit-polyfills ^2.0`, and `brain/monkey ^2.6`, added with `composer require --dev`. The release zip must be built with `composer install --no-dev`, so that `vendor/` doesn't ship PHPUnit.
- **Integration uses wp-env's tests site, never the dev site.** The WordPress test suite drops and reinstalls every table under its prefix. The dev site (`cli`) shares the e2e database, so running integration there would wipe the e2e site's seeded data. `yayh test scaffold` turns on `testsEnvironment` in `<e2e.dir>/.wp-env.json`, and `commands.test-integration` runs `wp-env run tests-cli`. The e2e package is shared: if it doesn't exist yet, the scaffold creates it. `yayh e2e env start` starts both sites.
- **Composer runs on the host.** `vendor/` is mapped into the containers along with the rest of the checkout, so the integration tests use the same packages under the container's PHP (8.2 by default).
