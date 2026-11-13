---
id: BS-1
title: WordPress.org submission check
status: decided
from:
decision: A. /yay:wporg in the kit
created: 2026-11-13
---
# BS-1 WordPress.org submission check

## Problem
Before a Yay plugin's free edition is submitted to WordPress.org (a new plugin, or an update during review), someone has to find **every** issue the Plugins Team will raise. Each review round costs 7–10 business days, and the email shows only examples, so a partial fix costs another round.

We have two existing sources:

1. **The partner checklist** (`YayCommerce/YayAutomation@develop:.claude/docs/context-wporg-release-checklist.md`). It has 54 manual items with IDs (S1–S13 security, G1–G7 guidelines, B1–B4 build, Q1–Q13 quality, R1–R6 readme, T1–T3 tools, U1–U4 upload).
2. **A local skill, `~/.claude/skills/wporg-plugin-review`**. It's user-level, not in the kit. It has:
   - `precheck.py` (823 lines), which approximates the Plugin Check upload gate and lists an inventory
   - `run_plugin_check.sh`
   - a 664-line rulebook, a manual-review pass and a report shaped like the review email
   - fix mode and a reply draft
   - 3 eval cases

### The partner checklist: what's good
- **Stable IDs, plus a table mapping review-email headings to items.** This is the most useful part for round 2: paste the email and know exactly what to re-check.
- **Lessons from real rounds that generic guides miss:**
  - S11: `JSON_HEX_TAG|AMP` in inline scripts
  - S12: a `phpcs:ignore` comment doesn't pass review, and `wp_kses_post` strips `<input>`, `<svg>` and `srcset`
  - S13: `serialize_block_attributes()`
  - Q10: requirements checked at runtime, tested by forcing an old `$wp_version`
  - Q12: bounded query cost (`_prime_post_caches`, `clone` on `WC_Data`, `SAVEQUERIES` at two sizes)
  - Q13: catalog visibility
  - Q9: post type keys of 20 characters or fewer
  - Q3: `admin_body_class` and CSS leaking into the WordPress admin
- **B1/B2 treats public source as something to verify.** It means opening the link logged out, checking that the default branch equals the zip, and rebuilding from a clean clone.
- **U3/U4 reply etiquette**: no changelog, fix every occurrence, and push back on AI false positives with an example.

### The partner checklist: what's bad
- **It's all manual.** That's 54 items of hand-run greps, and nothing records what passed.
- **The greps are noisy and miss code.**
  - Most search only `includes/`, so they skip the main file, `templates/` and `src/`.
  - They hard-code `yourprefix` and `your-slug`.
  - S4 `echo \$` matches already-escaped output.
  - G1 `license` matches the GPL text in every zip.
- **It checks the repo, not what ships.** Only G1 and B4 look at the zip, but reviewers see only the zip, so Pro code that the build removes gets flagged wrongly.
- **Nothing shows what blocks the upload.** T1 (Plugin Check, the actual upload gate) is item 46 of 54, and there's no blocker-vs-review severity.
- **A few rules are wrong or too strict.**
  - R6 requires a "Privacy" section, and "Source code" even when nothing is minified.
  - G5 requires every notice to be dismissible.
  - Q4 offers "move it to `init`" as if that were needed.
- **Gaps:**
  - name, trademark and ownership (guideline 17) beyond the "WooCommerce …" prefix
  - purpose-level rejections
  - zip structure (one top folder, `__MACOSX`, 10 MB)
  - the `Update URI` header, a short description of 150 characters or fewer, and contributors that are WordPress.org usernames
  - no output format and no tie to a release, so it drifts

### The local skill vs the checklist
The local skill already automates or documents nearly all of S, G, B, R and T, and does U3/U4 (`grep` per item: only catalog visibility, the 20-character post type key and `admin_body_class` are missing outright). What it lacks:
- the **heading → ID index**
- **runtime checks** on a real site: Q6 notices, Q7 lifecycle, Q10 runtime requirements, Q11 clean activation, T3 clean install, U1 install the real zip. It guesses the build by reading workflows and scripts.
- distribution: it lives in one person's `~/.claude`, so teammates and the partner team don't get it.

## Constraints
- **Review what ships.** The free zip has to come from the repo's real package step. The kit already has this in `yayh build zip edition=free` and `yayh build check` (one top folder, dev files, `package.forbidden` per edition, version and Stable tag). `plugin.wporgSlug` (`reference/config.md:16`) says which repos ship to WordPress.org.
- **A real site is available.** `yayh release ui` (`lib/bundle.sh:232`) already installs the built zip in a throwaway wp-env site. Plugin Check, a `WP_DEBUG` activation and a lifecycle check can run there. It needs `/yay:e2e-init` to have run; without it the check exits SKIP (`bundle.sh:268`), so a fallback path is required.
- **Dependencies.** The kit's runtime is bash plus one JSON engine. `python3` is only a fallback (`lib/common.sh:57`), so `precheck.py` would add a new hard dependency, or a port.
- **Read-only by default.** Fixes go through the normal branch, worktree and PR flow (`/yay:fix`, `/yay:implement`), never into the zip (release SKILL "Never hand-edit a zip").
- **The rules change.** WordPress.org updated its FAQ and scanner in 2024–2026, so the rulebook needs a dated sources section and a way to add each review email's lessons.
- **Evals.** New kit skills ship with eval cases (`plugins/yay/evals/`, 23 today), and the local skill's 3 cases can come along.

## Options

