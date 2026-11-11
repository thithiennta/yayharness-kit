# yay eval suite

Behaviour checks for the `/yay:*` skills, run with `claude plugin eval`. Each case builds a small "Giftly" plugin repo (git, `.yay/config.json`, a roadmap, a bug report, a planted off-by-one in `includes/GiftMessage.php`), asks the kind of thing a developer would type, and grades the outcome.

| Case | What it checks |
|---|---|
| `roadmap-status-readonly` | "Where are we with the sprint?" fires `/yay:roadmap`, reports the slipped item and the high bug, and leaves `docs/roadmap.md` unchanged. |
| `debug-finds-cause-without-editing` | A bug report fires `/yay:debug`, which finds the `>=` off-by-one with file:line evidence and writes `docs/bugs/`, without editing code. |
| `changelog-next-release` | "What's in the next release?" fires `/yay:changelog`: merchant-language lines, the harness commit left out, readme untouched. |
| `harness-init-never-auto` | "Set up the harness" must not wipe anything: `/yay:harness-init` is user-only, so Claude hands it to the user. |
| `plan-from-request` | A plan request fires `/yay:plan`, which writes `docs/plans/` with tasks and Verify checks, and no code. |

## Run

```bash
cd ~/yayharness
# one case, once, plugin arm only (cheap smoke test, about $0.25)
claude plugin eval plugins/yay --case roadmap-status-readonly --runs 1 --ablation none \
  --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish
# the whole suite against a no-plugin baseline
claude plugin eval plugins/yay --runs 3 -j 3 --judge-model sonnet \
  --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish --max-cost-usd 15
```

- `--scaffold` is needed because each case's `scaffold.sh` builds its repo.
- `--allow-tools Bash Write Edit` grants the gated tools that the skills use.
- Results go to `evals/results/`, which is gitignored.
- Use `--judge-model sonnet`. The default Haiku judge failed correct answers in the first run (2026-11-11). With Sonnet, the plugin scored 1.00 on every case, a mean +0.22 over the baseline.
- In a two-arm run, the `fires-skill` graders are reported as indicators, not as part of the score.

## Adding a case

Copy a case directory. Edit `scaffold.sh`: it's the shared fixture, plus case-specific lines at the end. Then write `prompt.md` the way a developer would phrase it, without naming the skill, and add graders under `graders/`:
- `tool_used` with `tool: Skill` checks that a skill fired
- `regex` with `target: { source: file, path: … }` checks file contents
- `file_exists` checks that a file was created
- `llm` judges the reply

Graders have no shell access, so check repo state through file contents.
