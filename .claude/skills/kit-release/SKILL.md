---
name: kit-release
description: Release a version of the yay kit itself (this repo, not a plugin repo) - bump plugin.json and the marketplace, date the CHANGELOG, record the eval scores, PR and merge to main, without stopping. Runs the unit tests only when no green run covers the code, and only the eval cases whose skill text changed since they were last scored, once each. Use when the user says "release the kit", "kit-release", "ship 0.7.0", "cut a kit version", "bump the kit".
argument-hint: "[x.y.z|major|minor|patch] [--no-evals] [--no-merge] [--dry-run]"
---

# /kit-release

Arguments: `$ARGUMENTS`

A kit release is one commit, `chore(release): yay kit <v>`, on its own branch and PR, merged into `main`. There are no tags: plugin repos get it through `claude plugin marketplace update yayharness`. Plugin releases use `/yay:release`; this skill is only for `~/yayharness`.

Run every command from the repo root.

## 1. Preflight

- A clean tree and an up-to-date base: `git fetch origin`, then release from `origin/main`. On `main`: `git pull --ff-only`. In a worktree (where `main` may be checked out elsewhere): the branch in step 3 starts from `origin/main`. A dirty tree: stop and suggest `/kit-ship` for those changes first.
- `cur` is `"version"` in `plugins/yay/.claude-plugin/plugin.json`. It must equal the `yay` entry's `"version"` in `.claude-plugin/marketplace.json` (not `metadata.version`). If they differ, stop and say which.
- `plugins/yay/CHANGELOG.md` must start its entries with `## Unreleased (<next>)` and at least one bullet. Without it, nothing is waiting to ship: stop.
- **Version** `v`: the argument (`x.y.z`, or a bump of `cur`), otherwise `<next>` from the heading. It must be newer than `cur`. An argument that disagrees with the heading wins, and the heading is renamed to it. A major bump (`1.0.0` or `x.0.0`) is the only thing you ask about, once, since every plugin repo is affected.
- `--dry-run`: report the version, the gate (step 2) and the files step 4 would change, then stop.

## 2. Gate: what must run

`.claude/skills/kit-release/gate.sh` prints a `tests` and an `evals` line, each `skip` or `run` with the reason.

- **tests `run`:** `./tests/run.sh` (the full suite; about a minute and a half, since only the JSON-backend files run on every engine), and wait. A failure stops the release. **tests `skip`:** the code a version bump can't touch already passed on this machine. Keep the reason for the PR.
- **evals `run`** (unless `--no-evals`): only the cases the gate names. A case runs when the skill text it covers (its own directory, the skills and agents its tags name, and the references those mention) changed since the version that last scored it in `plugins/yay/evals/scores.tsv`. Run them in the background and wait:
  ```bash
  .claude/skills/kit-release/evals.sh <the cases from the gate line>
  ```
  It runs each case once, three at a time. It re-runs a case that scored below its last score once more with 2 runs, and that score is the one that counts. It prints `case, last, score, runs, verdict` per case and the total cost (about $0.40 a case, $3 for `implement-roadmap-item`):
  - `drop` (more than 0.25 below its last score): **stop**. Name the cases and point at their transcripts (the path on stderr). The release goes ahead only once the drop is fixed (by `/kit-ship`) or the user says to explain it in the CHANGELOG instead.
  - `lower` (0.25 or less below): doesn't block. Name it in the score log row and the PR.
  - `new`: the case starts its own baseline and never blocks.
  - `error`, or a sandbox failure rather than a skill one (the README notes `/usr/bin/git` and `mktemp` trouble): re-run just that case once (`evals.sh <case>`) and use the re-run. Replies saying `yayh` was blocked ("Operation not permitted" on `lib/common.sh`) mean the eval ran the installed plugin's `yayh`: the whole run is invalid. Check that `evals.sh` puts `plugins/yay/bin` first on `PATH`.
- **evals `skip`:** no case covers skill text that changed since its last score, so no score can have moved.
- **`--no-evals` while the gate said `run`:** it's the maintainer's call. Record it as "not run" with the reason given.
- The whole suite (`plugins/yay/evals/README.md`, **Run**) is never required. Run it by hand to re-baseline every case.

## 3. Branch

`git switch -c chore/release-<x-y-z> origin/main` (dots become dashes).

## 4. Edit the release

1. `plugins/yay/.claude-plugin/plugin.json` and the `yay` entry in `.claude-plugin/marketplace.json`: `"version": "<v>"`. Nothing else in either file.
2. `plugins/yay/CHANGELOG.md`: `## Unreleased (<next>)` becomes `## <v> (<today, YYYY-MM-DD>)`. When evals or tests didn't run, its first bullet says so in one line, as 0.6.0's does ("Released without the eval suite (no skill text changed since 0.5.0).").
3. Scores, when evals ran: append one line per case to `plugins/yay/evals/scores.tsv`, `<case>\t<v>\t<score>\t<runs>\t<today>`, from `evals.sh`'s output. Never for a case that didn't run or errored. The `plugins/yay/evals/README.md` score log gets one new row after the last one:
   - ran: `| <v> | 1 | <mean of the cases run> (<n> of <N> cases) | <cases below 1.00 with scores, or none> | <date>; the cases run; any `lower` with its last score; anything re-run and why |`
   - skipped by the gate: `| <v> | 0 | not needed | — | No case covers skill text that changed since its last score. |`
   - `--no-evals`: `| <v> | 0 | not run | — | <the reason>. The gate picks these cases again next release. |`
4. `ROADMAP.md`: an item whose `- status:` is `planned` or `in-progress` and whose `target:` is `<v>`, and whose work is in the CHANGELOG entry: set `- status: shipped in <v>`. An item that targets `<v>` but didn't ship stays, and the report names it.
5. `claude plugin validate .` and `claude plugin validate plugins/yay` must pass.

## 5. Commit, PR, merge

1. Stage exactly the files from step 4. Commit `chore(release): yay kit <v>` with a body of 2-4 bullets: the versions, the dated heading, and how tests and evals were settled (run with the score, or skipped and why). End it with your session's attribution trailer, if any.
2. `git push -u origin <branch>`, then `gh pr create --base main --assignee @me --title "chore(release): yay kit <v>"` with these sections, as in #7:
   - `## Summary`: "Release yay kit <v>."
   - `## What ships`: the CHANGELOG entry's bold lines, each with its PR number (`git log --merges --oneline <last release commit>..main`).
   - `## Changes in this PR`: the edited files.
   - `## Not verified`: the tests and evals lines, saying exactly what ran and what was skipped and why.
   - `## How to test`: `claude plugin marketplace update yayharness`, check that `yay` reports `<v>`, then one command per headline.
3. Unless `--no-merge`: `gh pr merge <n> --merge`, then update `main` where it's checked out, as `/kit-ship` step 6.4 says. A failed merge stops with the PR URL and the reason.

## 6. Report

The version, the PR URL and whether it merged, the tests line, the evals line (the score against the last scored version, or why it was skipped), the roadmap items marked shipped and any that target `<v>` but didn't ship. **Next:** tell plugin repos to run `claude plugin marketplace update yayharness`; the session notice then offers `/yay:harness-update` there.

## Don'ts

- Never release with failing tests, or with an eval drop that nobody fixed or explained.
- Never write a score `evals.sh` didn't produce. A skipped run is `not needed` or `not run`, never a number.
- Never change anything in the release commit beyond step 4's files. A fix goes through `/kit-ship` first.
- Never tag, force-push, or edit a released CHANGELOG section.
