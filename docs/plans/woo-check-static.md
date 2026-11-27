---
id: P-5
title: /yay:woo-check static checks (step 1)
status: in-progress
from: BS-4
roadmap:
design:
trello:
type: feat
branch: feat/p-5-yay-woo-check-static
pr:
editions: [free, pro]
created: 2026-11-27
reviewed: yes
---
# P-5 /yay:woo-check static checks (step 1)

## Goal
A Yay developer types `/yay:woo-check` in a WooCommerce extension repo (`requires.wc` is set). They get the checks WooCommerce's QIT runs before a Marketplace release, run locally on **the zip the repo really builds**, with no WooCommerce.com account and no Docker:
- **SEC** security: PHPCS `WordPress.Security` and `WordPress.DB` on the whole plugin, `composer audit`, `npm audit` and gitleaks
- **STAN** PHPStan with the WordPress and WooCommerce stubs, level 2 by default
- **CMP** PHPCompatibilityWP from `Requires PHP` up to the newest PHP
- **MAL** malware patterns: dangerous functions, obfuscation, long base64 strings, hidden or disguised files, non-printable characters
- **VAL** WooCommerce headers and the HPOS and block-checkout compatibility declarations

The report gives each area Success, Warning or Failed, then every finding with an ID, a `file:line` and a fix. A committed baseline means only new findings count. Each run also ends with a plain-language summary written by `/yay:report` (a new `check` kind) that the developer can send to the lead or the team as it is. `/yay:release --woo-check` puts the report in the bundle and stops the release only when SEC or MAL is Failed (BS-4 decision).

Done means:
- `yayh woo-check static` reports the planted violations of every area on the fixture, and nothing on its clean file
- `/yay:woo-check` on a real Yay WooCommerce plugin writes the report, and a second run with the baseline written shows no new findings
- the `woo-check-planted-violations` eval passes
- `./tests/run.sh` is green

## Non-goals
- **The site stage (BS-4 step 2).** Activation with Woo flows, WooCommerce core checkout and REST tests, the REST fuzz and `--matrix` get their own plan. This one leaves `yayh woo-check site` out entirely.
- **Calling QIT.** No Yay plugin is on the Woo Marketplace. `--qit` waits until one is (BS-4 "What would change my mind").
- **Fixing PHPStan findings at level 2 for every plugin.** The baseline exists so a first run doesn't have to.
- **Changing `/yay:wporg`.** Its precheck stays as it is. Overlap (forbidden functions under both G and MAL) is accepted: the two reports serve different reviews.
- **Touching the plugin's `composer.json`, `vendor/` or `package.json`.** The tools live in the kit cache.

