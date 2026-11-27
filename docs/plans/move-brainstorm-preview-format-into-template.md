---
id: P-6
title: Move the brainstorm preview format into its own template file
status: in-progress
lane: small
from: BS-4
roadmap:
type: docs
branch: docs/p-6-move-the-brainstorm-preview-format-into-its-ow
pr:
editions: [free, pro]
created: 2026-11-27
---
# P-6 Move the brainstorm preview format into its own template file

## Goal
The `/yay:brainstorm` preview format (the summary rules, the format block and the prompt line) lives in `skills/brainstorm/preview-summary.md`, not in step 5 of the skill. Step 5 keeps the loop and accept rules, plus one pointer: read the template and show the summary in exactly that format. What people see doesn't change. Done means step 5 has no format block, the template holds it word for word, and `brainstorm-previews-first` still scores 1.00.

## Tasks
- [x] T1 Add the preview template and point step 5 at it: move the "The summary" bullet (length, naming rules, the Data line exception), the format block and the prompt line out of step 5 word for word. Step 5 keeps the accept meanings (a letter, "ok"/"go"/"write it" accept as decided, "leave it open" accepts as open), the `--decide` rule, and the rule that a new option gets checked against the code first. The pointer reads: "Read `${CLAUDE_PLUGIN_ROOT}/skills/brainstorm/preview-summary.md` and show the summary in exactly that format, ending with its prompt line." Named `preview-summary.md` so it can't be mistaken for `reference/preview.md` (the loop rules). — `plugins/yay/skills/brainstorm/preview-summary.md` (new), `plugins/yay/skills/brainstorm/SKILL.md`
  Reuse: the existing skill-to-file pointer form `${CLAUDE_PLUGIN_ROOT}/skills/design/SKILL.md` used in `plugins/yay/skills/plan/SKILL.md` [risk: 1]
- [ ] T2 Add a changelog entry under Unreleased (0.22.0): the brainstorm preview format now lives in `skills/brainstorm/preview-summary.md`, and the preview people see is unchanged. Comes with the plugin update. — `plugins/yay/CHANGELOG.md` [risk: 1]

**Tests:** none

## Verify
- `grep -c 'Brainstorm preview, nothing written yet' plugins/yay/skills/brainstorm/SKILL.md` → exit 1
- `grep -c 'Brainstorm preview, nothing written yet' plugins/yay/skills/brainstorm/preview-summary.md` → 1
- `grep -c 'Reply with a letter to pick it' plugins/yay/skills/brainstorm/preview-summary.md` → 1
- `grep -c 'preview-summary.md' plugins/yay/skills/brainstorm/SKILL.md` → exit 0
- `./tests/run.sh` → exit 0
- `claude plugin validate plugins/yay` → exit 0
- `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case brainstorm-previews-first --runs 1 --ablation none --judge-model sonnet` scores 1.00, and the transcript shows the template file being read before the preview.
