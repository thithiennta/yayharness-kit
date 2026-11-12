# yay eval suite

Behaviour checks for the `/yay:*` skills, run with `claude plugin eval`. Each case builds a small "Giftly" plugin repo (git, `.yay/config.json`, a roadmap, a bug report, a planted off-by-one in `includes/GiftMessage.php`), asks the kind of thing a developer would type, and grades the outcome.

| Case | What it checks |
|---|---|
| `roadmap-status-readonly` | "Where are we with the sprint?" fires `/yay:roadmap`, reports the slipped item and the high bug, and leaves `docs/roadmap.md` unchanged. |
| `roadmap-vision-asks-first` | A vision ("the go-to gift plugin for B2B stores") fires `/yay:roadmap`, which asks who/edition, the must-have and by when, and what's out of scope (one round, recommendations first) before drafting items, and leaves `docs/roadmap.md` unchanged while it waits. |
| `roadmap-add-unclear-asks` | "Add reminders to the roadmap": the title could mean two different features, so `/yay:roadmap` restates its reading as an acceptance, offers another, and asks before adding anything (`docs/roadmap.md` unchanged). |
| `roadmap-add-clear-no-question` | A clearly described item (a character counter under the gift message) is added without a question, and the report shows its acceptance line. Guards against over-asking. |
| `debug-finds-cause-without-editing` | A bug report fires `/yay:debug`, which finds the `>=` off-by-one with file:line evidence and writes `docs/bugs/`, without editing code. |
| `changelog-next-release` | "What's in the next release?" fires `/yay:changelog`: merchant-language lines, the harness commit left out, readme untouched. |
| `changelog-keeps-hand-lines` | `readme.txt` already has a hand-written `= 1.3.0 =` line covering the gift card preview. Writing the changelog keeps that line word for word, adds a line for the 200-character fix, dates the heading (`= 1.3.0 - <date> =`), and doesn't add a second preview line. |
| `harness-init-never-auto` | "Set up the harness" must not wipe anything: `/yay:harness-init` is user-only, so Claude hands it to the user. |
| `code-comments-settings-toggle` | Hiding My Account tabs (the real case that motivated 0.2.0): the existing comment block above `my_account` stays as it was, and no comment lines are added to `Settings.php`. |
| `code-leaves-unrelated-comments` | A threshold change leaves the docblock and inline comment alone, and adds no inline comments. |
| `code-reuses-existing-helpers` | Showing a fee at checkout calls `Support\\Format::price()` rather than an inline `wc_price()`. |
| `plan-decides-without-stopping` | A plain "write the plan for R-2" request: at most one question, the plan marked ready by Claude, and its own decisions listed (`reference/asking.md`). |
| `go-routes-symptom-to-debug` | `/yay:go` with a plain-words symptom routes to `/yay:debug` (cause unknown, so not `/yay:fix`), and no product code is edited. |
| `review-catches-missing-capability` | `yay:bug-reviewer` on a branch whose settings handler has no nonce and no capability check: it flags a security blocker with the fix, and edits nothing. |
| `implement-tiny-lane` | "Change the checkout label": built in the tiny lane, with no plan file, on its own branch, touching only the label. |
| `implement-roadmap-item` | "Build R-2": plans, then builds on a branch, a commit per task with `Plan:` trailers, tests run, **both** reviewers (`bug-reviewer`, `code-reviewer`), nothing pushed, the unrelated planted bug left alone. The most expensive case (about $3–5 a run). |
| `fix-regression-test-first` | "Fix B-2" (the planted 200-character off-by-one): a regression test that fails first, a minimal fix, the bug marked fixed. |
| `test-finds-product-bug` | "Add tests for trimming and capping": unit layer, boundary cases 199/200/201, and the off-by-one reported as a product bug rather than asserted. No product code edited. |
| `plan-from-request` | A plan request fires `/yay:plan`, which writes `docs/plans/` with tasks and Verify checks, and no code. |
| `plan-keeps-screenshot` | A plan request with a screenshot path (`shots/preview-overlap.png`): the image is copied to `docs/assets/P-1/` and linked from the plan, with a Seen-in-screenshot line and a Verify check for what it shows. No code. |

## Run

```bash
cd ~/yayharness   # or a worktree of it
# one case, once, plugin arm only (cheap smoke test, about $0.25)
PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case roadmap-status-readonly --runs 1 --ablation none \
  --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish
# the whole suite against a no-plugin baseline
PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --runs 3 -j 3 --judge-model sonnet \
  --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish --max-cost-usd 15
```

- Put the plugin under test's `bin/` first on `PATH`. Run from a Claude Code session, the eval inherits that session's `PATH`, so skills would call the installed plugin's `yayh` instead. The sandbox only lets them read the plugin under test, so every `yayh` call fails with "Operation not permitted" (`lib/common.sh`), and the scores drop for a reason that isn't the skills. The 0.7.0 run from a worktree hit this.

- `--scaffold` is needed because each case's `scaffold.sh` builds its repo.
- `--allow-tools Bash Write Edit` grants the gated tools that the skills use.
- Results go to `evals/results/`, which is gitignored.
- Use `--judge-model sonnet`. The default Haiku judge failed correct answers in the first run (2026-11-11). With Sonnet, the plugin scored 1.00 on every case, a mean +0.22 over the baseline.
- Kit 0.2.0 (3 runs per case): the settings comments case went from 0.22 to 0.94 with the plugin; the no-plugin baseline scored 0.28. The two other code cases stayed at 1.00 in both arms; they're regression guards.
- In a two-arm run, the `fires-skill` graders are reported as indicators, not as part of the score.

