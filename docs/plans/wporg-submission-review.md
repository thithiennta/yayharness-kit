---
id: P-1
title: /yay:wporg WordPress.org submission review
status: done
from: BS-1
roadmap:
design:
trello:
type: feat
branch: feat/p-1-yay-wporg-wordpress-org-submission-review
pr:
editions: [free]
created: 2026-11-13
reviewed: yes
---
# P-1 /yay:wporg WordPress.org submission review

## Goal
A Yay developer types `/yay:wporg` in a plugin repo that ships to WordPress.org (`plugin.wporgSlug` is set). They get a pre-review of **the free zip the repo really builds**, run on a clean throwaway site, written as the Plugins Team's review email. Every finding has a stable ID (S/G/B/Q/R/T/U, as in the partner checklist), a `file:line` and a fix, and blockers are marked apart from review issues. `/yay:wporg --email` takes a pasted review email, maps its headings to IDs, fixes every occurrence on a branch, and drafts the short reply. `/yay:release --wporg` runs the review as a release step.

Done means:
- the two ported evals pass
- `yayh wporg site` reports Plugin Check, clean activation, lifecycle and runtime-requirement results on a real Yay plugin
- `./tests/run.sh` is green

## Non-goals
- **Uploading or SVN deploys to WordPress.org.** The skill stops at the report, the fixes and the reply draft.
- **A harness-free version for the partner team.** BS-1 decided kit-only.
- **Porting `precheck.py` to bash.** BS-1 decided `python3` is a kit dependency.
- **Removing `~/.claude/skills/wporg-plugin-review`.** It's outside the repo; see Risks.
- **The partner's Q12 query-cost measurement** (`SAVEQUERIES` at two data sizes). It stays a manual-review item with its method written down, not an automated check.

## Findings
1. **The kit already builds exactly what ships.** `yayh build zip edition=<e>` and `yayh build check` (release SKILL step 2.3–2.4) cover one top folder, dev files, `package.forbidden` per edition, and the version and Stable tag. So the local skill's Step 1 (guessing the build from workflows, scripts and `.distignore`, plus the "repo source, not built" fallback) gets replaced, not ported. With no `commands.package`, the skill falls back to the local skill's repo-scan mode and says so.
2. **The throwaway site already exists, but it's locked inside `yay_release_ui`.** Lines `lib/bundle.sh:253-329` do three jobs in one function: start a site from the zip, run the plugins-page Playwright spec, and scan `debug.log`. `yayh wporg site` needs the first and last parts without the spec, so T3 pulls the site start and log scan out into shared helpers. `release ui` must behave the same afterwards. The SKIP paths (`bundle.sh:267-270`, exit 3) carry over as they are.
3. **The site already runs with `WP_DEBUG`, `WP_DEBUG_LOG` on and `WP_DEBUG_DISPLAY` off** (`bundle.sh:291`). So Q11 ("activation prints nothing") has to capture the output of `wp plugin activate` and of a front-end and admin request. It can't rely on the screen.
4. **`wp plugin uninstall` deletes the plugin folder by default.** Here that folder is a bind-mounted copy (`bundle.sh:276-281`). The lifecycle check uses `--skip-delete` so the mount survives, then re-copies the folder for the next run anyway.
5. **`precheck.py` already covers most of the partner's static items**, including `ob_start` (`precheck.py:626`), echoed JSON flags (`:72`), `load_plugin_textdomain` (`:73`) and `serialize_block_attributes` (in its rules). It's missing four:
   - post type keys over 20 characters (Q9)
   - `admin_body_class` and enqueue scope (Q3)
   - `wp_json_encode` into `wp_add_inline_script` without `JSON_HEX_TAG|JSON_HEX_AMP` (S11)
   - a `WP_Query` on `product` with no visibility filter (Q13)

   Its findings carry check names (`unclosed_ob_start`), not IDs, so T2 adds an ID map.