## Findings
1. **The kit already builds and checks what ships.** `/yay:wporg` step 1 uses `yayh run package`, `yayh build zip edition=<e> version=<v>` and `yayh build check` (`skills/wporg/SKILL.md`, "What ships"). `/yay:woo-check` copies that step, so Pro code the build strips isn't reported.
2. **A Woo extension is already declared.** `requires.wc` is null when the plugin isn't a Woo extension (`reference/config.md`, `requires.wp / requires.wc`). That's the opt-in: no new "is this Woo?" key.
3. **There is no kit cache folder today.** Nothing in `lib/` or `bin/` writes outside the repo or `release.bundleDir`; the only downloads are `curl` calls to sites (`lib/wporg.sh:20`, `lib/e2e.sh:49`). The tool cache is new.
4. **`yayh doctor` already gates a tool on a config key**: `python3` only when `plugin.wporgSlug` is set (`lib/doctor.sh:47-51`). The Woo tools follow the same pattern on `requires.wc`.
5. **`python3` is a kit dependency only for WordPress.org repos** (BS-1 decision, `lib/doctor.sh:47`). The MAL and VAL checks are regex and file-walk work like `precheck.py`, so a Python script is the natural fit; the doctor then needs `python3` for `requires.wc` repos too.
6. **Most tools are Composer packages.** PHPCS, WordPress Coding Standards, PHPCompatibilityWP, PHPStan, `szepeviktor/phpstan-wordpress` and `php-stubs/woocommerce-stubs` install together from one `composer.json` + `composer.lock`, which pins them exactly. gitleaks is a Go binary: pinned by version and sha256 per OS and arch.
7. **The audits need lock files the zip doesn't have.** `composer audit` reads `composer.lock`, `npm audit` reads `package-lock.json`, and both live in the repo, not in the built zip. They run against the checkout (`--no-dev` / `--omit=dev`, since only production dependencies ship).
8. **The release skill already has the slot.** `/yay:release` step 5 runs `/yay:wporg --report-only` and copies its folder into the bundle, with blockers stopping the release (`skills/release/SKILL.md:67`). The Woo check is a step 5b with the same shape.
9. **Libraries in `vendor/` use the functions MAL1 looks for.** `symfony/process` calls `proc_open`, and many PHP SDKs call `shell_exec` or `exec` behind a check. If MAL1 were FAIL everywhere, the first `/yay:release --woo-check` would stop on code nobody at Yay wrote.
10. **PHPStan needs the dependencies it doesn't analyse.** If `vendor/` is left out entirely, every call into a bundled library shows up as STAN1 "unknown class". It has to be in `scanDirectories` (discovery only) while staying out of `paths`.
11. **`tests/run.sh --changed` maps paths to test files by hand** (`tests/run.sh:46-59`, e.g. `skills/wporg/scripts/*` → `test_wporg.sh`). New files without a mapping are never covered by `--changed` or `--quick`.
12. **`/yay:report` has four kinds and none fits a check result.** `idea`, `done`, `feature` and `guide` (`lib/report.sh:6`), each with fixed sections in English and Vietnamese (`_report_sections`, `lib/report.sh:13-24`) and a template per language (`templates/report/<kind>.md`, `templates/report/vi/<kind>.md`). `done` comes closest, but "What's done" and "What it means for users" don't hold a verdict and a list of things to fix. `report check` already keeps file names and jargon out of the body and allows them under **For developers**, which is exactly where the IDs and `file:line` go. It publishes the page as an Artifact when the tool is there, so the developer gets a link to share.
13. **`.yay/` never ships.** `yayh build check` already FAILs a zip with `.yay/` in it (`lib/release.sh:301`), so a committed baseline can't leak into a release.
14. **The kit repo isn't harnessed** (as P-1 Findings 8): `yayh artifact`, `plan` and `verify` may exit 3 here, so this plan was written by hand.

## Approach
- **The skill:** `plugins/yay/skills/woo-check/` (new) with `SKILL.md`, `references/checklist.md`, `references/report-template.md`, `scripts/woocheck.py` and `tools/` (the pinned `composer.json`, `composer.lock` and `gitleaks.tsv`).
- **IDs** (`references/checklist.md`): each row has ID, rule, how it's checked (`phpcs:<sniff>`, `phpstan`, `audit`, `gitleaks`, `woocheck:<check>`), severity and the fix.
  - SEC1 PHPCS `WordPress.Security.*`, SEC2 `WordPress.DB.*`, SEC3 `composer audit`, SEC4 `npm audit`, SEC5 gitleaks
  - STAN1 PHPStan errors
  - CMP1 PHPCompatibilityWP
  - MAL1 dangerous functions (`eval`, `assert` on a string, `create_function`, `system`, `shell_exec`, `passthru`, `proc_open`, backticks), MAL2 obfuscation (`base64_decode`/`gzinflate`/`str_rot13` chains, `preg_replace` with `/e`, strings of 200+ base64 characters), MAL3 hidden files or folders and PHP disguised under another extension, MAL4 non-printable characters in PHP
  - VAL1 `WC requires at least` and `WC tested up to` headers present, VAL2 they agree with `requires.wc` and `tested.wc`, VAL3 HPOS declared (`FeaturesUtil::declare_compatibility( 'custom_order_tables', … )`), VAL4 block checkout declared (`cart_checkout_blocks`), VAL5 `WC tested up to` older than the newest WooCommerce release (WARN; SKIP offline)
