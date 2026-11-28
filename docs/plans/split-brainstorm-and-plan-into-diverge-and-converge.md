---
id: P-9
title: Split brainstorm and plan into diverge and converge
status: in-progress
lane: small
from: BS-5
roadmap:
type: refactor
branch: refactor/p-9-split-brainstorm-and-plan-into-diverge-and-con
pr:
editions: [free, pro]
created: 2026-11-28
---
# P-9 Split brainstorm and plan into diverge and converge

## Goal
`/yay:brainstorm` diverges and `/yay:plan` converges (BS-5, option C).
- **Brainstorm:**
  - It asks up to 3 challenge questions first, but only when the input is rough.
  - It throws ideas away fast.
  - It writes a file with Problem, Direction (and why), Discarded (one line each), Risks and edge cases, and Open questions.
  - Then it asks you to pick.
- **Plan:**
  - It makes no design choices. An undecided brainstorm gets the pick question, and an unclear approach is sent back to `/yay:brainstorm`.
  - It writes only Goal, Tasks, Verify (the acceptance criteria) and Risks.
  - Each task names its files and can carry `[size: S|M|L]`, `[after: T<n>]` and `[risk: 3]`.
  - A Verify item that a test proves ends with its layer, `(unit)`, `(integration)`, `(js)` or `(e2e)`, and `/yay:implement`, `/yay:test` and `/yay:e2e` write those tests.
- **Removed:** Findings, Non-goals, Approach, the Reuse and Callers lines, the Tests and E2E lines, and the small and standard lanes. The tiny lane stays.

Done means:
- `skills/plan/SKILL.md` is at most 900 words (3040 now).
- `plan check` no longer warns about any removed section.
- Older plans still pass `plan check`, and their extra sections are ignored.
- Every test passes.

## Tasks
- [x] T1 Brainstorm diverges: `plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/templates/artifacts/brainstorm.md`, `plugins/yay/reference/asking.md`, `plugins/yay/reference/artifacts.md` (Brainstorm) [size: S]
  - a challenge round first, only when the input is rough; a new template; asking rules allow brainstorm's two rounds
- [ ] T2 Plan format and `plan check` (`plugins/yay/templates/artifacts/plan.md`, `plugins/yay/templates/artifacts/plan-small.md` deleted, `plugins/yay/lib/artifact.sh`, `tests/unit/test_artifact.sh`, `tests/unit/test_tests.sh`, `tests/unit/test_e2e.sh`, `plugins/yay/reference/artifacts.md` (Plan)) [size: M] [after: T1]
  - the template has Goal, Tasks, Verify and Risks; `lane=` is still accepted and makes no difference
  - `plan check` drops the lane, strictness, Reuse, Callers, Tests, E2E and Findings checks
  - `plan check` warns on an unknown `[size: …]` and on an `[after: T<n>]` naming a task that isn't earlier
  - a risk-3 task needs a Verify item that's a command check or names a test layer
- [ ] T3 Plan converges (`plugins/yay/skills/plan/SKILL.md`) [size: M] [after: T2]
  - the steps are: source (ask the pick, or send back to `/yay:brainstorm`), read the files, tasks, Verify, self-check, write, report
  - no question round apart from the pick; drop `--tests` and `--lane`
- [ ] T4 Readers of the old format (`plugins/yay/skills/implement/SKILL.md`, `plugins/yay/reference/implement-unplanned.md`, `plugins/yay/skills/test/SKILL.md`, `plugins/yay/skills/e2e/SKILL.md`, `plugins/yay/skills/go/SKILL.md`, `plugins/yay/reference/code-rules.md`, `plugins/yay/reference/models.md`, `plugins/yay/reference/config.md`, `plugins/yay/reference/config.schema.json`, `plugins/yay/templates/rules/yay-workflow.md`, `plugins/yay/templates/docs/yay-workflow.md`, `plugins/yay/templates/artifacts/design.md`) [size: M] [after: T3]
  - implement reads the Verify layers instead of the Tests and E2E lines, and its lanes are tiny or plan
  - strictness: relaxed and strict no longer change `plan check`; strict still has no tiny lane
- [ ] T5 Evals and changelog (`plugins/yay/evals/plan-from-request/graders/plan-format.md`, `plugins/yay/evals/README.md`, `plugins/yay/CHANGELOG.md`) [size: S] [after: T4] [risk: 1]

## Verify
- `test ! -e plugins/yay/templates/artifacts/plan-small.md` → exit 0
- `test "$(wc -w < plugins/yay/skills/plan/SKILL.md)" -le 900` → exit 0
- `grep -rlE 'Reuse:|Callers:|\*\*Tests:\*\*|\*\*E2E:\*\*|## Findings|Non-goals' plugins/yay/skills plugins/yay/reference plugins/yay/templates plugins/yay/lib` → exit 1
- `grep -c '^## Direction' plugins/yay/templates/artifacts/brainstorm.md` → 1
- `grep -c 'Unreleased (0.23.0)' plugins/yay/CHANGELOG.md` → 1
- `./tests/run.sh` → exit 0 (unit)
- `claude plugin validate plugins/yay` → exit 0
- In a plugin repo, `/yay:brainstorm "<rough idea>"` asks challenge questions first, writes BS-n with Direction and Discarded, then asks the pick.
- In a plugin repo, `/yay:plan --from=BS-n` writes a plan with only Goal, Tasks (each with its files and a size), Verify and Risks, and asks nothing when BS-n is decided.

## Risks
- **Plan evals score lower once the reuse and test-layer rules are gone.** Roll back by reverting the PR. The rules come back from git.
- **Plugin repos keep the old wording until the harness is updated.** That's the managed `yay-workflow` rule and docs. The next release's harness update fixes them.
