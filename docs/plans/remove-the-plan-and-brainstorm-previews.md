---
id: P-8
title: Remove the plan and brainstorm previews, and trim the brainstorm skill
status: in-progress
lane: small
from:
roadmap:
type: refactor
branch: refactor/p-8-remove-the-plan-and-brainstorm-previews-and-tr
pr:
editions: [free, pro]
created: 2026-11-28
---
# P-8 Remove the plan and brainstorm previews, and trim the brainstorm skill

## Goal
`/yay:plan` and `/yay:brainstorm` write their file straight away, with no preview loop. The plan skill self-reviews, asks its hard questions in one round, then writes, and its report lists the plan's data changes in plain words (keys, default, upgrade, uninstall). The brainstorm skill writes BS-n as `open`, shows each option in a line or two with the recommendation, then asks one AskUserQuestion to pick (recommended first, plus at most 2 open questions); the answer sets it `decided`, and "don't ask" leaves it `open`. Done means `reference/preview.md` and both `preview-summary.md` files are gone, nothing in skills, reference or agents points to them, the two preview eval cases are removed, and `skills/brainstorm/SKILL.md` is at most about 450 words (798 now).

## Tasks
- [ ] T1 Plan skill without the preview (`plugins/yay/skills/plan/SKILL.md`, `plugins/yay/skills/plan/preview-summary.md` deleted):
  - remove the `--yes` row, the intro's preview sentence and "previewed … until you accept" in the description
  - step 1: a brainstorm that isn't `decided` becomes "plan option <X>?" in step 7's question round
  - step 3 UI: a drafted design is written in step 8, no waiting
  - step 7 becomes **Hard questions**: tests only when the repo's rules need approval, and the single biggest open decision, in one AskUserQuestion (at most 3, recommended first), or none
  - step 8 writes from the reviewed draft; step 9's report drops "the preview rounds" and adds the data changes in plain words (each key, its default, upgrades, uninstall; or "none")
- [ ] T2 Brainstorm skill without the preview, trimmed (`plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/skills/brainstorm/preview-summary.md` deleted):
  - remove the `--yes` row and step 5's preview; the description no longer says it previews
  - new flow: write the file `open`, then show each option in 1-2 lines with the recommendation, then one AskUserQuestion to pick (recommended first, marked "(Recommended)", plus at most 2 open questions the choice depends on); the answer sets `decision` and `status decided`; "don't ask" or no answer leaves it `open`
  - trim: step 2's checklist down to editions and existing data; step 3's "really different, pros, cons" wording (the template holds the fields); the Explore agents per option; step 4's "be honest"; step 7's removed-flags line and "preview rounds"; the Don't that repeats step 3
- [ ] T3 Shared rules, evals and changelog (`plugins/yay/reference/preview.md` deleted, `plugins/yay/reference/asking.md`, `plugins/yay/reference/implement-unplanned.md`, `plugins/yay/evals/brainstorm-previews-first/` and `plugins/yay/evals/plan-previews-first/` deleted, `plugins/yay/evals/README.md`, `plugins/yay/CHANGELOG.md`) [risk: 1]:
  - asking rules: drop the "One loop" bullet; the exception bullet also names `/yay:brainstorm`'s pick question after the file is written
  - implement-unplanned: "Skip its preview (step 5)" becomes "Skip its question round", and "summary or its question round (step 7)" becomes "question round (step 7)"
  - eval README: drop the two cases' rows (score history stays)
  - CHANGELOG: an entry under `## Unreleased (0.23.0)`

## Verify
- `test ! -e plugins/yay/reference/preview.md` → exit 0
- `test ! -e plugins/yay/skills/plan/preview-summary.md` → exit 0
- `test ! -e plugins/yay/skills/brainstorm/preview-summary.md` → exit 0
- `test ! -d plugins/yay/evals/plan-previews-first` → exit 0
- `test ! -d plugins/yay/evals/brainstorm-previews-first` → exit 0
- `grep -rlE 'preview\.md|preview-summary|previews-first' plugins/yay/skills plugins/yay/reference plugins/yay/agents plugins/yay/evals/README.md` → exit 1
- `grep -c 'One loop' plugins/yay/reference/asking.md` → exit 1
- `test "$(wc -w < plugins/yay/skills/brainstorm/SKILL.md)" -le 480` → exit 0
- `grep -c 'Unreleased (0.23.0)' plugins/yay/CHANGELOG.md` → 1
- `./tests/run.sh` → exit 0
- `claude plugin validate plugins/yay` → exit 0
- In a plugin repo, `/yay:brainstorm <topic>` writes BS-n as `open`, then asks one question to pick an option; picking sets `status: decided`.
- In a plugin repo, `/yay:plan <topic>` writes the plan without showing a draft first, and its report lists the data changes.
