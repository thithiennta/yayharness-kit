---
name: wporg
description: Pre-review a Yay plugin's free zip the way the WordPress.org Plugins Team reviews submissions (Plugin Check gate, a clean-site run and a reviewer pass), write the result as their review email with a checklist ID, file:line and fix on every finding, then fix on a branch. Use when the user says "submit to wp.org", "is it ready for wordpress.org", "review it like the plugin team", "Plugin Check", "trialware", or pastes a review email from plugins@wordpress.org (--email fixes every occurrence and drafts the reply). /yay:release --wporg runs it as a release step.
argument-hint: "[--email] [--zip=<path>] [--edition=<e>] [--report-only] [--no-site] [--no-pcp] [--keep-site]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# /yay:wporg

Arguments: `$ARGUMENTS`

Get the plugin through WordPress.org review in as few rounds as possible. Each round costs 7–10 business days, and the email shows only examples, so finding **every** issue up front matters more than polish. The team reviews in two stages:
1. **Upload gate.** Plugin Check's `plugin_repo` category runs at upload; any ERROR refuses the zip (Stable tag ≠ Version, Text Domain ≠ slug, an old `Tested up to`, an `Update URI` header, disallowed files).
2. **Review.** An AI-assisted scanner drafts the email and a human confirms it. It quotes "Common issues" with `file:line` examples and asks for every occurrence to be fixed.

This skill runs the same checks on **the zip the repo really builds**, on a clean throwaway site, then reads the code like a reviewer. Every rule has an ID in `references/checklist.md` (S, G, B, Q, R, T, U from the partner checklist, plus N and Z); the report, the fix commits and the email mapping all use it.