### A. Bring the local skill into the kit as `/yay:wporg`, harness-aware, with the partner's lessons merged in
- **How:**
  - Move `wporg-plugin-review` into `plugins/yay/skills/wporg/`, keeping the rulebook, manual pass, report template and evals.
  - Replace its "guess the build" step with `yayh build zip edition=free` and `yayh build check`. Use `wporgSlug` as the slug.
  - Add a runtime stage on the `release ui` wp-env site:
    - Plugin Check `plugin_repo` (the T1 gate)
    - `wp plugin activate` with `WP_DEBUG` on, expecting no output and no log lines (Q11, Q6)
    - deactivate, uninstall and look for leftover options and tables (Q7)
    - force an old `$wp_version` and confirm the plugin stops (Q10)
  - Merge in the partner's unique lessons: S11–S13, Q3, Q9, Q10, Q12, Q13, B1/B2 logged out, U3/U4. Give every rule a stable ID, so the report, the heading → ID map and the fix commits all use the same ID (e.g. `fix(security): S12 …`).
  - Modes:
    - `/yay:wporg`: pre-review the free zip and write the email-shaped report
    - `--email`: paste a review email, map its headings to IDs, find every occurrence, open one `/yay:fix`-style branch and draft the U3 reply
  - `/yay:release` gets an optional `--wporg` step when `wporgSlug` is set.
- **Pros:**
  - Reuses about 1,800 lines of work that's already been evaluated.
  - Reviews the real zip on a real site, which is the biggest gap in both existing sources.
  - The whole team gets it through the marketplace.
  - Fixes follow the normal PR flow.
- **Cons:**
  - The largest of the three.
  - `precheck.py` brings Python into the kit (check it in `yayh doctor`, or port the hottest checks to bash later).
  - The runtime stage depends on the e2e/wp-env setup.
  - It only fits harnessed repos, so the partner team would need the harness or a standalone fallback.
- **Risks:**
  - The rulebook goes stale. Mitigate with a dated "sources" section, and add each new review email's new heading to the map as part of `--email`.
  - The runtime stage is slow. Make it skippable with `--no-site`, and mark the report "static only".
- **Size:** L

### B. Keep it a standalone, user-level skill and merge in the partner's checklist
- **How:**
  - Leave `wporg-plugin-review` where it is, or publish it as its own small plugin or marketplace.
  - Add the partner's missing items to `manual-review.md` and `precheck.py` (catalog visibility, the 20-character post type key, `admin_body_class`, the Q10 runtime pattern).
  - Add stable IDs and the heading → ID table to `report-template.md`.
  - Offer a runtime pass only when the user points at a site (`run_plugin_check.sh` already takes a WordPress root).
- **Pros:**
  - Small.
  - Works on any plugin, Yay or not, harnessed or not, including the partner's YayAutomation repos.
  - No new dependency in the kit.
- **Cons:**
  - It keeps guessing the build, so it can review the wrong files.
  - The runtime checks stay optional and manual.
  - The kit's release flow never calls it.
  - It gets to teammates only if they install it separately.
- **Size:** S–M

### C. A checklist as data plus a thin `yayh wporg check`, gated in `/yay:release`
- **How:**
  - Write a kit reference `reference/wporg-checklist.md` in the partner's style (IDs, How, heading map), with the fixes from "what's bad" above.
  - Automate only the machine-checkable IDs in bash, as `yayh wporg check <zip>`, next to `build check`: headers, readme, Stable tag, `Update URI`, ABSPATH, forbidden functions, `JSON_UNESCAPED`, remote URLs, zip structure, post type key length, `load_plugin_textdomain`.
  - `/yay:release --wporg` runs it, plus Plugin Check in the `release ui` site, and puts the remaining judgment items in the bundle as a checklist for a human to tick.
  - Drop the local skill.
- **Pros:**
  - No Python.
  - A deterministic, fast gate that fits the release step.
  - Small enough to unit-test in `tests/`.
- **Cons:**
  - Throws away the local skill's precheck and evaluated reviewer pass.
  - The judgment items (trialware, tracking, prefixes, trademarks, escaping in context), which cause most extra rounds, go back to a human with a checklist, which is the partner doc's weakness.
  - No email-shaped report, and no fix or reply mode.
- **Size:** M

## Recommendation
**A. Bring the local skill into the kit as `/yay:wporg`.**

Both existing sources are strong in different places, and each one's weakness is the other's strength:
- The local skill is the better reviewer. It automates the gate, reads entry points and trialware like a human reviewer would, writes the email-shaped report and drafts the reply, and it already has evals.
- The partner checklist holds the hard-won WooCommerce lessons and the ID/heading map that make round 2 fast.

Neither reviews the **built free zip on a clean site**, and that's exactly what the kit already knows how to produce (`build zip edition=free`, `release ui`). A turns that into the T1/T3/Q6/Q7/Q10/Q11/U1 checks, which neither source does today. B is the cheaper step that still works if we want the tool outside the harness. Doing B's merge first, as task 1 of A's plan, loses nothing.

**What would change my mind:**
- If the partner team (YayAutomation) must use it without the Yay harness, keep B's standalone skill as the engine and make `/yay:wporg` a thin wrapper that supplies the zip and the site.
- If Python in the kit is a hard no, choose C's bash gate for the static checks and keep A's skill text for the reviewer pass.

**Decided (2026-11-13):** A.
- **Kit only.** The partner team doesn't need a harness-free version, so there's no standalone engine.
- **`python3` is a kit dependency.** `precheck.py` comes over as it is, and `yayh doctor` checks for `python3`.

## Open questions
- Should the runtime stage install Plugin Check from WordPress.org into the throwaway site automatically (network access, but disposable), or only when asked?
- Where does the report live? Options: in the release bundle (`release/bundles/<v>/wporg-review.md`, gitignored), in `docs/releases/`, or next to the repo as the local skill does today.
- Who owns the rulebook's freshness, and should every review email received add its new headings to the map automatically?
- What happens to `~/.claude/skills/wporg-plugin-review` afterwards: delete it, or keep it for non-Yay plugins?