- **Severity:** PHPCS ERROR → FAIL, WARNING → WARN; audit advisories `high` or `critical` → FAIL, others WARN; any gitleaks hit → FAIL; PHPStan error → FAIL; MAL1 → FAIL in the plugin's own code, WARN under `vendor/` and `node_modules/` (Findings 9); MAL2 → FAIL everywhere, since no honest library hides code that way; MAL3–MAL4 → WARN; VAL1, VAL3 → FAIL, the others WARN. QIT's suppression comments are honoured as they are: `phpcs:ignore`, `gitleaks:allow`, and a new `woo-check:allow <ID>` comment for `woocheck.py`.
- **Paths:** PHPCS and PHPStan don't report on `vendor/` and `node_modules/` (bundled libraries are SEC3/SEC4's job). PHPStan still reads `vendor/` through `scanDirectories`, so calls into it resolve (Findings 10). MAL scans everything in the zip, `vendor/` included, since that's where injected code hides.
- **Tools:** `yayh woo-check tools [--install]` prints each tool, its pinned version and `ok|missing`. `--install` runs `composer install --no-dev --no-interaction` from `tools/composer.lock` into `<cache>/woo-check/<hash of composer.lock>/` and downloads gitleaks from `tools/gitleaks.tsv`, checking its sha256. `<cache>` is `${YAY_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/yay}`. A new lock hash means a new folder, so two kit versions never share tools. Needs `php` and `composer` on the host.
- **The static run:** `yayh woo-check static <zip|dir> out=<dir> [repo=<root>] [--only=sec,stan,cmp,mal,val]`.
  - Unpacks the zip into `<out>/src`, runs each area, and writes `findings.tsv` (`result id file line code message`, paths relative to the plugin folder) and `areas.tsv` (`area status fail warn skip`).
  - A missing tool gives SKIP rows for its IDs, never a silent pass.
  - Bash only runs the tools and saves each one's raw JSON in `<out>/raw/`. `woocheck.py convert <tool> <json>` turns it into `findings.tsv` rows, so every conversion is tested on a saved JSON file instead of a fake binary.
  - Tools are found only in the cache folder (`yay_woocheck_cache`), never on `PATH`, so the pinned version is the one that runs. `composer` and `npm` for the audits come from `PATH`.
  - PHPStan: a generated `<out>/phpstan.neon` with the stubs, `scanDirectories: [vendor]` when the zip has one, `level` from `wooCheck.phpstanLevel` (default 2), `--memory-limit=1G`, `--error-format=json`.
  - PHPCompatibility: `testVersion` is `<requires.php>-` (the header's `Requires PHP` when the config has none).
  - Exit 0 when SEC and MAL aren't Failed, 1 when either is, 3 when nothing could run (no tools at all).
- **Baseline:** `.yay/woo-check-baseline.tsv`, committed. A row's key is `id`, `file`, `code` and a sha256 of the message with numbers removed, so it survives moved lines. `yayh woo-check baseline <out> [--update]` marks baseline rows `BASE` in `findings.tsv` (they don't count towards an area's status) and lists the baseline rows that no longer occur; `--update` rewrites the file from `<out>`. `/yay:woo-check --update-baseline` does it on a branch, in a `chore(woo-check)` commit, so the PR shows the diff.
  - **Never baselined:** SEC5 (a secret in the zip) and MAL2 (obfuscated code). `--update` leaves them out and says so: they're fixed, or allowed in place with `gitleaks:allow` / `woo-check:allow MAL2` next to the line, where a reviewer sees it.
  - The report always gives the number of baselined SEC and MAL rows, so old security findings stay visible.
- **The report:** `<release.bundleDir>/<slug>-woo-check-<v>/report.md`, with `findings.tsv`, `areas.tsv` and the raw tool output next to it. Shape from `references/report-template.md`: a verdict line, the area table, then per area every non-baseline finding with ID, `file:line` (the source path the author edits, traced back as `/yay:wporg` step 3 does) and the fix, then "Not checked" (SKIPs) and "Baseline" (counts, plus rows that went away).
- **Fixes:** as `/yay:wporg` step 5. Ask once: all, only SEC and MAL, or chosen IDs. Branch `fix/woo-check-<n>`, one commit per ID (`fix(security): SEC1 escape admin notice output`), then re-run the static check on the new zip. Asked rather than chosen: removing a dependency for SEC3/SEC4 with no patched version, and declaring HPOS or block-checkout compatibility (VAL3/VAL4) when the code hasn't been checked against them.
- **Plain summary:** the last step of `/yay:woo-check` runs `/yay:report check --from=<report folder>`, in the repo's `language` (`--lang=` overrides). The `check` kind's sections:
  - en: In one line, Result, What blocks the release, Other things to fix, What's next
  - vi: Tóm tắt, Kết quả, Chặn phát hành, Cần sửa thêm, Tiếp theo
  - The body says what each problem means for the store and its customers ("a shop manager could read other customers' orders"), not the sniff name. IDs, `file:line` and tool names go under For developers. A Success run is one line and "Nothing needed from you".
  - It goes through `/yay:report`'s own steps (check, cold reader, render, Artifact), so it looks like every other Yay report. `report.md` stays the full technical record; the summary links to it in For developers.
  - With `/yay:release --woo-check`, the summary's text is also copied to `$bundle/woo-check/<e>/summary.txt` so QA reads it in the bundle.
- **Release:** `/yay:release --woo-check`, a step 5b after the WordPress.org review: `/yay:woo-check --zip=<zip> --report-only` per edition, report copied into `$bundle/woo-check/<e>/`. SEC or MAL Failed stops the release with the IDs, like a build-check FAIL. With no baseline file yet, the step stops before running and asks for `/yay:woo-check --update-baseline` on a branch first, so a release never turns into the first triage of years of findings. Other areas' failures go into Prepare step 9's question. When `requires.wc` is set and the flag isn't given, mention it.
- **Wiring:** a `/yay:go` routing row, the README, `yayh doctor`, the config key, the CHANGELOG.

## Tasks
- [x] T1 Write the checklist and the report template — `plugins/yay/skills/woo-check/references/checklist.md` (new)
  - Files: `plugins/yay/skills/woo-check/references/checklist.md` (new), `plugins/yay/skills/woo-check/references/report-template.md` (new)
  - Every ID from Approach, with how it's checked, severity, the fix, and a "When this is fine" note where a finding can be deliberate (MAL1 in a CLI-only file, SEC2 on a prepared query PHPCS can't see).
  - The template: verdict, area table, findings per area, Not checked, Baseline.
  - Reuse: the shape of `skills/wporg/references/checklist.md` and `report-template.md`. [risk: 1]