References (read when a step says so): `references/checklist.md` (IDs and the email heading map), `references/manual-review.md` (the reviewer pass), `references/report-template.md` (the email's shape), `references/wporg-rules.md` (the full rulebook, with dated sources). Git rules: `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`. Questions: `${CLAUDE_PLUGIN_ROOT}/reference/asking.md`.

## Options

| Option | Effect |
|---|---|
| `--email` | The user pasted a review email: map it, fix every occurrence, draft the reply (see **Review email**). |
| `--zip=<path>` | Review this zip instead of building one. |
| `--edition=<e>` | The edition that ships to WordPress.org. Default `free` when it's in `editions`, otherwise the first one. |
| `--report-only` | Stop after the report: no fix offer. `/yay:release --wporg` passes it. |
| `--no-site` | Skip the site stage: a static-only report. |
| `--no-pcp` | Run the site stage without installing Plugin Check (T1 is then SKIP, and the report says the gate didn't run). |
| `--keep-site` | Leave the site running to look around (`admin` / `password`); `yayh release ui-stop` stops it. |

## 1. What ships

- `slug="$(yayh config get plugin.wporgSlug)"`. Not set: use `plugin.slug`, and say in the report that `plugin.wporgSlug` opts the repo in. `v="$(yayh version current)"`, or with `--zip` the `Version:` in the zip's main file (a release candidate carries its rc version). Note `git status --porcelain`: the review must leave the working tree as it found it.
- The folder for everything this skill writes: `dir="$(yayh config get release.bundleDir release/bundles)/$(yayh config get plugin.slug)-wporg-$v"`, then `mkdir -p "$dir"`. It's gitignored and outside the zip.
- **The zip.** The repo's own package step builds exactly what ships, so never guess the build:
  - `--zip=<path>`: use it.
  - Otherwise, as `/yay:release` "Build the bundle" step 2: `yayh run build edition=<e>` (when `commands.build` is set), `yayh run package version=$v edition=<e>`, then `zip="$(yayh build zip edition=<e> version=$v)"`.
  - Then `yayh build check "$zip" edition=<e>`, with `version=$v` when this skill built the zip. A FAIL in `zip`, `folder`, `dev-files`, `edition`, `main-file`, `php-syntax` or a repo `check` stops the review: the zip isn't what you'd upload, so say what to fix in the build (release step 2.4). A FAIL in `version` or `stable-tag` doesn't stop it: it's finding **R2** `[blocks upload]`.
  - **No `commands.package`:** review the repo itself (precheck honours `.distignore`). Say "Reviewed: repo source, not built" in the header and list what could differ. Findings in paths the build would strip (`pro/`, `__premium_only` blocks) go under "Uncertain", not into the email: Pro code the build removes isn't trialware.

## 2. Automated pass

Nothing here changes the plugin.
- **Precheck** (always): `python3 -I "${CLAUDE_PLUGIN_ROOT}/skills/wporg/scripts/precheck.py" "$zip" --slug "$slug" > "$dir/precheck.txt"` (`--wp-version X.Y` when offline). It approximates the upload gate (headers, readme, files, forbidden functions, escaping, SQL, remote assets, ABSPATH, AJAX and REST checks, zip structure) and ends with an inventory for step 3. Each finding names its ID. They're heuristics: read each line before you report it, and drop false positives silently. If `python3` can't run, say so (`yayh doctor` gives the fix) and cover the same checks by reading the code.
- **Site** (unless `--no-site`): `yayh wporg site "$zip" out="$dir" [--keep] [--no-pcp]`. It installs the zip on the same throwaway wp-env site as `release ui` and writes `site.tsv`: T1 Plugin Check (`plugin_repo` errors are FAIL), Q11 clean activation, Q7 uninstall leftovers, Q6 `debug.log`, Q10 runtime requirements. Every FAIL and WARN is a finding with its ID; a SKIP is said in the report.
  - Exit 3 (no e2e setup, no Docker): carry on. The header says **"static only (no site: run /yay:e2e-init)"** with the SKIP reason, and the appendix lists T1, Q6, Q7, Q10, Q11 as not checked. Never fail the skill for it.
  - A SKIP `T1` means the upload gate didn't run: the header says so, and "Before you upload" asks for Tools → Plugin Check by hand.

## 3. Reviewer pass

Read `references/manual-review.md` and work through it against the unpacked zip, with the precheck inventory as the map. Read the handlers, settings pages, activation hooks and upsell code: that's where the rounds come from. Order for a large plugin: every entry point (S1–S13), then everything that talks to the network (G1–G3), then everything gated by a license or pro flag (G4), then the rest. Get each rule and fix exactly right from `wporg-rules.md`. A purpose-level problem (G8) leads the report, because no code fix gets it approved. Trace each finding back to the source file the author edits and give that path in the fix.

## 4. Report

Write `$dir/review.md` exactly as `references/report-template.md` says: the team's sections and order, their per-issue shape, only sections with findings, **the checklist ID on every issue**, and `[blocks upload]` or `[review]` on each. Every finding has a `file:line` and a fix. Call an area clean only when you checked all of it. Doubtful items go under "Other details" with a "✅ When this is fine" note, or under "Uncertain". Show the report in the reply too, in two groups, **Blocks the upload** and **Will be in the review email**: each issue with its ID, its `file:line` and its fix (the code fix itself for security issues, such as the `$wpdb->prepare()` call), then the path to the full report.

Then check `git status --porcelain` against step 1. If the build rewrote tracked files, restore them (`git checkout -- <files>`) and say so.

## 5. Fixes

Skip with `--report-only`. Otherwise ask once (AskUserQuestion): fix everything, only the blockers and security (S, upload blockers), or chosen IDs. In the same question round, ask the decisions that change behaviour instead of choosing them:
- renaming the prefix (Q2): options and meta already in use need a migration
- removing a pro gate (G4): does the feature become free or move to the add-on?
- removing tracking (G3) or adding an opt-in
- a new name or slug (N1): offer 2–3 of the form `<Own brand> <function> for <Project>`
- how to prove ownership (N3): DNS TXT record, account email domain, or a transfer
- which public REST routes stay public (S2): each needs a line in the reply

Fix on a branch, never in the zip: `branch="fix/wporg-review-<n>"` (`<n>` one past the highest existing `fix/wporg-review-*`), `wt="$(yayh git worktree "$branch" <base>)"`, and work only there.
- **One commit per ID**, every occurrence fixed, not only the examples (U4): `fix(<scope>): <ID> <what>`, for example `fix(security): S12 escape stored HTML`, with the scope from `git.scopes`. Follow the codebase's style. Don't touch vendor code: update or replace the library.
- Then rebuild and re-run step 1's `build check` and the precheck on the new zip; nothing you fixed may come back.
- Push and open the PR as `/yay:fix` does (assigned to you), listing each ID fixed and each decision taken.

## Review email (`--email`)

1. Parse each heading of the pasted email and map it to IDs with `checklist.md`'s heading table. A heading that isn't there: map it by its text, add the row to `checklist.md` in the fix branch, and say so.
2. For each ID, search the **whole** plugin for the pattern (U4). The email's examples are a sample.
3. Fix them as in step 5 (the user asked for the fixes, so only the behaviour decisions are asked), then run steps 1–4 on the fixed branch to catch what the next round would raise.
4. Write `$dir/reply.md` (U3): 3–8 lines for the same thread, holding only what the reviewer can't see in the code: the new slug, stated explicitly, if the name changed; ownership context; a one-line reason for each public REST route or nopriv handler kept; a false positive answered with the line it's about; real questions. **No list of changes**, no thanks paragraph.
5. Tell the user to upload the fixed zip on the "Add your plugin" page while logged in as the submitting account, then reply in that thread. Never resubmit it as a new plugin or from another account.

## 6. Wrap up

Report the verdict, the counts (upload blockers, review-email issues), the report folder, the fix branch and PR when there is one, and what didn't run (no site, no Plugin Check). End with the **Next** line (`reference/asking.md`): the PR's review after fixes; `/yay:wporg --email` when an email arrives; `/yay:release --bundle --wporg` once the report is clean.

## Don'ts
- Don't review the repo when a package command exists: WordPress.org sees only the zip.
- Don't edit the zip, the user's working tree or the base branch. Fixes go through the fix branch.
- Don't upload anything or touch WordPress.org SVN.
- Don't call a check clean that you sampled, and don't report a heuristic you didn't confirm by reading the line.