6. **The local evals use another format.** They have frontmatter in `prompt.md` and a `place-files.sh`, while the kit uses `case.yaml`, `prompt.md`, `scaffold.sh` and `graders/` (`evals/implement-tiny-lane/`). `yaycheckout-real-plugin` points at `~/Local-Sites/...`, a path only one machine has, so it isn't ported. The other two scaffolds also need a `.yay/config.json` with `wporgSlug` and a package command, so that the skill takes its harness path.
7. **`yayh doctor` treats `python3` only as one possible JSON engine** (`lib/doctor.sh:22`). Nothing checks for it as a tool in its own right.
8. **The kit repo isn't harnessed** (no `.yay/`), so `yayh artifact new` exits 3 here. BS-1 and this plan were written by hand. That's not a task, but `/yay:implement` will hit the same exit code (see Risks).

## Approach
- **The skill:** `plugins/yay/skills/wporg/` (new), with `SKILL.md`, `references/` and `scripts/precheck.py`, from the local skill. Scripts are called as `python3 -I "${CLAUDE_PLUGIN_ROOT}/skills/wporg/scripts/precheck.py"`.
- **One checklist with IDs:** `references/checklist.md`.
  - It indexes every rule: ID, rule, how it's checked (`precheck:<check>`, `site:<check>`, `pcp`, `manual`), and a pointer into `wporg-rules.md` or `manual-review.md`.
  - It holds the table mapping review-email headings to IDs.
  - It keeps the partner's IDs where they exist, so both teams use the same names. It adds IDs for the partner's gaps, under N (name, trademark, ownership) and Z (zip structure).
  - It drops the partner's over-strict rules: R6 "Privacy" becomes "Source code only when minified", and G5 asks for notices limited to the plugin's screens rather than every notice being dismissible.
  - The report, the fix commits (`fix(security): S12 escape stored HTML`) and the `--email` mapping all use these IDs.
- **What it reviews:**
  - edition `free` if it's in `editions`, otherwise the only edition (`--edition=` overrides)
  - zip from `yayh build zip edition=<e> version=<current>` in the checkout, then `yayh build check`; any FAIL stops the review, because the zip isn't what you'd upload
  - `--zip=<path>` reviews a given zip instead
- **The site stage:** `yayh wporg site <zip> out=<dir> [--keep] [--no-pcp]` in `lib/wporg.sh` (new), on the same throwaway site as `release ui`.
  - One TSV line per check (`PASS|WARN|FAIL|SKIP <id> <detail>`); exit 0 passes, 1 means a FAIL, 3 means it can't run.
  - **T1 Plugin Check:** installs `plugin-check` from WordPress.org into the throwaway site (it's disposable, so no question; `--no-pcp` skips it). `plugin_repo` errors are FAIL `T1`, and the full run's warnings are WARN.
  - **Q11 activation:** `wp plugin activate` output, plus one front-end and one `wp-admin/` request, must print nothing from the plugin.
  - **Q7 lifecycle:** snapshot options and tables, then activate, deactivate and `uninstall --skip-delete`. Leftover rows with the plugin's prefix are WARN, because keeping data on uninstall can be deliberate.
  - **Q10 runtime requirements:** an mu-plugin sets `$GLOBALS['wp_version']` below `Requires at least`. The admin must not fatal, and the plugin must show a notice. A fatal is FAIL, and no notice is WARN. The mu-plugin is removed afterwards.
  - **Q6 notices:** the `debug.log` scan, with the same rules as `release ui`.
- **The report** goes to `<release.bundleDir>/<slug>-wporg-<version>/review.md`, plus `site.tsv`, `precheck.txt` and `reply.md` for `--email`. That folder is gitignored and outside the zip. It's written in the shape of the local skill's email template, now with IDs.
- **Fixes and `--email`:** fixes go through a normal branch (`fix/wporg-review-<n>` from the base branch), one commit per ID with every occurrence fixed. `yayh build check` and precheck run again before the PR. The same decisions as the local skill's Step 5 are asked rather than chosen: prefix renames with a migration, removing a pro gate, tracking, name and slug, ownership, and public REST routes.
- **The release step:** `/yay:release --wporg` runs `/yay:wporg --zip=<free zip> --report-only` after the UI check, and writes the report into the bundle. An upload blocker stops the release, and review issues are listed for the developer to confirm.
- **Wiring:** the `/yay:go` routing table, the README requirements and diagram, `yayh doctor` (python3, only when `plugin.wporgSlug` is set), the CHANGELOG and the evals README.

## Tasks
- [x] T1 Bring the skill's references into the kit, with IDs and the partner's lessons — `plugins/yay/skills/wporg/references/checklist.md` (new), `plugins/yay/skills/wporg/references/manual-review.md` (new)
  - Files: `plugins/yay/skills/wporg/references/wporg-rules.md` (new), `plugins/yay/skills/wporg/references/manual-review.md` (new), `plugins/yay/skills/wporg/references/report-template.md` (new), `plugins/yay/skills/wporg/references/checklist.md` (new)
  - Copy the three references from `~/.claude/skills/wporg-plugin-review/references/`.
  - Write `checklist.md` (ID index and the email heading → ID map).
  - Add the partner's missing lessons to `manual-review.md`: Q3 `admin_body_class` and CSS leaking into WordPress screens, Q9, Q12 with its method, Q13, S12 (`phpcs:ignore` doesn't pass review, and `wp_kses_post` strips `<input>`, `<svg>` and `srcset`), B1/B2 (logged-out link, default branch equals the zip, clean-clone rebuild), and U3/U4.
  - Tag each section with its IDs, and put the ID on each issue in `report-template.md`.
  - Reuse: the local skill's three reference files, and the partner checklist's S/G/B/Q/R/T/U IDs. [risk: 1]
