# yay kit changelog

`/yay:harness-update` reads this file to tell a repo what changed between its recorded kit version and the installed one. Each entry lists new skills, config keys, template changes and behavior changes.

## Unreleased (0.5.0)
- **`/yay:go`: one front door.** With no argument it shows `yayh status` and runs or offers the next step. With an id, it runs `yayh next <id>`. In plain words ("fix the coupon bug", "build R-12", "ship it, dry run"), it routes to the right `/yay:*` skill with the options the words imply, says which one in one line, and hands off. It never starts `/yay:harness-init`. The managed CLAUDE.md block lists it first. (Plugin skills are namespaced, so a bare `/yay` isn't possible.)
- **Shorter skills; the rare paths load only when they're used.** Three skills move their less-used paths to reference files, which they read only when the matching option is given:
  - `/yay:roadmap`: multi-agent, publish, Trello and legacy conversion go to `reference/roadmap-extras.md` (141 → 107 lines).
  - `/yay:release`: `--bundle`, `--tag-only` and `--hotfix` go to `reference/release-modes.md` (166 → 140).
  - `/yay:implement`: planning a requirement and the tiny lane go to `reference/implement-unplanned.md` (152 → 132).

  Nothing in what the skills do has changed.
- **Correctness review before every PR: `yay:bug-reviewer`.** A new read-only agent runs next to `yay:code-reviewer` in `/yay:implement` (step 4.5), `/yay:fix` (every fix) and autopilot builds. It gets only the diff, the base branch and the plan's Goal (for a fix, the symptom and root cause), and checks:
  - logic
  - security: nonce and capability on every handler, a REST `permission_callback`, sanitize in, escape out, `$wpdb->prepare`
  - compatibility: HPOS through the WooCommerce CRUD, block and classic checkout, the PHP floor
  - editions: Pro code reaching Free
  - data: defaults, upgrades, uninstall
  - whether the diff meets the goal

  Each finding has a severity (`blocker`, `bug` or `risk`), `path:line`, and the input that fails. A blocker is fixed before the PR, or the PR opens as a draft with the blocker first. Everything else is fixed or answered. The PR template's "Reuse and comments review" section becomes **Review**. Both reviewers use the `review` model step.
- **Fixes from the yaycheckout pilot (R-10):**
  - `yayh status` showed nothing before the first sprint started, or between two sprints. The next sprint now counts as current.
  - `yayh plan check` warned that a note "follows the default" even when the plan answers it with a `Settles: BL-<n> …` line. It no longer warns about those notes.
  - `/yay:roadmap` scheduled around dependencies but didn't record them. It now writes `depends=` on items, which autopilot and `yayh status` order by.
- **Words work as options.** A new asking rule: plain words in a `/yay:*` argument that name an option mean that option (`/yay:roadmap status`, `/yay:release dry run`).

## Unreleased (0.4.0)
- **`yayh status` and `yayh next`: where you are and what's next.** `yayh status` lists every piece of work in flight, across all worktrees, most urgent first: this branch's work (`here`), work in progress (`active`), slipped roadmap items, critical and high bugs, the current sprint, then other bugs, plans not tied to a listed item, and brainstorms with no plan yet. Each row has its stage and the one command that moves it on (`/yay:implement P-4 --continue`, `/yay:plan --from=BS-3`, `/yay:fix B-7`; a finished branch gets its push and PR commands). `yayh next [ID]` prints only that command for one `R-`, `P-`, `BS-`, `B-` or `UX-<n>`. When that work is finished, it prints the most urgent other work. With no ID, it prints this branch's work or the top row. The managed CLAUDE.md block mentions both commands.
- **Sessions start where the work stands.** The SessionStart hook adds one line when the branch belongs to a plan or bug: `yay: this branch is P-4 "<title> · 3/7 tasks" (in-progress). Next: /yay:implement P-4 --continue`. On any other branch, it lists the 3 most urgent items from `yayh status`, each with its command.
- **Every skill ends with one next step.** A new asking rule (loaded at session start): a `/yay:*` report ends with `Next: <command>` from `yayh next <id>`, plus at most 2 alternatives. Replying "go", "next", "continue" or "yes" runs it. Brainstorm, debug, design, plan, implement, fix, roadmap, autopilot, test and e2e point their report at this rule.
- **Hooks hint about commit style instead of blocking.** After a commit, only a header the changelog can't read (not `type(scope): summary`) still blocks. A header over 72 characters, a final period, a scope outside `git.scopes` and a branch name that isn't `<type>/<slug>` now come back as a non-blocking hint, and the commit stands. These are still blocked: commits on the base branch, `--no-verify`, `yay:debug` leftovers, tags outside `/yay:release`, and edits to generated and kit-owned files. `yayh git commit-check` is still strict, for CI. New `lib/git.sh` checks: `yay_commit_shape` (blocking) and `yay_commit_style` (hints).
- **Implement adapts the plan instead of stopping.** When the code forces a change that keeps the plan's goal, scope and customer-visible behaviour (a moved file, a renamed hook, an equivalent approach, one more file), `/yay:implement` and autopilot builds edit the task text in the same commit and list the change under **Decided**. They stop to ask only when the scope or what customers see would change. The workflow rule "Plans are the contract" now says the same thing.
- **Three lanes: tiny, small, standard.** Each change gets as much planning as it needs.
  - **Tiny** (one or two files, about 30 lines, no customer-visible decision, no data change): `/yay:implement "<change>"` builds it with no plan file. The PR holds a one-line Goal and the Verify checks.
  - **Small** (an S item, one area, about 3 tasks): a plan with `lane: small` and only Goal, Tasks and Verify (template `artifacts/plan-small.md`, `yayh artifact new plan … lane=small`). `yayh plan check` skips the Reuse, Tests and E2E checks for it.
  - **Standard:** the full plan, as before.

  `/yay:plan` and `/yay:implement` pick the lane and list it under **Decided**, and `--lane=` overrides it. The workflow rule "Start from an artifact" becomes "Plan as much as the work needs". New optional plan key: `lane`.

## 0.3.0
- **Model and effort per step.** Each agent step can run on its own model and effort, set in `.yay/config.json` (or `.yay/local.json`) under `models`:
  - **Tiers:** `veryfast` (Sonnet, medium), `fast` (Opus, low), `balanced` (Opus, medium) and `deep` (Opus, high).
  - **Steps:** `scout`, `web-research`, `feasibility`, `revise`, `resolve`, `review`, `hypothesis`, `portfolio-research`, `cowork`, `prepare`, `implement`, `synthesis` and `task`. Each takes a tier, `inherit` (the session's model), or an inline `{ model, effort }`. The defaults are: scout, web-research and feasibility use `veryfast`; revise and resolve use `fast`; synthesis uses `deep`; task runs inline; every other step uses `balanced`.
  - **Fallback:** whatever can't be determined runs on Opus at medium effort (`balanced`), with a warning, and the run doesn't fail. That covers an unknown step, tier or task tag, a bad size, a tier missing its model or effort, and a workflow run without the table.
  - **Size bump:** `prepare`, `implement`, `review` and `task` move one tier down for an S roadmap item and one up for an L item (`models.sizeBump`).
  - **Commands:** `yayh model resolve <step> [--size] [--tier] [--plan] [--task]` and `yayh model table [--json]`. `yayh config validate` checks the block.
  - **Where it applies:** every skill that spawns an agent passes the resolved model and effort. `/yay:autopilot` and `/yay:roadmap --multi-agent` pass `yayh model table --json` to their workflows, which route each `agent()` call.
  - **Per-task delegation:** a plan task may end with `[tier: veryfast]` or `[tier: deep]`. `/yay:implement` then delegates that task to a subagent on that tier, and verifies, ticks and commits it itself. Untagged tasks still run inline. `yayh plan check` rejects unknown tiers.

  New optional config keys: `models.tiers`, `models.steps`, `models.sizeBump`. Contract: `reference/models.md`.

## 0.2.0
- **Optional Trello sync: `/yay:roadmap --trello` and `/yay:plan --trello`.** Off unless the flag is given. The roadmap gets one Trello list per sprint (plus `Later`) and one card per `R-<n>` item, due at the sprint's end; shipped cards are marked done and dropped ones archived. A plan's tasks become a checklist on its roadmap item's card, or on a new `P-<n>` card in `trello.list`. Card URLs are saved (`- trello:` on the item, `trello:` in the plan's front-matter), so re-runs update cards instead of duplicating them. New optional config keys `trello.board` and `trello.list`; with no board set, the run asks once and saves it to `.yay/local.json`. Without the Trello MCP server connected, the run says so and finishes normally. Contract: `reference/trello.md`.
- **`/yay:design`: a simple UI/UX before the plan.** For a change people will see (an admin screen, tab or modal, a product/cart/checkout/My Account element, a block, an email), it writes `docs/designs/` `UX-<n>`. The design is grounded in `yayh e2e surfaces` and the plugin's nearest existing screen and components. It holds the job, where the UI lives, the flow, an ASCII wireframe per screen, every state (empty, saving, success, error, no permission, Pro seen in Free), the copy, accessibility, the decisions and the acceptance checks. A simplify review cuts fields, screens and settings the job doesn't need. `--mockup` adds a self-contained HTML preview in `.yay/designs/` (new `.gitignore` line). `--quick` does a one-screen pass, and `--check` reviews a design.
  - `yayh design check` validates a design, `yayh artifact new design` creates one, and `yayh id next UX` gives its id.
  - Plans gain `design: UX-<n>`. `/yay:plan` uses or writes a design for UI work: UI tasks name the screen they build, and the Acceptance checks go into Verify. `/yay:implement` builds to the design and updates it when the code forces a change.
  - The managed CLAUDE.md block lists `/yay:design`.
- **Parked decisions and later work are picked up again.** Backlog files gain `kind: idea | decision | deferred`, plus `affects:`, `default:`, `decision:` and `settled:`. Files without `kind` are ideas, as before.
  - A **decision** note is a call that couldn't be made while planning or building. The work builds its `default:` and never stops for it.
  - A **deferred** note is work left for later: out of scope, a follow-up, a nice-to-have found while building.
  - `/yay:plan`, `/yay:implement`, `/yay:fix` and `/yay:autopilot` write these notes instead of stopping or burying the point under "Open:" risks or a report line.
  - Before they work on a plan, they run `yayh backlog open --for=<id>`, which matches the plan, its roadmap item and its source, across every worktree. They settle what can now be settled into the plan (`yayh backlog settle BL-<n> decided "…" | planned P-<n> | dropped "…"`). A decided answer that differs from a default already built becomes a task.
  - `yayh plan check` warns about each open note that touches the plan.
  - Autopilot's decision sheet also offers the open decision notes on its items.
  - `/yay:roadmap` reads deferred notes as evidence.
  - The PR template gains an "Open decisions and later work" section, and the workflow rules a "Park what can't be settled now" rule.
- **Unit, integration and JS tests: `/yay:test-init` and `/yay:test`.** Three layers:
  - **Unit:** PHPUnit 9.6 + Brain Monkey, with no WordPress (`tests/php/unit`).
  - **Integration:** the WordPress (and WooCommerce) test suite in wp-env's **tests** site, which has its own database on port+1. That way the e2e site's data is never wiped (`tests/php/integration`, `wp-env run tests-cli`).
  - **JS:** Vitest, Jest or wp-scripts (`tests/js`).

  `/yay:test-init` scouts the code with `yay:test-scout` agents, scaffolds or adopts, installs the dev packages, and writes baseline tests for the riskiest units. Each baseline test must pass twice and fail when the code is broken. It also writes a **Coverage** table in `docs/knowledge/testing.md`. New commands: `yayh test status|detect|scaffold|run|list`; `run all --id=P-4` runs every configured layer and skips integration when its site is down. New config keys: `commands.test-unit`, `test-integration`, `test-js` and `tests.php|js|jsRunner`. `yayh test scaffold` turns on `testsEnvironment` in the e2e package's `.wp-env.json`. Contract: `reference/testing.md`.
- **The agent picks the test layer for each task.** It follows a ladder in `reference/testing.md`: unit → integration → js → e2e → manual, stopping at the cheapest layer that proves the risk, with two layers only for two named risks.
  - `/yay:plan` writes `**Tests:**` items as `[unit] name (file) — risk`. `yayh plan check` warns about an item with no layer, and `--tests=ask` becomes `--tests=auto` (no approval round unless the repo's rules require one).
  - `/yay:implement` writes each task's tests in that task, and runs `yayh test run all` at the end.
  - `/yay:fix` and `/yay:debug` put the regression test at the layer of the root cause.
  - `/yay:release` runs `yayh test run all`.
  - The workflow rule "Tests only when they earn their keep" is now "Test each risk at the cheapest layer that proves it".
- **`/yay:build` is gone; `/yay:release` builds and ends in a bundle.** Every mode leaves `release/bundles/<slug>-<version>/` (`release.bundleDir`): the zips, `MANIFEST.txt` (commit, size, file count, sha256), a tester `README.md` and `ui/` screenshots. `--bundle` makes a test bundle for QA as `<next>-rc.<n>` from HEAD, with nothing committed. "Build the zip" / "package it" now trigger `/yay:release`.
- **Release gate (`yayh release check`):** version files agree and equal the release, it's newer than the last tag, the readme's **Stable tag** matches (`release.stableTag: trunk` to keep trunk), the **changelog** entry exists without placeholder text, and the release notes exist.
- **Bundle size (`yayh release size`):** compared with the last release that recorded its size (`zip_bytes_<edition>` in `docs/releases/<v>.md`, written by each release). A size or file-count change over 25% / 1 MB, or a file over 2 MB, is UNUSUAL and the release asks about it (`release.sizeChangePct`, `sizeChangeKb`, `largeFileKb`).
- **Plugin links check (`yayh release ui`):** installs the **built zip** in its own throwaway wp-env site (never the e2e site, which mounts the source), activates it on the Plugins page, and follows every **action link** (Settings, Upgrade…) and **meta link** (Docs, Support…) of the active plugin: internal ones must load without an error (heading and screenshot recorded), external ones are requested with redirects followed (404/410/5xx fail). It writes `links.tsv` (text, URL, status, where it lands), then deactivates the plugin and scans `debug.log`. Needs `/yay:e2e-init` and Docker; without them the links come from the code and are clicked by hand. **Every release asks the developer to confirm each link goes where it should** (and any unusual size) before committing; a non-interactive run stops there.
- New `.gitignore` line `.yay-release/` (the UI check's temporary Playwright files).
- **PRs by default:** `/yay:implement`, `/yay:fix`, `/yay:autopilot`, `/yay:roadmap`, `/yay:release` and `/yay:e2e-init` now push the finished branch and open its PR (assigned to you) without asking. `--no-pr` (or `--no-push`) keeps the work local and prints the commands; `--pr` is still accepted and does nothing. No `origin` remote or no logged-in `gh` never fails the work: it finishes locally and says why. Tags still stay local: `/yay:release --push-tag` pushes them.
- **Browser tests: `/yay:e2e-init` and `/yay:e2e`.** `/yay:e2e-init` scouts the whole plugin first (`yayh e2e surfaces` lists every admin page, shortcode, block, My Account endpoint, cart/checkout and product hook, email and more; `yay:e2e-scout` agents map them to flows with cited locators), writes a **Flows** table in `docs/knowledge/e2e.md`, seeds the site from what the flows need, and writes baseline specs for the critical browser-only flows (`--max-specs`, default 6), each proven to pass twice and to fail when its precondition is broken. Bugs it finds become `B-<n>` with the test marked `test.fail`. Playwright against a wp-env site, one per checkout. Each worktree gets its own port, so parallel branches never share a database. `yayh e2e status|detect|scaffold|port|url|env|run|specs|surfaces|cli`. `yayh e2e scaffold` writes the starter `tests/e2e/` package (config, seed script, admin and customer logins, `wp()` WP-CLI fixture, smoke spec) and `.github/workflows/e2e.yml`. It only fills gaps, and it adopts an existing Playwright setup. New config keys: `e2e.dir`, `e2e.port`, `e2e.baseUrl`, `e2e.wpEnvArgs`, `commands.e2e`, `e2e-install`, `e2e-start`, `e2e-stop`, `e2e-reset`. Contract: `reference/e2e.md`.
- **Targeted e2e in the flow:** plans gain an `**E2E:**` line (browser-only flows, usually none; `yayh plan check` warns when it's missing in a repo with e2e). `/yay:implement` writes and runs specs tagged `@P-<n>` (Finish step 2; the later Finish steps are renumbered). `/yay:fix` writes an `@B-<n>` regression spec only for UI-only bugs, fail-first. `/yay:release` runs the full suite in preflight: a product bug blocks, flakes don't. A new workflow rule says so, and a new knowledge doc, `docs/knowledge/e2e.md`, holds the details.
- **`/yay:implement "<requirement>"`:** implement also takes a requirement, or an `R-`/`BS-`/`B-<n>` with no plan yet. It reuses a plan made from that source if one exists; otherwise it writes one through `/yay:plan` (grounded, `plan check` clean, `--split` when it's big, with the first slice built), then builds it. Planning's hard questions join implement's single round, so it's still one round at most.
- **`/yay:autopilot`: plan many items, then build them all.** Takes a queue (`R-<n>…`, `--sprint=current`, `--ready`) through brainstorm, plan and implement with **one decision sheet** for the whole run instead of a question round per item. Prepare brainstorms and plans every item and returns only the hard calls; the sheet asks the top ones once (`--no-ask` takes every recommendation); build then runs unattended through `workflows/autopilot.js`: one worktree and branch per item, one at a time or `--parallel=N`, dependents stacked on their dependency's branch, `yay:code-reviewer` on each, PRs only with `--pr`. A blocked item stops only itself and its dependents. The run sheet goes to `.yay/runs/` (new `.gitignore` line). Re-running resumes.
- **`yayh roadmap queue`:** the build order for a scope (stage, artifact, in-run `after`, outside `waits`), following `depends:`; cycles fail.
- **Ids are safe across worktrees and parallel agents:** `yayh id next` also counts artifacts in every other worktree (carried plans kept their ids, but used to be reissued), and `yayh artifact new` takes a repo-wide lock.
Code quality (reuse existing code, leave comments alone) and less blocking (ask less).
- **Ask less, block less:**
  - **At most one question round of 1–3 questions, and only the hardest ones:** decisions that are expensive to undo, or that only the user can make. Claude decides everything else and lists it under **Decided** in the report, PR or artifact, so the user can overrule it. Open, non-blocking points go in the artifact for the next checkpoint.
  - **No standalone confirmations:** no "mark it ready?" (plan check passing means ready), no version confirmation (only a major bump or a conflict is asked), no "proceed with the draft?", no approval step before writing the roadmap, and no end-of-run "push?". Work is committed locally, and the report ends with the push and PR commands, unless `--pr` was given.
  - Deletes, overwrites, live-site writes, pushes and tags still need a yes.
  - The rules are in `reference/asking.md`, which the SessionStart hook loads next to the code rules.
- **Code rules for every session:** the SessionStart hook loads `reference/code-rules.md` into every yay repo session. It covers searching before creating, calling existing helpers, small diffs, and a WPCS-compatible comment policy: docblocks yes; no new, grown or reworded comments; nothing explaining other files; no change-log comments. The rules ship with the plugin, so `/yay:harness-update` isn't needed.
- **Plans:** each plan task has a `Reuse:` line (`yayh plan check` warns when it's missing, or when `none` has no reason). `/yay:plan`'s self-review looks for re-implementations.
- **`yayh code find|similar|index|new`:** a search over PHP and JS/TS classes, functions, methods and consts, matching names and docblock summaries.
- **Knowledge:** a new core doc, `docs/knowledge/helpers.md` (the reuse map), written by `/yay:knowledge-init` and kept current by `/yay:knowledge-update`. The project block's "Read when" points at it before adding any function.
- **`yayh review diff [base] [--plan=P-n]`:** flag-only findings. Kinds: `similar-exists`, `comment-edited`, `comment-grown`, `comment-heavy`, `comment-elsewhere`, `comment-changelog`, `docblock-prose`, `outside-plan`.
- **`yay:code-reviewer` agent:** a read-only reviewer for reuse and comments. `/yay:implement` (step 4.4, `--no-review` to skip) and `/yay:fix` run it before the PR. Each finding is fixed, or answered in the PR's new "Reuse and comments review" section.
- **PostToolUse hint hook (`hint-edit.sh`):** after an edit, a non-blocking note when a new function looks like an existing one, an edit only changes comments, existing comment lines were rewritten, or several inline comments were added.
- **Fix:** `yayh plan check` read an unticked task's ID as `]`.

## 0.1.0
- First version: `/yay:harness-init` and `/yay:harness-update`.
- `yayh` helper CLI: config, IDs, slugs, front-matter, manifest, git, harness.
- Kit files: the managed CLAUDE.md block, `.claude/rules/yay-{workflow,git,wordpress}.md`, `.claude/settings.json` (merged with `.yay/settings.extra.json`), the PR template, the docs skeleton, and `.gitignore` entries.
- Git conventions: `<type>/<slug>` branches with no owner prefix. PRs are assigned to their owner.
- `/yay:knowledge-init` and `/yay:knowledge-update` write and maintain the CLAUDE.md project block and `docs/knowledge/`. The `yay:knowledge-scout` agent explores areas in parallel. `yayh knowledge check|stale|stamp` keeps the docs verifiable: paths and links must exist, there's a 90-line budget for the block, and drift is tracked through `covers` and `updated_ref`.
- `/yay:brainstorm`, `/yay:plan`, `/yay:implement`, `/yay:debug` and `/yay:fix`. New artifacts are created untracked and carried into the work's worktree (`yayh artifact new|resolve|list|carry`, `yayh plan tasks|tick|check`, `yayh id conflicts`). The `yay:hypothesis-checker` agent checks bug hypotheses in parallel. `yayh run <command>` honours `.nvmrc`, and `yayh debug markers` finds leftover instrumentation.
- Config: per-developer `.yay/local.json` (gitignored) overrides the shared config. `site.wpPath` is derived when the repo sits in `wp-content/plugins/`. `id next` also counts IDs on the base branch.
- `/yay:changelog`, `/yay:build` and `/yay:release` (prepare, `--tag-only`, `--hotfix`).
  - `yayh version current|list|check|set|tested`.
  - `yayh changelog collect|suggest|baseline|style|write|entry`. The baseline is the last tag, a release commit, or the version's first appearance, in which case the skill asks.
  - `yayh build zip|check`: one top folder, dev files, per-edition `package.forbidden`, version and Stable tag, `php -l`, repo `checks`.
  - `package.output` may map editions to globs.
  - `config validate` rejects edition-keyed maps that use unknown editions.
  - `yayh git merged-worktrees`.
- `/yay:roadmap`: plan or re-plan dated sprints against capacity and freeze windows, `--status` (read-only progress, slipped items, open bugs, status drift), quick `--add`/`--move`/`--drop`, `--multi-agent` portfolio co-planning (`workflows/roadmap-portfolio.js`, one owner agent per plugin), and `--publish` as a private page.
  - `yayh roadmap list|get|set|add|move|sprints|current|check|status|links|peers`.
  - `/yay:implement` and `/yay:release` set item status through `yayh roadmap set`. The `roadmap` commit scope is always allowed.
- Hardening:
  - skill descriptions lead with their trigger phrases and stay under 420 characters, so the skill listing never cuts them off
  - `yayh … --help` anywhere prints usage and changes nothing, and artifact or roadmap titles that look like options are rejected
  - `/yay:release` runs `commands.test` first (lint only warns), and a hotfix release tags locally without asking
  - an eval suite in `evals/` (5 cases with a no-plugin baseline)
  - `ONBOARDING.md` for the team
- Reliability: no `| head` or `| grep -q` pipes anywhere (a lint test enforces it), because they fail under `pipefail`. The PHP engine now prints nothing for empty arrays.
- Hooks: they block edits to generated and kit-owned files, commits on the base branch, `--no-verify`, `yay:debug` leftovers, and tags made outside `/yay:release`; they check commit messages and branch names; at session start they flag a harness older than the kit.