- [x] T2 Pin the tools and install them into the kit cache — `plugins/yay/lib/woocheck.sh` (new), `plugins/yay/skills/woo-check/tools/` (new)
  - Files: `plugins/yay/skills/woo-check/tools/composer.json` (new), `plugins/yay/skills/woo-check/tools/composer.lock` (new), `plugins/yay/skills/woo-check/tools/gitleaks.tsv` (new: version, os, arch, url, sha256 for darwin and linux, arm64 and x64), `plugins/yay/lib/woocheck.sh` (new), `plugins/yay/bin/yayh` (source the lib, `woo-check` dispatch, help text), `tests/unit/test_woocheck.sh` (new), `tests/run.sh` (`--changed` maps `lib/woocheck.sh` and `skills/woo-check/*` to `test_woocheck.sh`)
  - `yay_woocheck_cache`, `yay_woocheck_tools [--install]` as in Approach. A sha256 mismatch deletes the download and fails.
  - Reuse: `yay_sha256` (`lib/common.sh:70`), `yay_die`/`yay_warn`, the `wporg` case in `yayh` as the dispatch pattern (`bin/yayh:526`).
  - Callers: `yay_woocheck_tools` → `yayh woo-check tools`, `yay_woocheck_static` (T4), `yayh doctor` (T6).