- [x] T2 Port `precheck.py` and add the four missing static checks
  - Files: `plugins/yay/skills/wporg/scripts/precheck.py` (new), `tests/fixtures/wporg/planted/` (new), `tests/unit/test_wporg.sh` (new), `tests/run.sh` (`--changed` maps the script to `test_wporg.sh`)
  - Add the checks:
    - `post_type_key_length` (Q9)
    - `admin_body_class` and enqueue scope, as an inventory warning (Q3)
    - `inline_script_json_hex` (S11)
    - `product_query_visibility` (Q13)
  - Add a `CHECK_IDS` map so every finding prints its checklist ID.
  - The fixture is a tiny plugin with one planted violation per new check, plus one clean file.
  - Reuse: `Report.add()` and the regex rule table in the local `precheck.py` (`:72-78`, `:145`).
  - Callers: `CHECK_IDS` → `Report.add()`; the new checks → `run()`.
- [x] T3 Pull the throwaway-site start and log scan out of `yay_release_ui` into shared helpers
  - File: `plugins/yay/lib/bundle.sh`
  - New `_yay_ui_site_up <zip> <out>`: extract, map, start and wait. It sets `site`, `folder`, `main` and `url`, and returns 3 on a SKIP.
  - New `_yay_ui_log_scan <out> <folder>`: the `debug.log` PASS, WARN and FAIL lines.
  - `yay_release_ui` calls both, and its output and exit codes don't change.
  - Reuse: the body of `yay_release_ui` (`bundle.sh:253-329`), `_yay_ui_site_dir`, `_yay_ui_port`, `_yay_ui_wpenv`.
  - Callers: `_yay_ui_site_up`, `_yay_ui_log_scan` → `yay_release_ui` (this task), `yay_wporg_site` (T4).
- [x] T4 `yayh wporg site`: Plugin Check, activation, lifecycle, runtime requirements and the debug log on the throwaway site
  - Files: `plugins/yay/lib/wporg.sh` (new), `plugins/yay/bin/yayh` (dispatch and help text), `tests/unit/test_wporg.sh`
  - The checks and their IDs are as in Approach: T1, Q11, Q7 with `--skip-delete`, Q10 through a temporary mu-plugin, and Q6.
  - Flags: `--keep` and `--no-pcp`.
  - The site stops afterwards unless `--keep`, and the mu-plugin and plugin-check leave nothing behind in the copied plugin folder.
  - Reuse: `_yay_ui_site_up`, `_yay_ui_log_scan` (T3), `yay_config_get`, and the `release` case in `yayh` as the dispatch pattern.
  - Callers: `yay_wporg_site` → `yayh wporg site` → `/yay:wporg` step 2 (T6).
