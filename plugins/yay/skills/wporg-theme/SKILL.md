---
name: wporg-theme
description: Pre-review a Yay WordPress theme's zip the way the WordPress.org Themes Team reviews Theme Directory submissions (Theme Check, the required items, a clean-site run and a reviewer pass), write the result as their Trac ticket review with a checklist ID, file:line and fix on every finding, then fix on a branch. Use in a theme repo (plugin.kind = theme, e.g. Brandy, WPShadcn) when the user says "submit the theme to wp.org", "is the theme ready for wordpress.org", "review it like the theme team", "Theme Check", or pastes a review from themes.trac.wordpress.org (--ticket fixes every occurrence and drafts the reply).
argument-hint: "[--ticket] [--zip=<path>] [--edition=<e>] [--report-only] [--no-site] [--no-tc] [--keep-site]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# /yay:wporg-theme

Arguments: `$ARGUMENTS`

Get the theme through the Theme Directory review in as few rounds as possible. The team reviews on a Trac ticket: a reviewer checks the required items, posts what fails, and leaves the ticket open for updates. No reply for 7 days may close it, and **three or more distinct required issues may close it as not-approved**, so finding every issue before upload matters more than polish. Only one new theme per author may be in the queue at a time.

This skill runs the checks on **the zip the repo really builds**, on a clean throwaway site, then reads the theme like a reviewer. Every rule has an ID in `references/checklist.md` (TC, L, P, A, C, F, W, N, I, X, K, B, O, S, U, by the required-items sections); the report, the fix commits and the ticket mapping all use it.

This is the theme counterpart of `/yay:wporg`. In a plugin repo (`yayh config get plugin.kind` is `plugin`), stop and point to `/yay:wporg`.

