---
name: release
description: Release a Yay plugin version end to end - picks the version from commit types, writes the changelog and release notes, bumps every version file and the tested-up-to values, marks fixed bugs and shipped roadmap items, builds and checks every edition's zip, commits chore(release) on a release branch and opens the PR assigned to its owner; after merge, --tag-only tags the released commit; --hotfix releases a patch straight from a hotfix branch. Use when the user says "release", "cut a release", "ship 1.4.0", "prepare the release", "tag the release", "hotfix release".
argument-hint: "[major|minor|patch|x.y.z] [--edition=<name>|all] [--wp-tested=X.Y] [--wc-tested=X.Y] [--hotfix] [--tag-only] [--date=YYYY-MM-DD] [--dry-run] [--pr|--no-pr] [--no-push] [--draft]"
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# /yay:release

Arguments: `$ARGUMENTS`

Three modes:
- **Prepare** (the default): a release PR from the base branch.
- **`--tag-only`**: tag it after that PR merges.
- **`--hotfix`**: release a patch from a `hotfix/*` branch.

Git rules are in `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`. Only this skill creates tags, and every tag command must start with `YAY_RELEASE=1` (the hook blocks any other).

## Options

| Option | Effect |
|---|---|
| `major\|minor\|patch\|x.y.z` | The bump. Default: `yayh changelog suggest`, confirmed with the user. With `none`, there's nothing to release. |
| `--edition=<e>\|all` | Editions to build (default `all`). |
| `--wp-tested=X.Y` / `--wc-tested=X.Y` | Update "Tested up to" and "WC tested up to" (`yayh version tested`). Without them, keep the current values, and mention them if they look stale. |
| `--hotfix` | Release a patch from the current `hotfix/*` branch (made by `/yay:fix --hotfix`), tag it there, and open the merge-back PR. |
| `--tag-only` | After the release PR has merged: tag the base branch's released commit and build the final zips from the tag. |
| `--date=YYYY-MM-DD` | Changelog date (default today). |
| `--dry-run` | Show the version, changelog, version-file changes and build plan, and change nothing. |
| `--pr` / `--no-pr`, `--no-push`, `--draft` | As in `/yay:implement`. Pushing and tagging always ask, unless `--pr` was given. |

## Prepare (default)

1. **Preflight.**
   - Be on `git.baseBranch` with a clean tree.
   - Run `git fetch origin` (if it fails, say the remote is unreachable and continue locally) and make sure the base isn't behind `origin/<base>`.
   - Run `yayh version check`. The version files must agree, and normally equal the last tag's version (`yayh git version-of-tag "$(yayh git last-tag)"`). If they don't, ask before going on.
   - Run `yayh knowledge stale --since=<last tag>`. If anything is stale, suggest `/yay:knowledge-update` first. Don't block on it.
   - Look for open work: `yayh artifact list plan --status=in-progress`. Mention it, since it isn't in this release.
2. **Version.**
   - Run `yayh changelog baseline`. It prints `<ref> <how>`, and the next step depends on `<how>`:
     - **`tag`:** normal. `last=<ref>`.
     - **`release-commit`:** `<cur>` was released at that commit but never tagged. Offer to back-fill the tag: `YAY_RELEASE=1 git tag -a "$(yayh git tag-for "$cur")" -m "<name> $cur" <ref>`, then push it after asking. Either way, `last=<ref>`.
     - **`first-appearance`:** ambiguous, so **ask** (AskUserQuestion). Has `<cur>` shipped already?
       - **Not yet:** this is the first release. Release `<cur>` itself (no bump), with a changelog of "Initial release." plus the headline features.
       - **Yes, at commit…:** back-fill the tag there, as above.
       - **Yes, but I don't know where:** use `--since` to give a date or ref.

       In a non-interactive run, stop here with this question. Don't guess.
   - `cur="$(yayh version current)"`
   - `bump` comes from the argument, or from `yayh changelog suggest`.
   - `new="$(yayh git bump "$cur" "$bump")"`
   - Show the commit summary: `yayh changelog collect`, counted by type, with breaking changes listed. Confirm `new` with the user (with `--pr`, skip the confirmation if it matches the suggestion).
