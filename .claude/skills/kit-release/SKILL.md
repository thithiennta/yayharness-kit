---
name: kit-release
description: Release a version of the yay kit itself (this repo, not a plugin repo) - bump plugin.json and the marketplace, date the CHANGELOG, record the eval score, PR and merge to main, without stopping. Runs the unit tests only when no green run covers the code, and the eval suite only when skill text changed since the last scored version. Use when the user says "release the kit", "kit-release", "ship 0.7.0", "cut a kit version", "bump the kit".
argument-hint: "[x.y.z|major|minor|patch] [--no-evals] [--no-merge] [--dry-run]"
---

# /kit-release

Arguments: `$ARGUMENTS`

A kit release is one commit, `chore(release): yay kit <v>`, on its own branch and PR, merged into `main`. There are no tags: plugin repos get it through `claude plugin marketplace update yayharness`. Plugin releases use `/yay:release`; this skill is only for `~/yayharness`.

Run every command from the repo root.

## 1. Preflight

- On `main`, clean tree, `git pull --ff-only`. A dirty tree: stop and suggest `/kit-ship` for those changes first.
- `cur` is `"version"` in `plugins/yay/.claude-plugin/plugin.json`. It must equal the `yay` entry's `"version"` in `.claude-plugin/marketplace.json` (not `metadata.version`). If they differ, stop and say which.
- `plugins/yay/CHANGELOG.md` must start its entries with `## Unreleased (<next>)` and at least one bullet. Without it, nothing is waiting to ship: stop.
- **Version** `v`: the argument (`x.y.z`, or a bump of `cur`), otherwise `<next>` from the heading. It must be newer than `cur`. An argument that disagrees with the heading wins, and the heading is renamed to it. A major bump (`1.0.0` or `x.0.0`) is the only thing you ask about, once, since every plugin repo is affected.
- `--dry-run`: report the version, the gate (step 2) and the files step 4 would change, then stop.

## 2. Gate: what must run

`.claude/skills/kit-release/gate.sh` prints a `tests` and an `evals` line, each `skip` or `run` with the reason.

- **tests `run`:** `./tests/run.sh` (full suite, every engine), in the background, and wait. A failure stops the release. **tests `skip`:** the code a version bump can't touch already passed on this machine. Keep the reason for the PR.
- **evals `run`** (unless `--no-evals`): the whole suite, plugin arm, as the score log's release rule says (`plugins/yay/evals/README.md`):
  ```bash
  claude plugin eval plugins/yay --runs 2 -j 3 --judge-model sonnet --ablation none \
    --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish --max-cost-usd 15
  ```
  Run it in the background and wait; it takes a while and costs up to the cap. Take the mean and every case below 1.00 from its report, and compare with the last score-log row that has Runs above 0:
  - the mean dropped, or one case dropped by more than 0.25: **stop**. Name the cases, and point at their transcripts in `plugins/yay/evals/results/`. The release goes ahead only once the drop is fixed (by `/kit-ship`) or the user says to explain it in the CHANGELOG instead.
  - a case is new since that row: it starts its own baseline and never blocks.
  - a sandbox failure, not a skill one (the README notes `/usr/bin/git` and `mktemp` trouble): re-run just that case (`--case <name>`) once and use the re-run.
- **evals `skip`:** no skill, agent, reference, template, workflow or eval case changed since the last scored version, so the score can't have moved.
- **`--no-evals` while the gate said `run`:** it's the maintainer's call. Record it as "not run" with the reason given.

## 3. Branch

`git switch -c chore/release-<x-y-z>` (dots become dashes).

## 4. Edit the release

1. `plugins/yay/.claude-plugin/plugin.json` and the `yay` entry in `.claude-plugin/marketplace.json`: `"version": "<v>"`. Nothing else in either file.
2. `plugins/yay/CHANGELOG.md`: `## Unreleased (<next>)` becomes `## <v> (<today, YYYY-MM-DD>)`. When evals or tests didn't run, its first bullet says so in one line, as 0.6.0's does ("Released without the eval suite (no skill text changed since 0.5.0).").
3. `plugins/yay/evals/README.md` score log: one new row after the last one.
   - ran: `| <v> | 2 | <mean> (<n> cases) | <cases below 1.00 with scores, or none> | <date>; anything re-run and why |`
   - skipped by the gate: `| <v> | 0 | not needed | — | No skill text changed since <scored>, so the next full run still compares against <scored>. |`
   - `--no-evals`: `| <v> | 0 | not run | — | <the reason>. The next full run compares against <scored>. |`
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
3. Unless `--no-merge`: `gh pr merge <n> --merge`, then `git switch main && git pull --ff-only`. A failed merge stops with the PR URL and the reason.

## 6. Report

The version, the PR URL and whether it merged, the tests line, the evals line (the score against the last scored version, or why it was skipped), the roadmap items marked shipped and any that target `<v>` but didn't ship. **Next:** tell plugin repos to run `claude plugin marketplace update yayharness`; the session notice then offers `/yay:harness-update` there.

## Don'ts

- Never release with failing tests, or with an eval drop that nobody fixed or explained.
- Never write a score the suite didn't produce. A skipped run is `not needed` or `not run`, never a number.
- Never change anything in the release commit beyond step 4's files. A fix goes through `/kit-ship` first.
- Never tag, force-push, or edit a released CHANGELOG section.
