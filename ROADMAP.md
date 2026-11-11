---
horizon: 2027-01-20
sprint_length: 2w
capacity: 8
updated: 2026-11-11
---
# yay kit roadmap: 0.4.0 → 0.5.0

Four goals for the next version:
1. **Easy to use.** Fewer things to remember.
2. **Smooth handoffs.** Moving between steps and workflows should feel like one flow.
3. **Less strict.** Guardrails for safety, not ceremony.
4. **Better results.** Proven correct, measured, and learning from past runs.

Sizes: S = 1.5, M = 4, L = 8 dev-days. Capacity: 8 dev-days per 2-week sprint (one maintainer). Every `why` points at something in this repo.

## Sprint 1 (2026-11-12 → 2026-11-25)
Goal: you always know where you are and what comes next. *(7 / 8)*

### R-1 `yayh status` / `yayh next`: one view of all work in flight
- size: M · goal: 2 (it also feeds R-4 and R-7)
- why: state is spread across `yayh roadmap status`, `roadmap links`, `roadmap queue`, `backlog open`, `artifact list`, worktrees and PRs. Only roadmap items get a "next action" (roadmap SKILL.md, Status step 3). Bugs without a fix, unpushed worktrees and plans that are half done get none.
- what: one command that lists every chain (R → BS → UX → P → branch → PR → release) with its stage and the single next command. `yayh next <id>` prints just that command. It reuses `roadmap queue`'s stage logic.

### R-2 Resume where you stopped, at session start
- size: S · goal: 2
- why: `hooks/session-start.sh` only prints the rules and the harness version. A new session in a worktree doesn't know that it's P-4, task 3 of 7.
- what: when the checkout or worktree is on a work branch, add one line: `P-4 "<title>" · 3/7 tasks · next: /yay:implement P-4 --continue` (from R-1). On the base branch, show the current sprint's next item. At most 3 lines.