References (read when a step says so): `references/checklist.md` (IDs, rules, dated sources, the ticket section map), `references/manual-review.md` (the reviewer pass), `references/report-template.md` (the ticket review's shape). Git rules: `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`. Questions: `${CLAUDE_PLUGIN_ROOT}/reference/asking.md`.

## Options

| Option | Effect |
|---|---|
| `--ticket` | The user pasted a review from the Trac ticket: map it, fix every occurrence, draft the reply (see **Ticket review**). |
| `--zip=<path>` | Review this zip instead of building one. |
| `--edition=<e>` | The edition that ships to WordPress.org. Default `free` when it's in `editions`, otherwise the first one. |
| `--report-only` | Stop after the report: no fix offer. |
| `--no-site` | Skip the site stage: a static-only report (Theme Check doesn't run, so say so). |
| `--no-tc` | Run the site stage without installing Theme Check. |
| `--keep-site` | Leave the site running to look around (`admin` / `password`); `yayh release ui-stop` stops it. |

## 1. What ships

- Check `yayh config get plugin.kind` is `theme` (else stop: `/yay:wporg`). `slug="$(yayh config get plugin.wporgSlug)"`, or `plugin.slug` when it isn't set. `v="$(yayh version current)"`, or with `--zip` the `Version:` in the zip's `style.css`. Note `git status --porcelain`: the review must leave the working tree as it found it.
- The folder for everything this skill writes: `dir="$(yayh config get release.bundleDir release/bundles)/$(yayh config get plugin.slug)-wporg-theme-$v"`, then `mkdir -p "$dir"`.
- **The zip**, as `/yay:wporg` step 1 builds it: `--zip`, or `yayh run build edition=<e>` (when `commands.build` is set), `yayh run package version=$v edition=<e>`, `zip="$(yayh build zip edition=<e> version=$v)"`. Then `yayh build check "$zip" edition=<e>` (with `version=$v` when you built it). A FAIL in `zip`, `folder`, `dev-files`, `edition`, `main-file` or `php-syntax` stops the review: say what to fix in the build. A `version` FAIL is finding **X7**.
  - **No `commands.package`:** review the repo itself, say "Reviewed: repo source, not built" in the header, and list what could differ (dev files, built assets).
- The zip's top folder must be the slug (I2: text domain = slug = folder).

## 2. Automated pass

Nothing here changes the theme.
- **Precheck** (always): `python3 -I "${CLAUDE_PLUGIN_ROOT}/skills/wporg-theme/scripts/precheck.py" "$zip" --slug "$slug" > "$dir/precheck.txt"`. It checks headers, readme, required files, the screenshot's size and ratio, files the team refuses, plugin territory, remote resources, core-library copies, removed core hooks, classic-theme hooks, text domains and line endings, and ends with an inventory for step 3. Each finding names its ID. They're heuristics: read each line before you report it, and drop false positives silently. If `python3` can't run, say so and cover the same checks by reading the files.
- **Site** (unless `--no-site`): `yayh wporg theme-site "$zip" out="$dir" [--keep] [--no-tc]`. On the same throwaway wp-env site as `release ui` it runs Theme Check (`TC`: REQUIRED results are FAIL), activates the theme (`F5`), loads the front page, a post, a page, search and a 404, and scans `debug.log` (`C1`). It writes `site.tsv` and `theme-check.txt`; read `theme-check.txt` yourself too, since its table format isn't documented and the summary lines are a grep. Exit 3 (no e2e setup, no Docker): carry on, and the header says **"static only (no site: run /yay:e2e-init)"**.
- **Themes page** (unless `--no-site`): `yayh release ui "$zip" out="$dir/ui"`. It activates the theme from Appearance → Themes, screenshots each front-end page and the Site Editor (or the Customizer for a classic theme), and switches back. Use the screenshots for A1/A2 (skip link, focus), L5/S1 (footer credits), S2 (front-end upsell) and B2 (block recovery prompts).

## 3. Reviewer pass

Read `references/manual-review.md` and work through it against the unpacked zip, with the precheck inventory as the map. Order: plugin territory and plugins (F7, W), anything remote or tracking (X2, P), licensing of every bundled image and font (L1, L3), admin screens and notices (F2, O), the name (N), then the rest. Trace each finding to the source file the author edits and give that path in the fix.

## 4. Report

Write `$dir/review.md` exactly as `references/report-template.md` says: only sections with findings, **the ID on every issue**, `[gate]`, `[required]` or `[recommended]` on each, every occurrence with its `file:line`. Lead with the count of distinct required issues and what it means for the ticket. Call an area clean only when you checked all of it; doubts go under "Uncertain". In the reply, show **Theme Check** and **Required** issues with their IDs, `file:line` and fix, then the path to the full report.

Then check `git status --porcelain` against step 1. If the build rewrote tracked files, restore them (`git checkout -- <files>`) and say so.

## 5. Fixes

Skip with `--report-only`. Otherwise ask once (AskUserQuestion): fix everything required, only Theme Check and the required items, or chosen IDs. In the same question round, ask the decisions that change the product instead of choosing them:
- plugin territory (F7): which features move to a companion plugin (on WordPress.org, recommended per W1) and which are dropped
- a new name (N1, N3): offer 2–3 that lead with the theme's own brand
- replacing images whose license doesn't fit (L1, L3): the author's own, or which CC0 source
- removing a remote service or adding an opt-in (P1, X2)
- which upsell placement stays (S2)

Fix on a branch, never in the zip: `branch="fix/wporg-theme-review-<n>"` (`<n>` one past the highest existing `fix/wporg-theme-review-*`), `wt="$(yayh git worktree "$branch" <base>)"`, and work only there.
- **One commit per ID**, every occurrence fixed: `fix(<scope>): <ID> <what>`, e.g. `fix(theme): X2 bundle the icon font`, with the scope from `git.scopes`.
- Then rebuild and re-run step 1's `build check`, the precheck and, when it ran, `yayh wporg theme-site` on the new zip; nothing you fixed may come back.
- Push and open the PR as `/yay:fix` does (assigned to you), listing each ID fixed and each decision taken.

## Ticket review (`--ticket`)

1. Split the pasted review by its section headings and map each to IDs with `checklist.md`'s ticket section map. A heading that isn't there: map it by its text, add the row in the fix branch, and say so.
2. For each ID, search the **whole** theme for the pattern; the reviewer's examples are a sample.
3. Fix them as in step 5 (only the product decisions are asked), then run steps 1–4 on the fixed branch to catch what the next round would raise.
4. Bump the theme's version (`yayh version set <next patch>`): an update is uploaded as a new version of the same theme.
5. Write `$dir/reply.md`: 3–8 lines for the ticket, holding only what the reviewer can't see in the files: the new name if it changed, why a flagged item is fine (with the line), real questions. No list of changes and no thanks paragraph.
6. Tell the user to upload the fixed zip from the same account, then reply on the ticket. Whether the upload attaches to the open ticket by itself isn't stated on the team's pages; say so and suggest they check the ticket after uploading. Never submit it as a new theme or from another account (U1).

## 6. Wrap up

Report the verdict, the counts (Theme Check REQUIRED, distinct required issues), the report folder, the fix branch and PR when there is one, and what didn't run (no site, no Theme Check). End with the **Next** line (`reference/asking.md`): the PR's review after fixes; `/yay:wporg-theme --ticket` when a review arrives; `/yay:release --bundle` once the report is clean.

## Don'ts
- Don't review the repo when a package command exists: WordPress.org sees only the zip.
- Don't edit the zip, the user's working tree or the base branch. Fixes go through the fix branch.
- Don't upload anything or touch WordPress.org SVN or Trac.
- Don't call a check clean that you sampled, and don't report a heuristic you didn't confirm by reading the line.
- Don't apply the Plugins Team's rules (`/yay:wporg`'s checklist) to a theme: the two teams' rules differ (Google Fonts may stay remote for a theme; a theme can't register blocks or post types at all).
