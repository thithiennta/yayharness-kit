---
name: release
description: Build, check and release a Yay plugin, ending in a bundle to send. Use when the user says "release", "cut a release", "ship 1.4.0", "tag the release", "hotfix release", "build the zip", "package it", "make a build for QA", "send a test build", "check the zip". --bundle makes a test bundle (next version + rc) for QA without releasing. A release checks the Stable tag, versions and changelog, builds and checks every zip, compares the bundle size with the last release, runs the plugins page with the built zip, gets the developer's confirmation, and opens the release PR. --tag-only tags it after merge; --hotfix releases a patch.
argument-hint: "[major|minor|patch|x.y.z] [--bundle] [--edition=<name>|all] [--wp-tested=X.Y] [--wc-tested=X.Y] [--hotfix] [--tag-only] [--date=YYYY-MM-DD] [--no-build] [--no-ui] [--keep-site] [--dry-run] [--no-pr] [--push-tag] [--draft]"
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# /yay:release

Arguments: `$ARGUMENTS`

Every mode ends in a **bundle**: one folder, `release/bundles/<slug>-<version>/` (`release.bundleDir`), that you can send to QA or use to publish.
- the zip for each edition
- `MANIFEST.txt`: the commit, plus each zip's size, file count and sha256
- `README.md`: what changed, the check results, the size compared with the last release, the UI check, and the manual checks left
- `ui/<edition>/`: plugins-page screenshots and logs

Four modes:
- **Prepare** (the default): release `x.y.z` through a release PR from the base branch.
- **`--bundle`**: a test bundle for QA, `<next>-rc.<n>`, built from HEAD. Nothing is committed, tagged or pushed.
- **`--tag-only`**: tag the release after its PR merges, and rebuild the final bundle from the tag.
- **`--hotfix`**: release a patch from a `hotfix/*` branch.

Git rules are in `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`. Only this skill creates tags, and every tag command must start with `YAY_RELEASE=1` (the hook blocks any other). The commands come from `.yay/config.json` (`commands.build`, `commands.package`, `package.output`, `package.forbidden`, `checks`). Never improvise a different build.

## Options

| Option | Effect |
|---|---|
| `major\|minor\|patch\|x.y.z` | The bump. Default: `yayh changelog suggest`. With `none`, there's nothing to release. |
| `--bundle` | Make a test bundle for QA instead of releasing. See `reference/release-modes.md`. |
| `--edition=<e>\|all` | Editions to build (default `all`, from `yayh config get editions`). |
| `--wp-tested=X.Y` / `--wc-tested=X.Y` | Update "Tested up to" and "WC tested up to" (`yayh version tested`). Without them, keep the current values, and mention them if they look stale. |
| `--hotfix` | Release a patch from the current `hotfix/*` branch (made by `/yay:fix --hotfix`), tag it there, and open the merge-back PR. |
| `--tag-only` | After the release PR has merged: tag the base branch's released commit and rebuild the final bundle from the tag. |
| `--date=YYYY-MM-DD` | Changelog date (default today). |
| `--no-build` | Skip `commands.build` (the assets are already built): only package and check. |
| `--no-ui` | Skip the automatic plugins-page check. A release then asks you to confirm that you checked it by hand. |
| `--keep-site` | Leave the UI check's site running afterwards, to look around (`admin` / `password`). `yayh release ui-stop` stops it. |
| `--dry-run` | Show the version, the changelog, the version-file changes, the release checks and the build plan. Change nothing. |
| `--no-pr`, `--no-push`, `--draft` | As in `/yay:implement`: the release branch is pushed and its PR opened by default. `--no-pr` keeps it local and prints the commands. |
| `--push-tag` | Also push the tag (`--tag-only`, `--hotfix`). Without it the tag stays local and the report prints `git push origin <tag>`. Local tags are made without asking. |

## Build the bundle

Every mode uses this. It needs a version `v` (the version the zips carry) and a baseline version `b` for the size comparison (`v` itself, or `x.y.z` for an rc).

1. **Config.** `yayh config get commands.package` and `yayh config get package.output` must both be set. If one is missing, stop and say which key to add, with a suggestion based on `scripts/`, `bin/`, or the `package.json`/`composer.json` scripts. Note `git status --porcelain`, so you can tell afterwards what the build changed.
2. **For each edition** `e`:
   1. Unless `--no-build`, run `yayh run build edition=<e>`. If dependencies are missing, run `yayh run install` once.
   2. `yayh run package version=<v> edition=<e>`.
   3. `zip="$(yayh build zip edition=<e> version=<v>)"`. If it's empty, the package command didn't produce what `package.output` describes; report both.
   4. `yayh build check "$zip" edition=<e> version=<v>`. This checks for one top folder, no dev files, no forbidden paths for the edition, the right version header and Stable tag, PHP that parses, and the repo's `checks`. Any FAIL means the build is **not shippable**: stop and say what to fix. A dev file means fixing the package script's excludes or `.distignore`. Forbidden paths mean fixing the edition strip step. A version mismatch means fixing `versionFiles`. Never fix a check by editing the zip. WARN lines are judgment calls; a legitimate one is silenced with `package.allow`.
   5. `yayh release size "$zip" edition=<e> version=<b>`. Keep any `UNUSUAL` lines: a size or file count that moved more than 25% or 1 MB against the last release that recorded its size, or a single file over 2 MB (`release.sizeChangePct`, `release.sizeChangeKb`, `release.largeFileKb`). A `WARN baseline` line only means nothing was recorded yet.