### R-3 The same "Next:" footer on every skill
- size: S · goal: 2
- why: each skill writes its next step differently (brainstorm step 7, roadmap step 9, implement's report has none). Some skills end without one.
- what: every report ends with `Next: <one command>` plus at most 2 alternatives, taken from `yayh next`. If the user replies "go", "next" or "continue", that command runs.

## Sprint 2 (2026-11-26 → 2026-12-09)
Goal: the workflow bends for small work. Safety guards stay. *(7 / 8)* → **ship 0.4.0**

### R-4 Lanes by size: tiny, small, standard
- size: M · goal: 3
- why: `yay-workflow.md` says "Start from an artifact" for everything. `/yay:implement "<req>"` always runs the full `/yay:plan` (step 0.2), and `plan check` warns about Reuse, a Tests layer and the E2E line even for a one-file change.
- what: implement picks the lane and says which one it chose.
  - **tiny** (one file, about 30 lines or fewer, no customer-visible decision): no artifact. A branch, a commit and a PR whose body holds Goal and Verify.
  - **small** (S): a mini plan with only Goal, Tasks and Verify. The Reuse, Tests and E2E warnings are off.
  - **standard**: the flow as it is today.
  - Pass `--lane=` to override.

### R-5 Adapt the plan instead of stopping
- size: S · goal: 3
- why: implement step 3.1 says "If the plan turns out to be wrong … stop and tell the user", and the workflow rule says "Plans are the contract". A moved file or an equivalent API therefore halts the run.
- what: when the scope and the customer-visible behaviour stay the same, edit the task text in the same commit and list the change under **Decided** in the PR. Stop only when the scope or what customers see would change.

### R-6 Hooks warn about style and block only for safety
- size: S · goal: 3
- why: commits get rejected for a scope that isn't in `git.scopes` or for a header that's too long (ONBOARDING §8, "A commit is rejected").
- what: an unknown scope, the header length and the branch-name shape become post-commit warnings that suggest an `--amend`. These stay blocked: commits on the base branch, `--no-verify`, tags, generated and kit-owned files, and `yay:debug` markers.

## Sprint 3 (2026-12-10 → 2026-12-23)
Goal: one front door, and shorter skills. *(8 / 8)*

### R-7 `/yay`: a front door that routes plain language
- size: M · goal: 1 · depends: R-1
- why: there are 18 skills, `/yay:roadmap` has 21 flags and `/yay:release` has 14, and ONBOARDING §7 needs a table just to remember them.
- what: `/yay` with no argument shows `yayh status` and offers the next step. `/yay fix the coupon bug`, `/yay build R-12` or `/yay ship it` routes to the right skill and its flags. The other skills stay as they are; this one only adds.

### R-8 Slimmer skills, details loaded only when needed
- size: M · goal: 1, 4
- why: release is 166 lines, roadmap 141 and implement 134, and two rule files load in every session. The rarely used branches (Trello, multi-agent, publish, legacy conversion, hotfix) take up context on every run.
- what: aim for 80 lines or fewer per SKILL.md. Move the rare paths into `reference/<skill>-*.md`, read only when the matching flag is given. Accept words as well as flags (`/yay:roadmap status`, `/yay:release bundle`).

## Sprint 4 (2026-12-24 → 2027-01-06)
Goal: work proven correct, not only tidy. Expect a holiday slowdown. *(8 / 8)* → **ship 0.5.0**

### R-9 Correctness review before every PR
- size: M · goal: 4
- why: `yay:code-reviewer` reviews only reuse and comments (CHANGELOG 0.2.0). Nothing independent checks the diff for logic bugs, WordPress security (nonces, capabilities, escaping, sanitizing), HPOS or block-checkout compatibility, or Pro code leaking into Free.
- what: add a correctness pass to the reviewer, or a second `yay:bug-reviewer`, briefed only with the diff and the plan's Goal. Findings are fixed or answered in the PR, as reuse findings are today. Blocking findings only for security.

### R-10 Live pilot sweep of features never run for real
- size: M · goal: 4
- why: PLAN.md lists five "not yet run live" gaps: autopilot with model routing and a tagged task (P12), a sheet answer settling a note (P10), `/yay:design` on a real screen (P11), e2e worktree ports, adopting YayWholesale's setup and CI (P8), and a multi-plugin roadmap (P5).
- what: run each one on one real plugin, and fix what breaks (the P3 and P4 runs found 3 to 5 bugs each).

## Sprint 5 (2027-01-07 → 2027-01-20)
Goal: measure quality, so every later change can show it helped. *(8 / 8)*

### R-11 Task-quality evals for the build skills
- size: L · goal: 4
- why: the 9 eval cases cover roadmap, debug, changelog, harness-init, plan and code style. None covers implement, fix, autopilot, design, test or e2e, and P11 says "no eval yet".
- what: Giftly cases for implement (tests pass, plan followed, reuse), fix (regression test fails first), the lane choice from R-4, and test-layer choice. Run them per kit version, record the scores in CHANGELOG, and don't release a version that scores lower.

## Later

### R-12 `/yay:setup` and `yayh doctor`
- size: M · goal: 1
- why: ONBOARDING §2 has one person run 2 to 4 init skills in order, and most of the 11 rows in its troubleshooting table are environment problems (plugin not installed, Node, Docker, jq).
- what: `yayh doctor` checks gh, jq, node, nvm, Docker, wp-env, the plugin install and the config. `/yay:setup` chains the init skills it needs, with one question round.

### R-13 Proof of done: executable Verify
- size: M · goal: 4
- why: Verify items are prose (`templates/artifacts/plan.md`), and the implementer grades its own work (implement 4.3).
- what: write Verify as `command → expected`, run them with `yayh verify P-<n>`, and have an agent outside the build check the Goal against the diff.

### R-14 One item, end to end, interactively
- size: M · goal: 2
- why: brainstorm → plan → implement takes three invocations. Autopilot chains them, but through background workflow agents.
- what: `/yay:implement R-12 --from-scratch` (or `/yay go R-12`) brainstorms, plans and builds in the session, with one question round.

### R-15 Lessons loop
- size: M · goal: 4
- why: blocked items, hook rejections and review findings end up in `.yay/runs/` and PR bodies, and nothing reads them again.
- what: every run appends its friction to `.yay/runs/lessons.md`. `/yay:knowledge-update` turns patterns that repeat into `docs/knowledge/` entries, and kit-level ones into notes for this repo.

### R-16 Easier artifact carrying across worktrees
- size: M · goal: 2
- why: artifacts start untracked in the main checkout and are carried in, autopilot refuses a dirty main checkout, and id clashes renumber an artifact before the PR.
- what: write the artifact directly into the work branch once one exists, show `yayh artifact where <id>` across worktrees, and clean up leftover copies automatically.

### R-17 Strictness setting in config
- size: M · goal: 3
- why: some repos want stricter rules than R-4, R-5 and R-6 leave (for example, client work with required approvals).
- what: `workflow.strictness: relaxed | standard | strict`, read by the hooks, by `plan check` and by the lane choice.

## Decided
- Order: smooth handoffs first. R-1 underpins R-2, R-3 and R-7, and it's cheap.
- Loosening the rules (R-4, R-5, R-6) ships in 0.4.0. The evals (R-11) come after it, so they also measure the new lanes. If you want a baseline to compare with first, pull R-11's implement case into Sprint 1.
- `/yay` only adds an entry point (R-7). No skill is removed or renamed, so nothing breaks for the team.
- The safety blocks stay as they are: commits on the base branch, `--no-verify`, tags, generated and kit-owned files, debug markers, and the harness wipe confirmation.
- The calendar defaults (2-week sprints, 8 dev-days, start on 2026-11-12) are a guess. Change the capacity and the plan reflows.
