---
id: BS-5
title: Split brainstorm and plan into diverge and converge
status: decided
from:
decision: C. Plan cut to the bone
created: 2026-11-28
---
# BS-5 Split brainstorm and plan into diverge and converge

## Problem
The two skills don't match how people think about them. They should be:
- **Brainstorm (diverge):** "what if…?". Ask, list options, challenge assumptions, spot risks and edge cases. It ends in a chosen direction and its reasons. It can be messy, and most ideas get thrown away.
- **Plan (converge):** "exactly what, where, in what order, how do we know it's done". Ordered tasks with files, acceptance criteria, estimates and dependencies, so the implementer decides nothing new.

What the code does now:
- **Brainstorm** (`plugins/yay/skills/brainstorm/SKILL.md`, 480 words) is already short, but it doesn't diverge:
  - It never asks or challenges anything before it writes. The only question is the pick at the end (step 6).
  - Its file is a formal comparison, where every option fills the same six fields (How, Pros, Cons, Risks, Editions, Size) (`templates/artifacts/brainstorm.md`). It isn't "a direction plus reasons", and rejected ideas take as much space as the chosen one.
  - Risks and edge cases sit inside each option, not across the problem.
- **Plan** (`plugins/yay/skills/plan/SKILL.md`, 3040 words, six times the brainstorm) is where it gets complicated, and it still makes decisions:
  - Step 1: a brainstorm that isn't decided gets its recommended option planned anyway.
  - Step 3 writes the Approach, the edition split and storage, and may draft a whole design.
  - Step 7 asks "the single biggest open decision".
  - So "plan" also diverges.
- **Plan lacks two of the converge outputs:**
  - Per-task estimates: there's only S/M/L on brainstorm options.
  - Dependencies between tasks: order is implied by T-numbers, and `Callers: … (T4)` hints at it.
- **The plan's size is mostly rules, not steps.** These paragraphs run long:
  - Reuse/Callers (step 4)
  - risk and tier tags (step 4)
  - the Tests ladder and E2E (step 5)
  - Verify format (step 5)
  - lanes
  - picking up notes

## Constraints
- `/yay:implement` reads the plan's fields and must keep working:
  - `[risk: 3]` triggers a pre-commit review.
  - `[tier: …]` delegates a task.
  - Command checks in Verify feed `yayh verify --run --mark`.
  - The `Plan:` trailer and tick boxes stay.
- `yayh plan check` (`plugins/yay/lib/artifact.sh:167`) warns on Reuse, Callers and Tests layers. Changing what a plan holds means changing it and its tests too.
- `reference/artifacts.md` (Brainstorm, Plan) documents both formats. `implement-unplanned.md` runs both skills inline (`--explore`, the small and standard lanes).
- Evals cover plan-from-request, plan-keeps-screenshot, implement-roadmap-item and implement-tiny-lane. A big plan rewrite has to keep them passing.
- Old BS and P files in plugin repos must still read.
- One question round per skill (`reference/asking.md`), except brainstorm's pick.

## Options

### A. Clean split, keep the plan's machinery, move its rules out (M)
- **Brainstorm** becomes a real diverge pass:
  - Steps: frame the problem → challenge it (assumptions, who it's really for, the edge cases) → 2-4 directions, thrown away fast → pick → write.
  - Ask first only when the input is rough. That's one AskUserQuestion of at most 3 questions that change the direction. Then the pick at the end, as now.
  - The new file: Problem; **Direction** (the chosen one, with its why); **Discarded** (one line each, with why not); **Risks and edge cases** (across the problem); **Open**.
  - No per-option six-field table.
- **Plan** stops deciding:
  - A brainstorm that isn't decided means plan asks the pick, the same question brainstorm asks, and never picks on its own.
  - Step 7 asks only what's needed to execute (tests approval), not design choices.
  - The Approach becomes "Decisions in" (copied from the brainstorm's Direction) plus "Model on".
- **Plan gains the converge fields** on each task: a size (`[size: S|M|L]`) and `after: T<n>` when a task depends on one that isn't the one before it. Acceptance criteria are the Verify list, named that way.
- **Plan gets short.** The rules move to a new `reference/plan-rules.md`: Reuse/Callers, the risk and tier tags, the Tests ladder, Verify format, and picking up notes. `SKILL.md` keeps only the steps, about 1,000-1,200 words.
- **Pros:**
  - It matches the diverge/converge model exactly.
  - `implement`, `plan check` and the evals keep their contract.
  - The plan becomes easy to read.
- **Cons:**
  - Two skill rewrites, plus a template, `artifacts.md`, `plan check` (sizes and deps are optional, so no new warns) and `implement-unplanned.md`.
  - The rules file is one more place to look.
- **Risks:**
  - The plan evals score lower if the moved rules aren't read. Mitigation: steps point to the exact section.

### B. Rewrite brainstorm, touch plan lightly (S)
- Brainstorm as in A.
- Plan only changes three things:
  - step 1, which asks the pick instead of planning an open brainstorm;
  - step 7, which asks no design questions;
  - a size and `after:` on tasks.
- Everything else stays at about 3,000 words.
- **Pros:**
  - Small, quick, low eval risk.
- **Cons:**
  - Plan stays "complicated like now", the user's main complaint.

### C. Plan cut to the bone (L)
- Brainstorm as in A.
- A plan is only Goal, Tasks, Acceptance and Risks. Each task has its files, size, deps and risk tag.
- Drop Findings, Non-goals, Reuse/Callers, the Tests/E2E lines and the lanes. The lanes go because every plan has the same shape.
- **Pros:**
  - The simplest plan possible.
- **Cons:**
  - It loses the reuse and caller discipline that the code reviewer and `yayh code unused` lean on.
  - It loses test-layer choice, so implement must decide tests, which is a new decision at build time and against "decide nothing new".
- **Risks:**
  - Rewrites of `plan check` and `implement`.
  - Every plan eval rebaselines.
  - Older plans have sections nothing reads.

## Recommendation
**A.** It's the only option that gives both halves of the model:
- Brainstorm actually diverges: questions, challenges, discarded ideas, risks across the problem.
- Plan actually converges: no design choices, sizes and dependencies added.

And it makes plan short without throwing away what `/yay:implement` relies on.
- B leaves the plan exactly as hard to read as it is now.
- C makes it simpler by moving decisions into implement, which breaks "nothing new to decide".

I'd switch to C if you're willing to give up Reuse/Callers and per-plan test layers. I'd switch to B if the goal is only the brainstorm.

Suggested order: brainstorm first (one PR, small), then plan (one PR), so each one's evals are read on their own.

Answered (2026-11-28):
- Brainstorm asks challenge questions before writing, but only when the input is rough: one round, at most 3 questions.
- `/yay:plan` on an undecided brainstorm asks the pick itself and never picks on its own.

C includes all of A's brainstorm and A's plan changes (no design choices, task size and deps). The only difference is the plan's rules: A moves them to `reference/plan-rules.md`, and C deletes them (Findings, Non-goals, Reuse/Callers, Tests/E2E lines, lanes).

**Decided: C** (2026-11-28). The plan is cut to Goal, Tasks (files, size, deps, risk tag), Acceptance and Risks. The plan still has to name the tests, or `/yay:implement` decides them at build time: a planning question for the plan.

## Open questions
- Without the Tests line, how does `/yay:implement` know which tests to write? Default: each task's acceptance line says how it's proven, and implement writes the cheapest test that proves it.
- Do old plans (with Reuse, Callers and Tests lines) still pass `plan check`? Default: yes, the extra lines are ignored.
