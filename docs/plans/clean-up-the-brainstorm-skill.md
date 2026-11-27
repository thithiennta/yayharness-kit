---
id: P-7
title: Clean up the brainstorm skill and drop --options, --decide and --commit
status: in-progress
lane: small
from:
roadmap:
type: refactor
branch: refactor/p-7-clean-up-the-brainstorm-skill-and-drop-options
pr:
editions: [free, pro]
created: 2026-11-27
---
# P-7 Clean up the brainstorm skill and drop --options, --decide and --commit

## Goal
`/yay:brainstorm` is about a quarter shorter, loses three options nothing uses, and says how to start from a bug or a backlog note. Each option in the brainstorm file gets `Risks:` and `Editions:` lines. The preview looks the same, except `--decide` no longer changes the prompt. Done means the three options are gone everywhere (autopilot included), `SKILL.md` is at most 800 words (1,005 now), `brainstorm-previews-first` scores 1.00, and a `--yes` run still writes the file straight away. Step numbers stay 1-7, so the "step 5" pointers in `reference/preview.md`, `reference/asking.md` and `skills/brainstorm/preview-summary.md` stay right.

## Tasks
- [x] T1 Drop `--options`, `--decide` and `--commit` (`plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/skills/brainstorm/preview-summary.md`, `plugins/yay/workflows/autopilot.js`):
  - remove their rows and the `argument-hint` entries
  - step 3 says "2-4 options, only as many as are really different"
  - delete step 6's "Preview skipped" `--decide` bullet: a skipped preview always writes `status: open`
  - delete the `--decide` sentence from the preview template's prompt line
  - the `--yes` row drops "unless `--decide`"
  - step 7 says, in one line, when the arguments named a removed option and what to do instead (pick in the preview; say "commit it")
  - the autopilot prompt drops "(no --decide, no --commit)"
- [ ] T2 Tighten the rest, and fill the gaps (`plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/templates/artifacts/brainstorm.md`):
  - **Remove:**
    - the intro's repeat of step 5 and of the second Don't, and its `artifacts.md` pointer
    - step 5's description of the loop, which `reference/preview.md` already holds (keep the skip list, which gates the loop)
    - step 6's list of headings, which the template shows (keep the rule that preview answers go into Recommendation, not Open questions)
    - the Accepting bullet's "ground a new option in the code (step 3)", which the third Don't covers
  - **Shorten:** the `--yes` and `--research` rows.
  - **Spell out:**
    - `--quick` means two options and no subagents; the preview still runs
    - step 1 gets one line each for a bug (its root cause and fix options are the starting point) and a backlog note (its question and default become the Problem and option A)
  - **Template:** add `- Risks:` and `- Editions:` to each option in the brainstorm template.
- [ ] T3 Changelog entry under Unreleased (0.22.0): the three removed options and what to do instead, and the new Risks and Editions lines. — `plugins/yay/CHANGELOG.md` [risk: 1]

**Tests:** none

## Verify
- `grep -cE -- '^\| .--(options|decide|commit)|\[--(options|decide|commit)' plugins/yay/skills/brainstorm/SKILL.md` → exit 1
- `grep -cE -- '--(options|decide|commit)' plugins/yay/skills/brainstorm/preview-summary.md` → exit 1
- `grep -c 'no --decide' plugins/yay/workflows/autopilot.js` → exit 1
- `test "$(wc -w < plugins/yay/skills/brainstorm/SKILL.md)" -le 800` → exit 0
- `grep -c -- '- Editions:' plugins/yay/templates/artifacts/brainstorm.md` → 2
- `grep -c 'skipped' plugins/yay/skills/brainstorm/SKILL.md` → exit 0
- `git diff --numstat main -- plugins/yay/workflows/autopilot.js` → 1	1
- `./tests/run.sh` → exit 0
- `claude plugin validate plugins/yay` → exit 0
- `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case brainstorm-previews-first --runs 1 --ablation none --judge-model sonnet --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish` scores 1.00.
- In a plugin repo, `/yay:brainstorm <topic> --yes` writes a `status: open` brainstorm with no preview, and each option has Risks and Editions lines.