3. **Bundle.** `bundle="$(yayh release bundle <v> <e>=<zip>… [--replace])"`, run in the main checkout. Use `--replace` only when rebuilding the same version (`--tag-only`, or a release re-run).
4. **Plugin links check** (the UI check), unless `--no-ui`. For each edition: `yayh release ui "$zip" out="$bundle/ui/<e>" edition=<e> [--keep]`. It installs **the built zip** (not the source) in its own throwaway wp-env site, then on the WordPress Plugins page:
   - checks that the plugin is listed, and activates it from its row (recording where activation lands)
   - collects every **action link** (under the plugin's name: Settings, Upgrade to Pro…) and **meta link** (next to the version: Docs, Support, View details…) of the now-active plugin
   - follows each one. An internal link must answer without a 4xx/5xx, a fatal error or a "not allowed" page; it records the page's heading and a screenshot. An external link is requested, redirects followed: 404/410/5xx is a FAIL; 403/429 or unreachable is a WARN (sites often block automated checks)
   - deactivates it (noting a deactivation-feedback dialog), and scans `debug.log` for PHP errors from the plugin's folder

   `ui/<e>/links.tsv` is the table the developer confirms: kind, text, URL, status, where it lands (page heading, or final URL after redirects), result.

   Exit 1 is a FAIL: stop, show the lines and the screenshot, and suggest `/yay:debug`. Exit 3 means it couldn't run (no e2e setup or no Docker): say why. The release then gets a manual check instead (Prepare step 9).
5. **Bundle README.** Write `$bundle/README.md`:
   - the plugin, the version and the commit
   - what changed: the changelog entry, or for an rc, a short merchant-language list from `yayh changelog collect --since=<last tag>`
   - the build-check results per edition
   - the size against the baseline, with every UNUSUAL line and the largest files
   - the plugin's links (`links.tsv`) and the other UI-check lines, naming each step's screenshot, so the tester can confirm each link goes where it should
   - the manual checks left: the `## Verify` items needing a browser or a human, from the plans shipped since the last tag (`Plan:` trailers)
   - how to install it: upload the zip under Plugins → Add New → Upload, or `wp plugin install <zip> --force`
6. **Tidy up.** Compare `git status` with step 1. If a package script rewrote tracked files that this mode doesn't commit, restore them (`git checkout -- <files>`) and say so.

## Prepare (default)

1. **Preflight.**
   - Be on `git.baseBranch` with a clean tree.
   - Run `git fetch origin` (if it fails, say the remote is unreachable and continue locally) and make sure the base isn't behind `origin/<base>`.
   - Run `yayh version check`. The version files must agree, and normally equal the last tag's version (`yayh git version-of-tag "$(yayh git last-tag)"`). If they don't, that's a question in the round below.
   - Run `yayh knowledge stale --since=<last tag>`. If anything is stale, suggest `/yay:knowledge-update` first. Don't block on it.
   - Look for open work: `yayh artifact list plan --status=in-progress`. Mention it, since it isn't in this release.
   - Run the tests: `yayh test run all` (unit, integration when Docker is running, js; it falls back to `commands.test`). A failure stops the release, so report it and suggest `/yay:debug`. Integration reported as *skipped* is said in the report, not a block. If no test command is set, say that the kit ran no tests. Also run `yayh run lint` when it's set, and report failures without blocking: lint debt often predates the release.
   - **E2E** (when `commands.e2e` is set and Docker is running): `yayh e2e env start`, then the full suite, `yayh e2e run`. Triage failures as `${CLAUDE_PLUGIN_ROOT}/reference/e2e.md` says. A product bug stops the release, like a failing test. A flaky or environment failure is reported and doesn't block. Without Docker, say the suite wasn't run.
2. **Version.**
   - Run `yayh changelog baseline`. It prints `<ref> <how>`, and the next step depends on `<how>`:
     - **`tag`:** normal. `last=<ref>`.
     - **`release-commit`:** `<cur>` was released at that commit but never tagged. Back-fill the tag locally: `YAY_RELEASE=1 git tag -a "$(yayh git tag-for "$cur")" -m "<name> $cur" <ref>`, pushed only with `--push-tag`. Either way, `last=<ref>`.
     - **`first-appearance`:** ambiguous, so **ask** (AskUserQuestion). Has `<cur>` shipped already?
       - **Not yet:** this is the first release. Release `<cur>` itself (no bump), with a changelog of "Initial release." plus the headline features.
       - **Yes, at commit…:** back-fill the tag there, as above.
       - **Yes, but I don't know where:** use `--since` to give a date or ref.

       In a non-interactive run, stop here with this question. Don't guess.
   - `cur="$(yayh version current)"`. `bump` comes from the argument, or from `yayh changelog suggest`. `new="$(yayh git bump "$cur" "$bump")"`.
   - Show the commit summary: `yayh changelog collect`, counted by type, with breaking changes listed.
   - **Hard questions only** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`). Use the suggested version without asking. Ask only for a **major** bump (breaking changes reach customers), a bump argument that disagrees with the commits, or a version-file or baseline doubt from preflight. Hold these for step 9's round when they can wait that long; they rarely can't.
3. **Branch.** `branch="$(yayh git branch-name chore "release $new")"`, `wt="$(yayh git worktree "$branch")"`, then `cd "$wt"`.
4. **Changelog.** Follow `/yay:changelog` steps 1–6 with `--version=$new --since=$last`: the readme entry plus `docs/releases/$new.md`.
5. **Versions.** `yayh version set "$new"`, then `yayh version check` must print `$new`. With `--wp-tested`/`--wc-tested`: `yayh version tested wp=… wc=…`.
6. **Close the loop on artifacts.** These are the commits since `$last` (from the collect output):
   - **`Fixes: B-<n>`:** `yayh fm set <bug> fixed_in "$new"`, and `status fixed` if not already.
   - **`Roadmap: R-<n>`:** `yayh roadmap set R-<n> status "shipped:$new"`. Also do this for the `roadmap:` item of every plan shipped in this release.
   - **Plans whose commits are all in:** make sure their `status` is `done`.
7. **Release gate.** `yayh release check "$new"` must have no FAIL. It checks:
   - every version file says `$new`, and `$new` is newer than the last release tag
   - the readme's **Stable tag** is `$new` (`trunk` only when `release.stableTag` is `trunk`)
   - the readme **changelog** has a `$new` entry without placeholder text
   - `docs/releases/$new.md` exists

   A FAIL from steps 4–5 (a missing entry, a version file that `versionFiles` doesn't cover) gets fixed here, then the gate runs again. Anything else stops the release, with the line.
8. **Build the bundle** (above) with `v=$new`, `b=$new`.
9. **Confirm: the developer always signs off on a release.** One AskUserQuestion, asked even when nothing else is open:
   - **The plugin's links** (always first). Show `links.tsv` for each edition as a table: every action and meta link of the active plugin, with its URL, where it lands and its result, plus where activation lands. The question is whether **each link goes where it should** (the right settings tab, the right docs page, the right upgrade URL with its tracking parameters), not only whether it loads. Ask: "Are these the right links for `<plugin> $new`?" Options: "All correct, release it" / "A link is wrong, stop". A WARN link (blocked or unreachable from here) is named in the question so the developer opens it by hand. If the check didn't run, list the links from the plugin's `plugin_action_links_*` and `plugin_row_meta` filters in the code instead, ask the developer to activate the zip on a test site and click each one, and ask the same question.
   - **Size**, only when step 8 had UNUSUAL lines. Show them, with the largest new files. Ask: "Is this size change expected?" Options: "Expected" / "Not expected, stop".
   - **Any hard question held from step 2.**

   Any "stop" answer leaves the branch as it is and reports what to look at. In a non-interactive run, or when the user said "don't ask", stop here too: a release needs a person's yes. Report the bundle and the pending confirmations.
10. **Record the size** as the next release's baseline: for each edition, `yayh release size "$zip" edition=<e> version=$new --record=docs/releases/$new.md`.
11. **Commit.**
    ```
    git add -- <version files> <readme> docs/releases/$new.md <changed artifacts> [.yay/config.json if tested changed]
    git commit -m "chore(release): $new" -m "<headline from the release notes>"
    ```
    Stage by path. The bundle stays untracked (`release/` is a generated path).
12. **Push and PR.** By default, without asking. With `--no-pr`, or with no `origin` remote or no logged-in `gh`, end the report with the exact commands instead.
    - `git push -u origin "$branch"`
    - `gh pr create --base <base> --assignee @me --title "chore(release): $new" --body-file <release notes, the bundle README's check, size and UI sections, and "Confirmed by the developer: plugins page, size">`
13. **Report.** Give the version, the changelog entry, the check results, the size against the baseline, the UI check, the PR URL, and **the bundle path to send**. The next step is to merge, then `/yay:release --tag-only`.

## `--bundle`, `--tag-only` and `--hotfix`

Each of these modes is in `${CLAUDE_PLUGIN_ROOT}/reference/release-modes.md`. Read only the section for the mode you were given. All of them use **Build the bundle** above, and `--hotfix` also uses **Prepare**.

## Don'ts
- Never tag without `YAY_RELEASE=1`, never tag an unmerged release branch (hotfixes excepted), and never move or delete a pushed tag.
- Never release with a FAIL from `yayh release check`, `yayh build check` or the UI check, or without the developer's yes in Prepare step 9.
- Never hand-edit a zip, or delete files from it to pass a check. Fix the build.
- Never commit a test bundle's rc version, and never send a bundle built with `--no-build` unless you know the assets are current.
- Never publish to WordPress.org SVN or upload anywhere. That's out of scope; report where the bundle is.
