---
id: BS-4
title: WooCommerce quality check, QIT-style, run locally
status: decided
from:
decision: A. /yay:woo-check in the kit, static first
created: 2026-11-27
---
# BS-4 WooCommerce quality check, QIT-style, run locally

## Problem
WooCommerce's QIT (Quality Insights Toolkit, `woocommerce/qit-cli`) runs a fixed set of checks on an extension's zip before every Woo Marketplace release: activation, security, PHPStan, PHP compatibility, malware, validation, Plugin Check, WooCommerce core E2E and REST tests, and REST fuzzing, against chosen WordPress, WooCommerce and PHP versions. Each run ends in Success, Warning or Failed, with a report per test.

Yay plugins aren't on the Woo Marketplace, so `qit run:*` isn't available to us: it needs a WooCommerce.com partner account with a listed extension. The checks themselves are still what a WooCommerce extension should pass before a release, and most of them are open tools (PHPCS + WPCS, PHPStan + `php-stubs/woocommerce-stubs`, PHPCompatibilityWP, `composer audit`, `npm audit`, gitleaks, WP-CLI on a throwaway site).

What the kit covers today, and what's missing:

| QIT test | In the kit today | Missing |
|---|---|---|
| plugin-check | `/yay:wporg` T1 on the built zip (`lib/wporg.sh:83`) | nothing |
| activation | `yayh wporg site`: Q11 clean activation, Q6 `debug.log`, Q7 uninstall leftovers | the Woo flow: log in, create a product, place an order, deactivate, all with no PHP notice |
| security | `precheck.py` heuristics (escaping, SQL, forbidden functions), `yay:bug-reviewer` on the diff only | PHPCS `WordPress.Security` + `WordPress.DB` on the **whole zip**, `composer audit`, `npm audit`, gitleaks |
| phpstan | none | PHPStan with WordPress and WooCommerce stubs, level from config |
| phpcompatibility | none | PHPCompatibilityWP with `testVersion` from the `Requires PHP` header up to the newest PHP |
| malware | `precheck.py` forbidden functions | obfuscation, long base64 strings, hidden files and folders, non-printable characters |
| validation | `precheck.py` WordPress headers and readme | `WC requires at least`, `WC tested up to`, `FeaturesUtil::declare_compatibility` for `custom_order_tables` (HPOS) and `cart_checkout_blocks` |
| woo-e2e / woo-api | `/yay:e2e` tests the plugin's own flows only | WooCommerce core flows with the plugin active: classic and block checkout, products and orders REST CRUD |
| api-fuzz | none | the plugin's REST routes (`yayh e2e surfaces`) called anonymous and as admin, any 5xx is a finding |
| version matrix | one wp-env site, `phpVersion` 8.2 (`templates/e2e/.wp-env.json:3`) | the same site at the minimum and the newest WP, WC and PHP |
| custom E2E packages | `/yay:e2e` | nothing |
| `qit compare` | none | this run's results against the last run's |

## Constraints
- **Check what ships.** As in `/yay:wporg`: the zip comes from `yayh run package` and passes `yayh build check` first, so Pro code the build strips isn't reported.
- **No account, no network service.** Everything runs on this machine. Tools that need downloading (PHPCS, PHPStan, stubs, gitleaks) go into a kit cache, never into the plugin's `composer.json` or `vendor/`.
- **The site already exists.** `yayh wporg site` installs the zip on the `release ui` wp-env site and writes `site.tsv` rows (`PASS|WARN|FAIL|SKIP|INFO`, ID, detail). The new site checks should be more rows in the same shape. Without `/yay:e2e-init` the site stage exits 3 and the report is static only.
- **Read-only by default.** Fixes go through a branch and PR, as in `/yay:wporg` step 5.
- **Skill size.** A new `SKILL.md` stays under 150 lines (R-8).
- **Overlap with `/yay:wporg`.** Plugin Check, activation, debug.log and uninstall leftovers are already there. They should be shared, not run twice under two sets of IDs.

## Options

### A. A new `/yay:woo-check` skill that reuses the wporg site and adds the QIT checks
- **How:**
  - `plugins/yay/skills/woo-check/`: `SKILL.md`, `references/checklist.md` (IDs per area: `SEC`, `STAN`, `CMP`, `MAL`, `VAL`, `ACT`, `WOO`, `API`), `references/report-template.md`.
  - `lib/woocheck.sh` with `yayh woo-check static <zip> out=<dir>` (PHPCS, PHPStan, PHPCompatibility, audits, gitleaks, malware patterns, Woo headers and feature declarations) and `yayh woo-check site <zip> out=<dir> [wp=] [wc=] [php=]` (calls the shared part of `yayh wporg site`, then adds the Woo flow, core checkout and REST checks, and the REST fuzz). Both write TSV rows like `site.tsv`.
  - Tools pinned and cached under the kit's data folder, installed on first run; `yayh doctor` reports them.
  - The report at `release/bundles/<slug>-woo-check-<v>/report.md`: one Success / Warning / Failed per area, then every finding with ID, `file:line` and fix. `--compare` diffs the TSV against the previous version's folder.
  - `/yay:release --woo-check` runs it with `--report-only`. `/yay:go` routes "QIT", "Woo compat", "security scan", "PHPStan" to it.
  - Options: `--zip`, `--edition`, `--only=<areas>`, `--wp`, `--wc`, `--php`, `--matrix` (min and newest), `--report-only`, `--no-site`, `--keep-site`.