- [x] T5 `yayh doctor` checks for `python3` when the repo ships to WordPress.org
  - Files: `plugins/yay/lib/doctor.sh`, `tests/unit/test_doctor.sh`
  - If `plugin.wporgSlug` is set and there's no `python3`, report `warn python3 "needed by /yay:wporg"` with the fix `brew install python3`. Otherwise report `ok` with its version.
  - Reuse: `_yay_doc` and `yay_config_get` in the doctor's existing harness section (`doctor.sh:30-40`).
- [x] T6 Write `/yay:wporg`
  - File: `plugins/yay/skills/wporg/SKILL.md` (new)
  - Adapt the local `SKILL.md`:
    - Step 1 reads `plugin.wporgSlug`, picks the edition and builds and checks the zip (Findings 1), with the repo-scan fallback when there's no package command.
    - Step 2 runs precheck and `yayh wporg site`; exit 3 means a static-only report that says so.
    - Steps 3–4 are the reviewer pass and the report (IDs, `[blocks upload]` or `[review]`, the bundle-dir location).
    - Step 5 fixes on a `fix/` branch, one commit per ID, with the existing questions.
    - `--email` mode uses `checklist.md`'s heading map and writes `reply.md`.
  - Options: `--email`, `--zip=`, `--edition=`, `--report-only`, `--no-site`, `--no-pcp`, `--keep-site`.
  - It ends with the kit's **Next** footer.
  - Reuse: the local skill's `SKILL.md` steps 3–5 and its email section; `yayh build zip`/`build check` (release SKILL step 2); `reference/asking.md`; `reference/git-conventions.md`.
  - Callers: `/yay:wporg` → the user, `/yay:go` (T7) and `/yay:release --wporg` (T7).
- [x] T7 Wire it into release, go and the README — `plugins/yay/skills/release/SKILL.md`, `plugins/yay/skills/go/SKILL.md`, `plugins/yay/README.md`
  - Files: `plugins/yay/skills/release/SKILL.md`, `plugins/yay/skills/go/SKILL.md`, `plugins/yay/README.md`
  - Release: a `--wporg` option, and a step after the UI check that runs `/yay:wporg --zip=<free zip> --report-only` into the bundle. A blocker stops the release.
  - Go: a routing row for "submit to wp.org", "is it ready for wordpress.org" and "review email from plugins@wordpress.org" → `/yay:wporg` (`--email` when they paste one).
  - README: the diagram gets `/yay:wporg` before `/yay:release`, and Requirements gets `python3` for `/yay:wporg`.
  - Reuse: the release skill's options table and step 4 layout, and go's routing table rows (`go/SKILL.md:42-43`). [risk: 1]
- [x] T8 Port the two evals to the kit's format — `plugins/yay/evals/wporg-planted-violations/` (new), `plugins/yay/evals/wporg-fix-from-email/` (new)
  - Files: `plugins/yay/evals/wporg-planted-violations/` (new: `case.yaml`, `prompt.md`, `scaffold.sh`, `graders/`), `plugins/yay/evals/wporg-fix-from-email/` (new, same layout), `plugins/yay/evals/README.md`
  - Each scaffold writes the local fixture files plus `.yay/config.json` with `wporgSlug` and a `commands.package` that zips the folder, so the skill reviews a built zip.
  - Keep the local graders' assertions (the reply grader names `reply.md` in the report folder). Add one per case: the report names checklist IDs; in the email case, each fix commit names its ID.
  - Drop `yaycheckout-real-plugin` (Findings 6).
  - Reuse: the local `evals/*/graders/*.md` and `files/`, and `evals/implement-tiny-lane/scaffold.sh` for the git and config setup. [risk: 1]
- [x] T9 CHANGELOG entry — `plugins/yay/CHANGELOG.md`
  - File: `plugins/yay/CHANGELOG.md`
  - Under `## Unreleased`: the new `/yay:wporg`, `yayh wporg site`, `/yay:release --wporg` and the doctor's `python3` check.
  - For each repo: set `plugin.wporgSlug` to opt in, and have `/yay:e2e-init` run for the site stage.
  - Reuse: n/a [risk: 1]

