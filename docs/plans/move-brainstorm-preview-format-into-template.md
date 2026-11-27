---
id: P-6
title: Move the brainstorm preview format into its own template file
status: done
lane: small
from: BS-4
roadmap:
type: docs
branch: docs/p-6-move-the-brainstorm-preview-format-into-its-ow
pr: 64
editions: [free, pro]
created: 2026-11-27
---
# P-6 Move the brainstorm preview format into its own template file

## Goal
The `/yay:brainstorm` preview format (the summary rules, the format block and the prompt line) lives in `skills/brainstorm/preview-summary.md`, not in step 5 of the skill. Step 5 keeps the loop and accept rules, plus one pointer: read the template and show the summary in exactly that format. What people see doesn't change. Done means step 5 has no format block, the template holds it word for word, and `brainstorm-previews-first` still scores 1.00. Extended after the first PR review round: `/yay:plan` gets the same split (`skills/plan/preview-summary.md`, step 7), and `plan-previews-first` scores 1.00.

## Tasks
- [x] T1 Add the preview template and point step 5 at it: move the "The summary" bullet (length, naming rules, the Data line exception), the format block and the prompt line (with its `--decide` rule) out of step 5 word for word. Step 5 keeps the accept meanings (a letter, "ok"/"go"/"write it" accept as decided, "leave it open" accepts as open) and the rule that a new option gets checked against the code first. The pointer reads: "Read `${CLAUDE_PLUGIN_ROOT}/skills/brainstorm/preview-summary.md` and show the summary in exactly that format, ending with its prompt line." Named `preview-summary.md` so it can't be mistaken for `reference/preview.md` (the loop rules). — `plugins/yay/skills/brainstorm/preview-summary.md` (new), `plugins/yay/skills/brainstorm/SKILL.md`
  Reuse: the existing skill-to-file pointer form `${CLAUDE_PLUGIN_ROOT}/skills/design/SKILL.md` used in `plugins/yay/skills/plan/SKILL.md` [risk: 1]
- [x] T2 Add a changelog entry under Unreleased (0.22.0): the brainstorm preview format now lives in `skills/brainstorm/preview-summary.md`, and the preview people see is unchanged. Comes with the plugin update. — `plugins/yay/CHANGELOG.md` [risk: 1]

- [x] T3 Same split for `/yay:plan`: move step 7's "The summary" bullet, the format block and the prompt line word for word into `skills/plan/preview-summary.md`, and point step 7 at it. Step 7 keeps the Open bullet (it also says what to ask when the preview is skipped) and the accept rule. Extend the T2 changelog entry to name both skills. — `plugins/yay/skills/plan/preview-summary.md` (new), `plugins/yay/skills/plan/SKILL.md`, `plugins/yay/CHANGELOG.md`
  Reuse: the T1 pointer form `${CLAUDE_PLUGIN_ROOT}/skills/brainstorm/preview-summary.md` [risk: 1]

- [x] T4 Remove what the templates made redundant in `reference/preview.md`: the naming, first-line and `Changed:` rules in "Each round" step 1 (step 1 now points at the skill's `preview-summary.md`), the plan prompt quoted in step 3, and "each skill defines its own summary" (now names where it lives). The two details only `preview.md` had move into the templates first: no commands or test file paths (with its examples; for the brainstorm too, in How), and Data lines never name the functions that write the data. This also ends a clash: `preview.md` allowed `file:line` only under Surprises, the brainstorm template allows it in Must keep. — `plugins/yay/reference/preview.md`, `plugins/yay/skills/plan/preview-summary.md`, `plugins/yay/skills/brainstorm/preview-summary.md`, `plugins/yay/CHANGELOG.md`
  Reuse: n/a [risk: 1]

**Tests:** none

## Verify
- ✅ `grep -c 'Brainstorm preview, nothing written yet' plugins/yay/skills/brainstorm/SKILL.md` → exit 1
- ✅ `grep -c 'Brainstorm preview, nothing written yet' plugins/yay/skills/brainstorm/preview-summary.md` → 1
- ✅ `grep -c 'Reply with a letter to pick it' plugins/yay/skills/brainstorm/preview-summary.md` → 1
- ✅ `grep -c 'preview-summary.md' plugins/yay/skills/brainstorm/SKILL.md` → exit 0
- ✅ `./tests/run.sh` → exit 0
- ✅ `claude plugin validate plugins/yay` → exit 0
- ✅ `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case brainstorm-previews-first --runs 1 --ablation none --judge-model sonnet` scores 1.00, and the transcript shows the template file being read before the preview.
- ✅ `grep -c 'Plan preview, nothing written yet' plugins/yay/skills/plan/SKILL.md` → exit 1
- ✅ `grep -c 'Plan preview, nothing written yet' plugins/yay/skills/plan/preview-summary.md` → 1
- ✅ `grep -c 'skills/plan/preview-summary.md' plugins/yay/skills/plan/SKILL.md` → exit 0
- ✅ `PATH="$PWD/plugins/yay/bin:$PATH" claude plugin eval plugins/yay --case plan-previews-first --runs 1 --ablation none --judge-model sonnet --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish` scores 1.00, and the trace shows `skills/plan/preview-summary.md` being read.
- ✅ `grep -c 'php tests/run.php' plugins/yay/reference/preview.md` → exit 1
- ✅ `grep -c 'php tests/run.php' plugins/yay/skills/plan/preview-summary.md` → 1