- [x] T3 `woocheck.py`: the MAL and VAL checks, and the tool-output converters
  - Files: `plugins/yay/skills/woo-check/scripts/woocheck.py` (new), `tests/fixtures/woo-check/planted/` (new: a tiny Woo plugin with one planted violation per MAL and VAL ID, a `vendor/lib/process.php` calling `proc_open`, plus `includes/clean.php`), `tests/fixtures/woo-check/raw/` (new: one saved JSON output per tool: phpcs, phpstan, composer audit, npm audit, gitleaks), `tests/unit/test_woocheck.sh`
  - Input: the plugin folder, `--requires-wc`, `--tested-wc`, `--wc-latest` (optional). Output: `findings.tsv` rows on stdout. `woo-check:allow <ID>` on the line or the one above silences it.
  - `convert <phpcs|phpstan|composer|npm|gitleaks> <json> --root <plugin dir>`: one row per finding with the ID, the severity rule from Approach and the path relative to the plugin folder.
  - VAL3/VAL4 look for `declare_compatibility` with the feature name inside a `before_woocommerce_init` callback; a `false` third argument is a WARN ("declared incompatible"), not missing.
  - Reuse: the file walk and regex table style of `skills/wporg/scripts/precheck.py` (copy the pattern, don't import it: the two scripts ship separately).
- [x] T4 `yayh woo-check static`
  - Files: `plugins/yay/lib/woocheck.sh`, `plugins/yay/bin/yayh`, `tests/unit/test_woocheck.sh`
  - `yay_woocheck_static` as in Approach: unpack, PHPCS twice (a generated security ruleset and a PHPCompatibilityWP ruleset, `--report=json`), PHPStan, `composer audit --no-dev --format=json` and `npm audit --omit=dev --json` in `repo=` (default: the repo root; skipped with a SKIP row when the lock file is absent), `gitleaks dir --report-format json`, `woocheck.py`; each tool's JSON turned into `findings.tsv` rows; `areas.tsv`; the exit codes.
  - Each tool's JSON goes through `woocheck.py convert` (T3).
  - Reuse: `yay_config_get` for `requires.php`, `requires.wc`, `tested.wc`, `wooCheck.phpstanLevel`; `yay_woocheck_tools` (T2).
  - Callers: `yay_woocheck_static` → `yayh woo-check static` → `/yay:woo-check` step 2 (T7).
- [x] T5 The baseline — `plugins/yay/lib/woocheck.sh`
  - Files: `plugins/yay/lib/woocheck.sh`, `plugins/yay/bin/yayh`, `tests/unit/test_woocheck.sh`
  - `yay_woocheck_baseline <out> [--update]` as in Approach: the key, `BASE` marking, recomputing `areas.tsv`, listing gone rows, never writing SEC5 or MAL2, rewriting the file sorted so its diff is stable.
  - Reuse: `yay_sha256` (`lib/common.sh:70`) for the message hash; `yay_repo_root` for the baseline path.
  - Callers: `yay_woocheck_baseline` → `yayh woo-check baseline` → `/yay:woo-check` steps 2 and `--update-baseline` (T7).
- [x] T6 Config key and `yayh doctor`
  - Files: `plugins/yay/reference/config.schema.json`, `plugins/yay/reference/config.md`, `plugins/yay/lib/doctor.sh`, `tests/unit/test_doctor.sh`
  - `wooCheck.phpstanLevel`: integer 0–10, default 2.
  - Doctor, only when `requires.wc` is set: `php`, `composer` and `python3` (warn with the `brew install` fix when missing), then `yayh woo-check tools` (warn "run `yayh woo-check tools --install`" when any is missing).
  - Reuse: the `plugin.wporgSlug` block in `lib/doctor.sh:47-51`, `_yay_doc`.
- [x] T7 Write `/yay:woo-check`
  - File: `plugins/yay/skills/woo-check/SKILL.md` (new, under 150 lines)
  - Steps: 1 what ships (stop when `requires.wc` is null; build and check the zip as `/yay:wporg` step 1), 2 tools (install on first run, saying so) and `yayh woo-check static` + `baseline`, 3 read every FAIL before reporting it and trace it to the source file, 4 the report, 5 fixes on a branch, 6 the plain summary through `/yay:report check` (T11), 7 wrap up with the **Next** footer, giving the summary's link and `report.md`'s path.
  - Options: `--zip=`, `--edition=` (default: every edition, one report each), `--only=`, `--report-only`, `--update-baseline`.
  - Reuse: `/yay:wporg` steps 1, 4 and 5 as the model; `reference/asking.md`; `reference/git-conventions.md`.
  - Callers: `/yay:woo-check` → the user, `/yay:go` and `/yay:release --woo-check` (T8); `/yay:woo-check` → `/yay:report check` (T11).
- [x] T8 Wire it into release, go and the README — `plugins/yay/skills/release/SKILL.md`, `plugins/yay/skills/go/SKILL.md`, `plugins/yay/README.md`
  - Files: `plugins/yay/skills/release/SKILL.md`, `plugins/yay/skills/go/SKILL.md`, `plugins/yay/README.md`
  - Release: the `--woo-check` option and argument hint, step 5b (with `summary.txt` in the bundle), the bundle README line, the "no baseline yet" stop, Prepare step 9's question for non-blocking areas, and the Don'ts line (never release with SEC or MAL Failed).
  - Go: a row for "QIT", "Woo compatibility", "security scan", "PHPStan", "check before the Woo release" → `/yay:woo-check`.
  - README: the skill in the list and diagram; Requirements gets `php`, `composer` and `python3` for Woo extensions.
  - Reuse: the `--wporg` lines in the release skill (`:4`, `:17`, `:40`, `:67`, `:74`, `:123`, `:146`) and go's routing table (`go/SKILL.md:47`). [risk: 1]
- [x] T9 The eval — `plugins/yay/evals/woo-check-planted-violations/` (new)
  - Files: `plugins/yay/evals/woo-check-planted-violations/` (new: `case.yaml` with `tags: [woo-check]`, `prompt.md`, `scaffold.sh`, `graders/`), `plugins/yay/evals/README.md`
  - The scaffold writes the T3 fixture plus a `.yay/config.json` with `requires.wc` and a `commands.package` that zips the folder. Graders: the report names a planted ID from every area, each with `file:line`; SEC and MAL are Failed; the clean file isn't mentioned; the working tree is unchanged.
  - Reuse: `plugins/yay/evals/wporg-planted-violations/` as the layout. [risk: 1]
- [x] T10 CHANGELOG entry — `plugins/yay/CHANGELOG.md`
  - File: `plugins/yay/CHANGELOG.md`
  - Under `## Unreleased`: `/yay:woo-check`, the new `check` kind of `/yay:report`, `yayh woo-check tools|static|baseline`, `/yay:release --woo-check`, `wooCheck.phpstanLevel`, the doctor checks. For each Woo repo: run `/yay:woo-check` once and commit the baseline with `--update-baseline`.
  - Reuse: n/a [risk: 1]

- [x] T11 A `check` kind for `/yay:report` — `plugins/yay/lib/report.sh`, `plugins/yay/templates/report/check.md` (new)
  - Files: `plugins/yay/lib/report.sh`, `plugins/yay/templates/report/check.md` (new), `plugins/yay/templates/report/vi/check.md` (new), `plugins/yay/skills/report/SKILL.md`, `tests/unit/test_report.sh`
  - `YAY_REPORT_KINDS` gets `check`; `_report_sections` gets the en and vi sections from Approach; the limits stay those of the other kinds (300 en, 450 vi).
  - Templates with hints in each language: the verdict and the one ask in Tóm tắt, results as what the store and customers risk, blockers first.
  - `/yay:report`: a `check` row in the options table, "check results" / "kết quả kiểm tra" in the kind-picking rule, and `--from=<folder>` reading `report.md`, `areas.tsv` and `findings.tsv` from a check folder. Nothing in the kind is Woo-only, so `/yay:wporg` can use it later.
  - Reuse: the `done` templates' layout (`templates/report/done.md`, `templates/report/vi/done.md`), `yay_report_new`, `yay_report_check`, `yay_report_render` unchanged.
  - Callers: `check` kind → `/yay:report` → `/yay:woo-check` step 6 (T7). [risk: 1]

**Tests:** [unit] `test_woocheck_py_planted` (`tests/unit/test_woocheck.sh`): every MAL and VAL ID flags its planted line, `proc_open` under `vendor/` is WARN not FAIL, `woo-check:allow` silences one, and `includes/clean.php` stays quiet.; [unit] `test_woocheck_convert` (`tests/unit/test_woocheck.sh`): each saved JSON in `tests/fixtures/woo-check/raw/` gives the right ID, severity and relative path, and `vendor/` rows from PHPCS and PHPStan are dropped.; [unit] `test_woocheck_static_exit` (`tests/unit/test_woocheck.sh`): with `YAY_CACHE_DIR` pointing at stub tools that print the saved JSON, `areas.tsv` gets the right statuses and the exit code is 1 only when SEC or MAL fails.; [unit] `test_woocheck_static_missing_tools` (`tests/unit/test_woocheck.sh`): no tools gives SKIP rows for every tool ID and exit 3, never a pass.; [unit] `test_woocheck_baseline` (`tests/unit/test_woocheck.sh`): a baselined row becomes `BASE` after its line moves, a new row still counts, a gone row is listed, SEC5 and MAL2 rows are never written, and `--update` output is sorted and stable.; [unit] `test_woocheck_tools_sha_mismatch` (`tests/unit/test_woocheck.sh`): a gitleaks download with the wrong sha256 is deleted and the install fails.; [unit] `test_check_kind_has_its_sections` (`tests/unit/test_report.sh`): `yayh report new check` writes the en and vi templates, `report check` fails on the empty template and passes a filled one with IDs only under For developers.; [unit] `test_doctor_woo_tools` (`tests/unit/test_doctor.sh`): warn lines when `requires.wc` is set and tools are missing, no lines when it's null.; [manual] the real tool install and a run on a Yay WooCommerce plugin: what the unit layer can't do offline.

**E2E:** none

## Verify
- `./tests/run.sh woocheck doctor` → exit 0 (unit)
- `./tests/run.sh` → exit 0
- `python3 -I plugins/yay/skills/woo-check/scripts/woocheck.py tests/fixtures/woo-check/planted --requires-wc 8.0 --tested-wc 9.0` → MAL2 (unit)
- `plugins/yay/bin/yayh --help` → woo-check static
- `./tests/run.sh report` → exit 0 (unit)
- `claude plugin validate plugins/yay` → exit 0
- `grep -q "/yay:woo-check" plugins/yay/skills/go/SKILL.md` → exit 0
- `grep -q -- "--woo-check" plugins/yay/skills/release/SKILL.md` → exit 0
- `wc -l < plugins/yay/skills/woo-check/SKILL.md` → under 150
- On a machine with `php` and `composer`: `yayh woo-check tools --install`, then `yayh woo-check tools` → every tool `ok`, and the cache folder is named after the `composer.lock` hash.
- In a Yay WooCommerce plugin repo, run `/yay:woo-check`. You should see:
  - a report at `release/bundles/<slug>-woo-check-<version>/report.md` with Success, Warning or Failed for SEC, STAN, CMP, MAL and VAL
  - every finding with an ID, a `file:line` in the source and a fix
  - no PHPCS or PHPStan findings from `vendor/`
  - the repo's working tree unchanged (`git status` clean)
- After that run: a plain summary page (an Artifact link, or `.yay/reports/<date>-<slug>.html`) in the repo's language, with no file names or IDs outside For developers, and its paste-ready text in the reply.
- In the same repo, `/yay:woo-check --update-baseline`, then `/yay:woo-check` again → no new findings, and the Baseline section gives the counts.
- In the same repo, `/yay:release --bundle --woo-check` → the bundle has `woo-check/<edition>/report.md`; a planted `eval( base64_decode( … ) )` on a scratch branch stops it with MAL2.
- `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case woo-check-planted-violations --runs 1 --ablation none --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish` → all graders pass.

## Risks
- **The first run is noisy.** PHPCS security sniffs and PHPStan at level 2 flag a lot in older code. The baseline covers it, and the release asks for one before its first run. Baselining SEC findings hides them from the gate, so the report keeps their count, and SEC5 and MAL2 can't be baselined at all.
- **Host PHP and Composer.** The tools run on the host's `php`, which may differ from the plugin's floor. PHPCompatibility is static, so that's fine; PHPStan needs PHP 7.4+ on the host. The doctor names the gap.
- **Downloads.** The first run needs the network (Packagist, GitHub releases). Offline with no cache gives SKIP rows and a "Not checked" section, never a pass.
- **Escaping helpers PHPCS doesn't know.** A plugin's own `yay_esc_*` wrapper shows up as SEC1 `EscapeOutput`. For now that's `phpcs:ignore` or the baseline; a `wooCheck.escapingFunctions` key passed to the ruleset is the follow-up if it's common.
- **Two editions, twice the time.** `--edition` defaults to every edition and Pro usually contains Free, so a two-edition plugin runs the static check twice with mostly the same findings. Accepted for step 1: headers and VAL can differ per edition. Revisit if a run takes more than a few minutes.
- **Stub drift.** `php-stubs/woocommerce-stubs` is pinned; a new WooCommerce API the plugin uses can show as a STAN1 false positive until the lock is bumped. Bumping `tools/composer.lock` is a normal kit change with a CHANGELOG line.
- **`yayh artifact`, `plan` and `verify` exit 3 in this repo** (Findings 14). If `yayh plan tick` fails during `/yay:implement`, tick the checkbox by hand.

## Build notes
Built differently from the plan, on purpose:
- **Baseline hashing** lives in `woocheck.py baseline` (sha256 in Python), not `yay_sha256`: the rows are already parsed there, and the bash side only calls it.
- **PHPStan and `vendor/`**: `excludePaths.analyse` keeps `vendor/` and `node_modules/` out of the results while they stay in `paths`, so their classes are still discovered. No `scanDirectories` needed.
- **Area status** needs an `INFO … ran <tool>` row per check that ran; an area with none is `Skipped`, never `Success`.

This is the yay kit repo itself, not harnessed (no `.yay/config.json`). The checks are `./tests/run.sh` (full suite before the last commit) and `claude plugin validate plugins/yay`. Follow `.claude/skills/kit-ship/SKILL.md` for branch naming, conventional commits and the `## Unreleased` CHANGELOG entry (this is a `feat`, so a minor bump: 0.22.0). Generate `tools/composer.lock` with `composer update` in `tools/`, and fill `gitleaks.tsv` from the release's published checksums, not from a local hash.