- **Pros:**
  - Covers every QIT test we can run without an account, on the real zip.
  - Reuses the build, site, TSV and report patterns `/yay:wporg` already proved.
  - Each area can be run alone, so it's useful during development too, not only at release.
- **Cons:**
  - The largest option. PHPStan and PHPCS on a real plugin give a lot of findings at first; the first run needs a baseline.
  - The Woo core flows need a seeded WooCommerce site (products, a payment method that works offline, such as Cash on delivery).
- **Risks:**
  - Noise. Mitigate with a baseline file per repo (`.yay/woo-check-baseline.tsv`) so only new findings fail, and with QIT's own suppression comments (`phpcs:ignore`, `nosemgrep`, `gitleaks:allow`) honoured.
  - Slow matrix runs. Mitigate: the matrix is opt-in, and static checks never need the site.
- **Size:** L

### B. Extend `/yay:wporg` and `yayh build check` instead of a new skill
- **How:** add the static tools to `precheck.py` and `build check`, the Woo flow and REST checks to `yayh wporg site`, and a `--woo` flag to `/yay:wporg`.
- **Pros:** one skill, one site run, no ID overlap.
- **Cons:**
  - `/yay:wporg` is about WordPress.org review and writes the Plugins Team's email; Woo compatibility and PHPStan aren't part of that review, and plugins that don't ship to WordPress.org (`plugin.wporgSlug` unset) would still need it.
  - Makes the wporg skill and `precheck.py` (918 lines) bigger, against R-8.
- **Size:** M

### C. Only a deterministic gate in `/yay:release`
- **How:** `yayh woo-check static` from A, run by `/yay:release` as a pass/fail step. No site checks, no reviewer pass, no skill.
- **Pros:** small, fast, fully unit-testable in `tests/`.
- **Cons:** skips the checks that catch the worst Woo bugs (activation with WooCommerce flows, HPOS and block checkout at runtime, REST 5xx). No fix flow.
- **Size:** S–M

## Recommendation
**A. A new `/yay:woo-check` skill**, built in two steps:
1. **Static first:** `yayh woo-check static`, the checklist, the report, the baseline, `doctor`, and the release flag. This gives SEC, STAN, CMP, MAL and VAL with no Docker.
2. **Site second:** move the shared part of `yayh wporg site` into one helper, then add ACT, WOO and API rows and the `--matrix` option.

C is step 1 without the skill, so starting with A loses nothing. B mixes two different reviews into one report.

**What would change my mind:**
- If no Yay plugin should ship without passing it, make step 1 a required gate in `/yay:release` (C's behaviour) as well as a skill.
- If a Yay plugin is later listed on the Woo Marketplace, add `--qit` to call `qit run:*` and map its JSON into the same report, instead of building a second skill.

**Decided (2026-11-27):** A.
- **Name: `/yay:woo-check`.** Not `/yay:qit`: we don't run WooCommerce's QIT, and the name shouldn't suggest we do.
- **PHPStan level 2 by default**, as QIT's CLI. A repo can change it with a `wooCheck.phpstanLevel` config key.
- **Only security blocks a release.** A Failed `SEC` or `MAL` area (after the baseline) stops `/yay:release --woo-check`. Every other area goes into the bundle's report only.
- **Tools are downloaded, pinned, into the kit cache** on first run. Nothing goes into the plugin's `composer.json` or `vendor/`. `yayh doctor` shows each tool's version, or what's missing when offline.

Defaults taken without a separate decision (change them in the plan review if needed):
- **Baseline is committed** at `.yay/woo-check-baseline.tsv`, so the whole team sees the same "new findings". `--update-baseline` rewrites it, and the PR shows the diff.
- **PHPCompatibility checks** from the `Requires PHP` header up to the newest stable PHP.
- **Woo versions for `--matrix`:** the lower bound is `WC requires at least`, the upper bound is the newest release from the WordPress.org API (when offline, `WC tested up to`). A newest release above `WC tested up to` is a `VAL` warning.

## Open questions
- None left for step 1. Step 2's Woo core flows need a seed (products and an offline payment method): decide in its plan whether it extends the e2e seed or has its own.