**Tests:** [unit] `test_precheck_new_checks` (`tests/unit/test_wporg.sh`): the four new checks flag their planted lines with IDs Q9, Q3, S11 and Q13, and stay quiet on the clean file.; [unit] `test_wporg_site_skips_without_e2e` (`tests/unit/test_wporg.sh`): no e2e setup or no Docker gives exit 3 and a SKIP line, and nothing is started.; [unit] `test_release_ui_skips_unchanged` (`tests/unit/test_release.sh`): after the T3 refactor, `release ui` still prints the same SKIP line and exits 3.; [unit] `test_doctor_python_for_wporg` (`tests/unit/test_doctor.sh`): a `warn` when `wporgSlug` is set and `python3` is hidden from `PATH`, and no line when it isn't set.; [manual] the site stage on a real Yay plugin with e2e set up: what the unit layer can't reach without Docker.

**E2E:** none

## Verify
- `./tests/run.sh wporg release doctor` → exit 0 (unit)
- `./tests/run.sh` → exit 0
- `python3 -I plugins/yay/skills/wporg/scripts/precheck.py tests/fixtures/wporg/planted --slug wporg-planted --wp-version 6.9` → Q9 (unit)
- `plugins/yay/bin/yayh --help` → wporg site
- `claude plugin validate plugins/yay` → exit 0
- `grep -q "/yay:wporg" plugins/yay/skills/go/SKILL.md` → exit 0
- `grep -q -- "--wporg" plugins/yay/skills/release/SKILL.md` → exit 0
- In a Yay plugin repo with `plugin.wporgSlug` set and e2e set up, run `/yay:wporg`. You should see:
  - a report at `release/bundles/<slug>-wporg-<version>/review.md` in the email's shape
  - every finding with an ID, a `file:line` and a fix, and blockers tagged `[blocks upload]`
  - `site.tsv` with T1, Q11, Q7, Q10 and Q6 lines
  - the repo's working tree unchanged (`git status` clean)
- In the same repo, `/yay:release --bundle --wporg` → the bundle has `wporg/review.md`, and a planted blocker (e.g. `Stable tag` ≠ `Version` in a scratch branch) stops it with that ID.
- In the same repo without e2e set up, `/yay:wporg` → a report headed "static only (no site: run /yay:e2e-init)" with no site lines, and the skill doesn't fail.
- After `yayh wporg site <zip> out=<dir>` → `wp-env` for the release site is stopped, and `<site>/plugin/<slug>/` has no `mu-plugins` or `plugin-check` leftovers.
- `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case wporg-planted-violations --runs 1 --ablation none --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish` → all graders pass. Same for `wporg-fix-from-email`.

## Risks
- **The T3 refactor breaks `/yay:release`'s UI check.** The SKIP test covers only the no-Docker path, so run `/yay:release --bundle` once on a real plugin before merging. To roll back, revert T3. T4 is the only other caller.
- **Plugin Check isn't reachable from the throwaway site** (offline, or wordpress.org is down). It gives SKIP `T1` with "run Tools → Plugin Check by hand", and the report says the gate didn't run. It never passes silently.
- **Two skills trigger on the same words.** The local `~/.claude/skills/wporg-plugin-review` stays installed and will also fire on "submit to wp.org". Open: should the user delete the local skill once `/yay:wporg` ships? (default: the kit release note tells them to; the plan doesn't touch `~/.claude`). It's recorded here because `yayh backlog` can't run in this unharnessed repo.
- **`yayh artifact`, `plan` and `verify` exit 3 in this repo** (Findings 8). `/yay:implement P-1` may not be able to tick tasks through `yayh`. If a `yayh plan tick` or `fm` call fails, tick the plan checkbox by hand.

## Build notes
This is the yay kit repo itself, not harnessed (no `.yay/config.json`), so `yayh artifact`/`backlog` commands may exit 3. The checks are `./tests/run.sh` (full suite before the last commit) and `claude plugin validate plugins/yay`, not `commands.*`. Follow `.claude/skills/kit-ship/SKILL.md` for branch naming, conventional commits and the CHANGELOG `## Unreleased` entry, but don't merge: autopilot only opens the PR, and the repo uses merge commits, never squash. The skill's source is `~/.claude/skills/wporg-plugin-review`: copy from it, never modify or delete it.
- **The rulebook goes stale.** `wporg-rules.md` keeps its dated sources section, and `--email` mode adds any heading it can't map to `checklist.md` in the same fix branch.