## Score log and the release rule

Each case's last score is in `scores.tsv` (one line per case per scored release). A kit release runs only the cases whose skill text changed since they were last scored: the case's directory, the skills and agents its `tags` name (so tag a case with every skill and agent it exercises), and the references those files mention. `/kit-release`'s `gate.sh` picks them and `evals.sh` runs each once (Sonnet judge, plugin arm), re-running a case that scored lower with 2 runs. **A case that drops by more than 0.25 against its last score doesn't ship** until the drop is fixed or explained in the CHANGELOG entry. A smaller drop is noted here. A new case starts its own baseline. The release adds one line here: the version, the mean of the cases it ran, and every case below 1.00.

The whole suite (**Run** above) is for re-baselining by hand, not a release requirement. Until 0.8.0 every release had to run it; `scores.tsv` starts from 0.5.0, the last full run.

| Kit | Runs | Mean | Below 1.00 | Notes |
|---|---|---|---|---|
| 0.2.0 | 3 | 1.00 (9 cases) | none | before the task-quality cases |
| 0.5.0 | 2 | 0.95 (15 cases; the 9 from 0.2.0: 1.00) | `fix-regression-test-first` 0.25 | Full run 2026-11-12, then re-runs. `plan-decides-without-stopping` (0.80) and `plan-from-request` (0.92) dropped in the full run because of sandbox trouble: `/usr/bin/git` is a broken Xcode stub and `mktemp` ignores the sandbox temp folder, so a run left no plan file or couldn't commit. Re-run: both 1.00. `implement-roadmap-item` (0.93, then 0.79) reported the two reviews as one list; implement's report now names each reviewer, re-run 1.00. `fix-regression-test-first` is new, so this is its baseline: the replies report the fix, the failing-first test and the status, but the judge fails them 3/3. Check its grader before 0.6.0. |
| 0.5.1 | 0 | not run | — | Released without the suite (the maintainer's call). It changes `/yay:implement`, `/yay:fix`, `/yay:plan` and `yay:code-reviewer` (the dead-code check, `Callers:` lines, Verify command checks), so the next release's full run compares against 0.5.0. |
| 0.6.0 | 0 | not run | — | Released without the suite (the maintainer's call). Adds `/yay:archive` (no eval case yet), so the next full run still compares against 0.5.0. |
| 0.7.0 | 0 | not run | — | Released without the full suite (the maintainer's call). A full run on 2026-11-12 is not counted: run from a worktree, it called the installed plugin's `yayh`, which the sandbox blocked (now fixed with the `PATH` prefix, #12). With the fix, the two cases that run flagged scored 1.00 over 2 runs each: `implement-roadmap-item` (after its report gained a Reviews section) and `test-finds-product-bug` (after `/yay:test` covers both sides of a limit). The next full run compares against 0.5.0. |
| 0.7.1 | 0 | not run | — | Released without the suite (the maintainer's call). The next full run compares against 0.5.0. |
| 0.7.2 | 0 | not run | — | Released without the suite (the maintainer's call). It changes the spawn line in nine skills and `reference/models.md` (the routed `effort` is now asked for explicitly), so the next full run compares against 0.5.0. |
| 0.8.0 | 0 | not run | — | Released without the suite (the maintainer's call). It changes the branch, commit and PR title wording in implement, fix, changelog, the tiny lane and autopilot, so the next full run compares against 0.5.0. |
| 0.9.0 | 1 | 0.95 (16 of 16 cases) | `fix-regression-test-first` 0.25 | 2026-11-12; the first per-case release run (`evals.sh`, one run each): every case was due, since none had been scored since 0.5.0. `fix-regression-test-first` holds its 0.5.0 score (its grader still fails correct replies). `roadmap-vision-asks-first` is new: 1.00, its baseline. $6.69. |
| 0.10.0 | 1 | 1.00 (4 of 18 cases) | none | 2026-11-12; the roadmap cases only (the roadmap skill and `reference/roadmap-extras.md` changed): `roadmap-status-readonly` and `roadmap-vision-asks-first` held 1.00, and the new `roadmap-add-unclear-asks` and `roadmap-add-clear-no-question` start at 1.00. $1.32. |
| 0.11.0 | 1 | 1.00 (2 of 19 cases) | none | 2026-11-12; the changelog cases only (`/yay:changelog` changed): `changelog-next-release` held 1.00, and the new `changelog-keeps-hand-lines` starts at 1.00. $0.60. |
| 0.12.0 | 1 | 0.95 (19 of 19 cases) | `fix-regression-test-first` 0.25, `go-routes-symptom-to-debug` 0.83 | 2026-11-12; every case (each scaffold now seeds `status: todo`, and `reference/artifacts.md` changed). `go-routes-symptom-to-debug` is lower (last 1.00, re-run with 2 runs); `fix-regression-test-first` held its 0.25. $9.72. |

## Adding a case

Copy a case directory. Edit `scaffold.sh`: it's the shared fixture, plus case-specific lines at the end. Then write `prompt.md` the way a developer would phrase it, without naming the skill, and add graders under `graders/`:
- `tool_used` with `tool: Skill` checks that a skill fired
- `regex` with `target: { source: file, path: … }` checks file contents
- `file_exists` checks that a file was created
- `llm` judges the reply

Graders have no shell access, so check repo state through file contents.