3. **Branch.**
   - `branch="$(yayh git branch-name chore "release $new")"`
   - `wt="$(yayh git worktree "$branch")"`, then `cd "$wt"`
4. **Changelog.** Follow `/yay:changelog` steps 1–6 with `--version=$new --since=$last`: the readme entry plus `docs/releases/$new.md`.
5. **Versions.**
   - `yayh version set "$new"`
   - `yayh version check` must print `$new`
   - with `--wp-tested`/`--wc-tested`: `yayh version tested wp=… wc=…`
6. **Close the loop on artifacts.** These are the commits since `$last` (from the collect output):
   - **`Fixes: B-<n>`:** `yayh fm set <bug> fixed_in "$new"`, and `status fixed` if not already.
   - **`Roadmap: R-<n>`:** set that item's `- status:` line in `docs/roadmap.md` to `shipped:$new`.
   - **Plans whose commits are all in:** make sure their `status` is `done`.
7. **Build.** Follow `/yay:build` for every edition with `--version=$new`. Any FAIL stops the release: report it and leave the branch for the fix.
8. **Commit.**
   ```
   git add -- <version files> <readme> docs/releases/$new.md <changed artifacts> [.yay/config.json if tested changed]
   git commit -m "chore(release): $new" -m "<headline from the release notes>"
   ```
   Stage by path. The zips stay untracked (`release/` is a generated path).
9. **Push and PR.** Ask, unless `--pr` was given.
   - `git push -u origin "$branch"`
   - `gh pr create --base <base> --assignee @me --title "chore(release): $new" --body-file <release notes + build table>`
10. **Report.** Give the version, the changelog entry, the zips with their check results, and the PR URL. The next step is to merge, then run `/yay:release --tag-only`.

## `--tag-only`

1. Be on the base branch, clean, and run `git pull --ff-only`. HEAD must contain `chore(release): <v>`: find `<v>` from `yayh version current` and check that `yayh changelog entry <v>` isn't empty.
2. `tag="$(yayh git tag-for <v>)"`. It must not exist yet (`git rev-parse -q --verify "refs/tags/$tag"`).
3. Find the release commit: `git log --format=%H --grep="^chore(release): <v>$" -1`. Then `YAY_RELEASE=1 git tag -a "$tag" -m "<plugin name> <v>" <commit>`.
4. Ask, then `git push origin "$tag"`.
5. Build the final zips **from the tag**: `/yay:build --version=<v>` in a detached worktree of the tag (`git worktree add --detach <tmp> "$tag"`). Report the paths. Remove the temporary worktree when you're done.
6. Tidy up: `yayh git merged-worktrees` lists the worktrees whose branches are now merged (the release branch, and the features and fixes it shipped). Offer to remove them with `git worktree remove <path>`. Keep the branches, which the remote may still need.

## `--hotfix`

1. Be on a `hotfix/*` branch with a clean tree, branched from a release tag (`git describe --tags --abbrev=0` equals `yayh git last-tag`, or the tag given to `/yay:fix`). The bump is always `patch`.
2. Run the Prepare steps 2, 4–7 on **this** branch (no new branch): changelog since that tag, version, artifacts and build.
3. Commit `chore(release): <v>`. Ask, then tag that commit right away (`YAY_RELEASE=1 git tag -a …`), since it's exactly what ships, and push the branch and the tag.
4. Open the merge-back PR into the base branch: `gh pr create --base <base> --assignee @me --title "chore(release): <v> (hotfix)"`. In its body, warn that `readme.txt` and the version files will conflict if the base has moved on. Resolve them by keeping the base's newer entries plus this hotfix's entry.
5. Report the tag, the zips and the merge-back PR.

## Don'ts
- Never tag without `YAY_RELEASE=1`, never tag an unmerged release branch (hotfixes excepted), and never move or delete a pushed tag.
- Never release with failing zip checks or disagreeing version files.
- Never publish to WordPress.org SVN or upload anywhere. That's out of scope; report where the zips are.
