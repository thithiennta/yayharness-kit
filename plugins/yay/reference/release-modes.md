# /yay:release: test bundle, tag-only and hotfix

Read by `/yay:release` only for these modes. **Build the bundle** and **Prepare** are in `skills/release/SKILL.md`.

## Test bundle (`--bundle`)

A build for QA or a client to test before the release. It's built from HEAD of the current branch, any branch, and **nothing is committed, tagged or pushed**.

1. **Preflight.** `git status --porcelain`: uncommitted changes aren't in the bundle, so say so. Run `yayh run test` (and lint, reported only). A failing test stops it: don't send a broken build.
2. **Version.** `next="$(yayh git bump "$(yayh version current)" "<bump arg or $(yayh changelog suggest)>")"`, then `rc="$(yayh release next-rc "$next")"`, e.g. `1.5.0-rc.1`. WordPress sorts it before `1.5.0`, so the real release upgrades over it. Don't ask.
3. **A throwaway checkout of HEAD:** `tmp="$(mktemp -d)/build"`, `git worktree add --detach "$tmp" HEAD`, then `cd "$tmp"`. There, `yayh version set "$rc"` (never committed), and `yayh release check "$rc" --rc`: only a `version` FAIL matters here.
4. **Build the bundle** (in `skills/release/SKILL.md`) with `v=$rc` and `b=$next`, building in `$tmp`. Run `yayh release bundle` and `yayh release ui` from the **main checkout** (`YAY_REPO=<main checkout>`), with the zip paths from `$tmp`, so the bundle lands in the main checkout's `release/bundles/` and the UI site's settings come from it.
5. **No confirmation:** QA does that. UNUSUAL size lines and any UI FAIL go at the top of the bundle README and of the report.
6. Remove the throwaway checkout: `git worktree remove --force "$tmp"`.
7. **Report** the bundle path (`release/bundles/<slug>-<rc>/`), its zips with their sha256, the UI and size results, and the manual checks for the tester. To send it as one file: `(cd release/bundles && zip -qr <slug>-<rc>.zip <slug>-<rc>)`.

## `--tag-only`

1. Be on the base branch, clean, and run `git pull --ff-only`. HEAD must contain `chore(release): <v>`: find `<v>` from `yayh version current` and check that `yayh changelog entry <v>` isn't empty.
2. `tag="$(yayh git tag-for <v>)"`. It must not exist yet (`git rev-parse -q --verify "refs/tags/$tag"`).
3. Find the release commit: `git log --format=%H --grep="^chore(release): <v>$" -1`. Then `YAY_RELEASE=1 git tag -a "$tag" -m "<plugin name> <v>" <commit>`.
4. Push the tag only with `--push-tag`. Otherwise print `git push origin "$tag"` in the report.
5. **The final bundle, from the tag:** in a detached worktree of the tag (`git worktree add --detach <tmp> "$tag"`), **Build the bundle** with `v=<v>`, `b=<v>`, and `--replace`, but no UI check and no confirmation, since that build was confirmed in the release PR. If a zip's sha256 differs from the release PR's `MANIFEST.txt`, say so: the build isn't reproducible. Remove the temporary worktree when you're done.
6. Tidy up: `yayh git merged-worktrees` lists the worktrees whose branches are now merged (the release branch, and the features and fixes it shipped). Offer to remove them with `git worktree remove <path>`. Keep the branches, which the remote may still need.
7. **Archive check:** run `yayh artifact archive --release="$tag"` (a dry run that changes nothing). When it lists `archive` lines, the report's **Next** line is `/yay:archive --release=<tag>` with their count. It cleans the shipped plans, notes and roadmap items out of `docs/` on its own PR.
8. **Report** the tag and the bundle path: this is what gets published.

## `--hotfix`

1. Be on a `hotfix/*` branch with a clean tree, branched from a release tag (`git describe --tags --abbrev=0` equals `yayh git last-tag`, or the tag given to `/yay:fix`). The bump is always `patch`.
2. Run the tests (the skill's Prepare step 1), then Prepare steps 2 and 4–10 on **this** branch (no new branch): the changelog since that tag, the versions, the artifacts, the release gate, the bundle and the developer's confirmation.
3. Commit `chore(release): <v>` and tag that commit right away (`YAY_RELEASE=1 git tag -a …`), since it's exactly what ships. A local tag is safe, so don't ask first. Push the branch by default (not with `--no-pr`); push the tag only with `--push-tag`. Print whatever wasn't pushed as commands.
4. Open the merge-back PR into the base branch (by default; with `--no-pr`, print the command): `gh pr create --base <base> --assignee @me --title "chore(release): <v> (hotfix)"`. In its body, warn that `readme.txt` and the version files will conflict if the base has moved on. Resolve them by keeping the base's newer entries plus this hotfix's entry.
5. Report the tag, the bundle path and the merge-back PR.
