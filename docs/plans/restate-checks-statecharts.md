---
id: P-2
title: Restate the job, turn corrections into checks, statecharts for stateful flows
status: done
from: Lauren Tan's agent-harness practices (talk "All Code Is Slop (Except Mine)", 2026-11-14, and the "six habits" write-up)
roadmap:
design:
trello:
type: feat
branch: feat/p-2-restate-checks-statecharts
pr:
editions: [free, pro]
created: 2026-11-23
reviewed: no
---
# P-2 Restate the job, turn corrections into checks, statecharts for stateful flows

## Goal
Three of Lauren Tan's practices the kit doesn't have yet, each in the lightest form that fits how the kit already works:

1. **Restate before building from words.** When `/yay:implement` or `/yay:fix` start from a plain-text request (no plan, no bug report), the agent writes a short **Reading** block before touching code: Goal, Not doing, Done when (an exact check), Model on (one existing `path:line` that does the same kind of thing well). If the request has two plausible readings, or no check can say when it's done, that becomes the hard question in the run's single round. Otherwise it goes on without asking. The block goes into the PR body (tiny lane) or becomes the plan's Goal and Non-goals.
2. **A repeated correction becomes a check, not a line of prose.** When the user corrects the agent, it logs `kind=correction`. `/yay:knowledge-update` promotes a correction that repeats by going down a ladder: a lint rule (PHPCS/ESLint config), then a test, then a `Verify`-style command check, and only then a sentence in the rules or knowledge docs.
3. **Statecharts for flows with real states.** `/yay:design` (and `/yay:plan` when there's no design) draw a Mermaid `stateDiagram-v2` from the user's point of view when the feature has 3+ states that move on user or system events (a return request, a points balance, a subscription-like status, a multi-step checkout). Every transition has an Acceptance line, and every risk-3 transition has a test.

Done means:
- the three new evals pass (`implement-restates-request`, `knowledge-update-correction-to-check`, `design-draws-statechart`)
- `yayh lessons add … kind=correction` works and `yayh design check` checks a statechart when one is present
- `./tests/run.sh` is green

## Non-goals
- **Formal verification (TLA+, Lean).** Too heavy for most plugin code. Revisit for a pricing or rule engine if a statechart shows the logic is the hard part.
- **Asking to confirm every restatement.** That breaks `reference/asking.md` ("Don't ask to confirm … a plan"). The Reading block is shown, not approved, unless it's ambiguous.
- **Restating when a plan or bug report exists.** The plan's Goal, Non-goals and Verify already are the restatement; the bug report's Root cause already is.
- **Writing PHPCS sniffs or ESLint plugins.** The ladder uses config of existing rules (`Generic.PHP.ForbiddenFunctions`, `WordPress.WP.DeprecatedFunctions` properties, ESLint `no-restricted-syntax` / `no-restricted-imports`). A custom sniff is a deferred note, not part of a promotion.
- **Rendering statecharts to images or a mockup.** GitHub renders Mermaid in the markdown; that's enough.
- **Checking a statechart against the code automatically.** The check is structural only (T6).

## Findings
1. **The roadmap already restates, the build skills don't.** `reference/roadmap-extras.md:26` ("Restate, then ask once") writes the acceptance it would use for an unclear item and asks once. `/yay:implement` step 0 (`reference/implement-unplanned.md`) and `/yay:fix` step 1 (`skills/fix/SKILL.md:34`) start from text with no such step. The tiny lane writes a one-line Goal into the PR only at the end (`implement-unplanned.md`, Tiny lane step 5). T1 reuses the roadmap's pattern.
2. **Asking rules limit the restatement to one round.** `reference/asking.md:5-6`: at most one round, never confirm a plan or default. So the Reading block is a printed artifact, and only an ambiguous reading becomes a question, joined to the round `/yay:implement` step 1 already has (`skills/implement/SKILL.md:48`).
3. **"One correct example" has no home.** Plans cite `Reuse:` helpers per task (`skills/plan/SKILL.md`, step 4) and `/yay:design` finds "the nearest existing screen" (`skills/design/SKILL.md:31`), but nothing asks for one existing feature to model the whole change on. T1 adds **Model on** to the Reading block, T2 adds it to the plan's Approach.
4. **Lessons exist but have no "correction" kind, and promotion only writes prose.** `lib/lessons.sh:7` has `hook review blocked env plan retry kit`. `skills/knowledge-update/SKILL.md:52-56` (3b) turns a repeated lesson into `known-issues.md`, the project block or `conventions.md`: always prose. That's exactly what the talk says not to do ("make that a deterministic check instead of adding another line to your rules").
5. **Design already has States, but as a flat list.** `templates/artifacts/design.md` `## States` lists empty/saving/success/error, which are screen states, not domain states with transitions. `yay_design_check` (`lib/artifact.sh:279-303`) checks required sections; a new optional section fits its warn pattern (`:296-302`).
6. **Testing already names state machines as unit-test targets** (`reference/testing.md:19`), so transitions map straight onto the existing Tests line. No new layer.

## Approach
- **Reading block** (T1), in `reference/asking.md` as one rule so every skill and plain request gets it, and referenced from `implement-unplanned.md` (all lanes, before picking the lane) and `fix/SKILL.md` step 1 (description only, before the inline debug):
  ```
  Reading: <one-line goal, user-visible>
  Not doing: <1-3 things a reader might expect>
  Done when: <exact check: command → expected, or UI path → what you see>
  Model on: <path:line of existing code doing the same kind of thing>
  ```
  Two plausible readings, or no possible Done when → the round's question, recommended reading first. Nobody to ask → take the likely reading, list it under **Decided**.
- **Correction ladder** (T3, T4): `reference/corrections.md` (new, short) with the ladder and recipes for a WordPress plugin repo:
  - forbidden function → `phpcs.xml` `Generic.PHP.ForbiddenFunctions` with the helper to use instead in the message
  - forbidden import or JS pattern → `.eslintrc` `no-restricted-imports` / `no-restricted-syntax` with a message naming the fix
  - wrong behaviour → a unit test at the cheapest layer (`reference/testing.md`)
  - something a grep proves → a `yayh verify`-style command check recorded in `docs/knowledge/conventions.md` under a **Checks** list
  - only what none of these can express → a sentence in the project block or `conventions.md`
  Lint-rule and test promotions happen on a branch with a PR (they change product config), like any change. The error message must say how to fix it, since the agent reads it.
- **Statechart** (T5, T6): optional `## Statechart` section in the design template, after `## Flow`. One `mermaid` block with `stateDiagram-v2`, states named as the user sees them, transitions labelled with the event (`approved: admin approves`). Required when the feature stores a status that changes on events and has 3+ states; skipped otherwise. In `/yay:plan`, with no design and a backend state machine, the chart goes in the Approach.

## Tasks
- [x] T1 Add the Reading block rule and wire it into the two skills that start from words — `plugins/yay/reference/asking.md`, `plugins/yay/reference/implement-unplanned.md`, `plugins/yay/skills/fix/SKILL.md`
  - Reuse: the "Restate, then ask once" pattern in `plugins/yay/reference/roadmap-extras.md:26`; the single round in `skills/implement/SKILL.md:48`
  - asking.md: one bullet "Restate before you build from words", with the four lines and when it becomes a question.
  - implement-unplanned.md: a step before "Pick the lane" that writes the block; the tiny lane's PR body (step 5) uses it in place of the one-line Goal; small/standard plans take Goal/Non-goals from it.
  - fix/SKILL.md step 1, "No report, only a description": write the block first; its Done when becomes the report's repro check. [risk: 1]
- [x] T2 Ask plans for one existing feature to model on — `plugins/yay/skills/plan/SKILL.md`, `plugins/yay/templates/artifacts/plan.md`
  - Reuse: the Approach bullet in `skills/plan/SKILL.md` step 3; "the nearest existing screen" wording from `skills/design/SKILL.md:31`
  - Approach starts with `Model on: <path:line> — <why it's the closest>`, or `none: nothing similar exists`. [risk: 1]
- [x] T3 Add the `correction` lesson kind and log corrections — `plugins/yay/lib/lessons.sh`, `plugins/yay/reference/asking.md`, `tests/unit/test_lessons.sh`
  - Reuse: `YAY_LESSON_KINDS` in `lib/lessons.sh:7`; the "Log the friction" bullet in `asking.md:11`
  - Add `correction` to the kinds. The bullet says: when the user corrects how you did something (not what to build), log `kind=correction` with the wrong move and the right one.
  - Test: `yayh lessons add "x" kind=correction` succeeds and `lessons list --kind=correction` lists it.
- [x] T4 Promote repeated corrections down the check ladder — `plugins/yay/reference/corrections.md` (new), `plugins/yay/skills/knowledge-update/SKILL.md`
  - Reuse: step 3b in `skills/knowledge-update/SKILL.md:52-56`; layers from `reference/testing.md`; command checks from `skills/plan/SKILL.md` step 5 (Verify)
  - corrections.md: the ladder and the five recipes above, each with a minimal config snippet.
  - 3b: a repeated `correction` (or `review`) lesson goes down the ladder first. A lint rule or test is written as a deferred note `kind=deferred` with the exact rule (knowledge-update doesn't change product config); prose only for the last rung. The report lists each promotion with its rung.
- [x] T5 Statechart in designs and plans — `plugins/yay/templates/artifacts/design.md`, `plugins/yay/skills/design/SKILL.md`, `plugins/yay/skills/plan/SKILL.md`
  - Reuse: `## States` and `## Acceptance` in the design template; the transition-as-unit-test line in `reference/testing.md:19`
  - Template: optional `## Statechart` after `## Flow`, comment says when it's needed and shows a 3-state example.
  - design step 3: when to draw it, user's point of view, every transition gets an Acceptance line. Step 5 checklist: "Does every transition have an Acceptance check, and can every state be left?"
  - plan step 3 (Approach): with no design and a stored status that changes on events, draw the chart in the Approach. Step 5 (Tests): each transition that touches money or stored data is a Tests item.
- [x] T6 Structural check for statecharts — `plugins/yay/lib/artifact.sh`, `tests/unit/test_design.sh`
  - Reuse: `yay_design_check` and its warn pattern in `lib/artifact.sh:279-303`
  - When `## Statechart` exists: warn if it has no ```` ```mermaid ```` block with `stateDiagram-v2`, warn if it has no `-->` transition, and warn on a state (other than `[*]`) with no outgoing transition and no `--> [*]` (a dead end). No error: the section is optional.
  - Tests: a design with a good chart gives no statechart warning; one with a dead-end state warns and names it; a design without the section is unchanged.
- [x] T7 Evals for the three behaviours — `plugins/yay/evals/implement-restates-request/` (new), `plugins/yay/evals/knowledge-update-correction-to-check/` (new), `plugins/yay/evals/design-draws-statechart/` (new), `plugins/yay/evals/README.md`
  - Reuse: the case format of `plugins/yay/evals/implement-tiny-lane/` (`case.yaml`, `prompt.md`, `scaffold.sh`, `graders/`)
  - implement-restates-request: "make the coupon notice say how much is left" in a tiny fixture. Graders: a Reading block with all four lines before the first edit; Model on names a real file; no question asked (the request is clear).
  - knowledge-update-correction-to-check: a lessons log with the same `get_option( 'giftly_settings' )` correction twice. Grader: the promotion is a `Generic.PHP.ForbiddenFunctions`-style rule or a deferred note with it, not only a sentence in `conventions.md`.
  - design-draws-statechart: "customers can request a return; admin approves or rejects; approved returns are refunded". Graders: a `stateDiagram-v2` with requested/approved/rejected/refunded; every transition has an Acceptance line; `yayh design check` has no statechart warning.
- [x] T8 Wire up and document — `plugins/yay/CHANGELOG.md`, `README.md`, `plugins/yay/templates/docs/yay-workflow.md`
  - Reuse: the CHANGELOG entry style of 0.15.1
  - Unreleased entry: the three behaviours, the new lesson kind, the optional design section. Nothing to run in a repo beyond `/yay:harness-update` (the design template changes). [risk: 1]

**Tests:** [unit] lessons accepts kind=correction (tests/unit/test_lessons.sh) — new kind rejected by the kind check; [unit] design check statechart warnings (tests/unit/test_design.sh) — dead-end and missing-diagram detection, and no change for designs without the section

**E2E:** none

## Verify
- ✅ `./tests/run.sh` → exit 0
- ✅ `bash tests/unit/test_lessons.sh` → exit 0 (covers `kind=correction`)
- ✅ `bash tests/unit/test_design.sh` → exit 0 (covers the statechart warnings)
- ✅ `grep -c "Reading:" plugins/yay/reference/asking.md` → 1
- ✅ `grep -c "stateDiagram-v2" plugins/yay/templates/artifacts/design.md` → 1
- ✅ the three new evals pass on their configured runs (`/kit-release` scores them)
- ✅ `/yay:implement "<a clear one-line change>"` in a real Yay repo: the Reading block appears before any edit, no question is asked, and the PR body carries it

## Risks
- **More output per run, and a creeping confirmation step.** The rule says the block is shown, not approved. The eval checks that no question is asked for a clear request. Roll back by reverting T1.
- **Lint promotions annoy a team** if a rule is too broad. Promotions are deferred notes with the exact rule, so a human ships them through a normal PR.
- **Statecharts for things that aren't state machines.** The "stored status, 3+ states, events" test keeps most designs without one; the section is optional and only warns.
- **Eval cost.** Three new cases run only when their skill text changes (`/kit-release`).
