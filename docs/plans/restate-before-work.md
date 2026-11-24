---
id: P-4
title: Say the job back before the work, in every skill that starts from words
status: done
from: conversation 2026-11-24 (Lauren Tan's "make it say the job back to you"; Thariq Shihipar's "Finding your unknowns": blind spot pass, interviews, plans that lead with what's likely to change; Boris Cherny's plan-first habit)
roadmap:
design:
trello:
type: feat
branch: feat/p-4-restate-before-work
pr:
editions: [free, pro]
created: 2026-11-24
reviewed: no
---
# P-4 Say the job back before the work, in every skill that starts from words

## Goal
Every `/yay:*` skill that starts from someone's words says the job back first: what it understood, what it assumes, what it won't do, what could catch it out, and how we'll know it's done. A misunderstanding then costs one correction, not a branch.

- **Every skill restates.** Today only `/yay:implement` and `/yay:fix` do (the Reading block, P-2). Brainstorm, design, debug, plan, test and e2e get a restatement in their own shape. Most of it lives in sections their artifacts already have (Problem, Job, Symptoms, Goal).
- **Big work waits for you** (decided with the user 2026-11-24: "always wait on big work"). Brainstorm, design, debug from a pasted thread or long report, a standard-lane plan or implement written from words, and `/yay:autopilot`'s decision sheet show the restatement and stop on it before writing any file. That stop is the run's one question round: the restatement is question 1, the hard questions are 2-3. Small and tiny work shows it and carries on, as today. With nobody to ask, nothing waits.
- **Assumptions come first, not last.** The block gets an `Assumed:` line (Lauren: list assumptions for the user to correct), so a guess is visible before the work, not only under **Decided** at the end.
- **A blind spot pass.** The block gets a `Watch for:` line (Thariq): at most 3 things that could catch this change out in this repo, from `known-issues.md` and a short WordPress/WooCommerce list (HPOS, block vs classic checkout, Free vs Pro, caching, existing data on upgrade, multisite, translations).
- **An opt-in interview** (decided with the user 2026-11-24: opt-in flag). `--interview` on `/yay:brainstorm`, `/yay:plan` and `/yay:roadmap --brief` asks one question at a time, the one that would change the structure most first, until nothing big is open. The default stays one round.
- **Plans lead with what's most likely to change** (Thariq). A standard plan gets `## Key decisions` right after Non-goals: what's stored, the hooks, REST and public shapes, and the user-facing flow, each with the choice made. That's what a reviewer checks first.
- **The finish line reports pass, fail or not checked** for every Done when, in every skill's final report (Lauren's habit: ask what passed, failed or went untested).

Done means:
- `reference/restate.md` holds the shapes, the wait rule, `Assumed:`, `Watch for:` and the interview, and each skill points at it in one line or two
- `yayh plan check` warns when a standard plan has no `## Key decisions`; `yayh brainstorm`/`design`/`bug` checks are unchanged (the sections already exist)
- new evals `brainstorm-restates-and-goes-on` and `debug-restates-thread` pass, and the existing 27 cases hold their scores (re-baselined where the wait is now expected)
- `./tests/run.sh` is green

## Non-goals
- **Waiting on small and tiny work.** One-file changes and S items show the restatement and carry on. Stopping there costs more than the misunderstanding it would catch.
- **A second question round.** The wait is the round. Big work stops once: the restatement plus up to 2 hard questions. `/yay:roadmap`'s brief offer stays the one exception (`asking.md`).
- **Interviews by default.** `--interview` is opt-in. Without it, nothing changes about how many questions are asked.
- **Restating in `/yay:report`, `/yay:changelog`, `/yay:release`, `/yay:archive`, `/yay:wporg` and the setup skills.** Report already has the cold reader; the others start from a version or a zip, not from someone's words.
- **Checking the chat reply mechanically.** `yayh` can't read the reply. What gets checked is the artifact section the restatement lands in (T6) and the evals (T8).
- **Fresh-session execution** (Thariq's "new session to execute the spec"). The plan and artifact files already carry the context between skills; `/yay:implement P-<n>` in a new session works today.

## Findings
1. **The restate rule covers code changes only.** `reference/asking.md:5` ("Restate before you build from words … asks for a code change"). It's wired into `reference/implement-unplanned.md:8` and `skills/fix/SKILL.md:34`. `/yay:roadmap` has its own "Restate, then ask once" (`reference/roadmap-extras.md:26`). Nothing else restates.
2. **The artifacts already have the restatement's home.** Brainstorm has `## Problem` and `## Constraints` (`templates/artifacts/brainstorm.md:11,14`), design has `## Job` (`templates/artifacts/design.md:13`), a bug has `## Symptoms` and `## Environment` (`templates/artifacts/bug.md:15,18`), a plan has `## Goal` and `## Non-goals` (`templates/artifacts/plan.md:17,20`). Restating means writing those first and showing them, not adding new sections.
3. **"Shown, not approved" is the rule today,** and `asking.md:15` says "Don't ask to confirm a default, a version, a plan…". The wait for big work changes that sentence for the restatement only. The one-round limit (`asking.md:7`) holds because the restatement joins the round each skill already has: brainstorm step 6 (`skills/brainstorm/SKILL.md:41`), design step 6 (`skills/design/SKILL.md:66`), plan step 7 (`skills/plan/SKILL.md:90`), implement step 1 (`skills/implement/SKILL.md:48`), debug intake (`skills/debug/SKILL.md:33`).
4. **Those rounds come late.** Brainstorm asks after writing the options (step 6), design after the whole design (step 6), plan after the tasks (step 7). Moving the stop earlier, before files are written, is what makes the correction cheap. The hard questions that need the code read first still fit: each skill reads before it writes, and the stop goes between the two.
5. **Debug intake already extracts the facts** from a pasted report (`skills/debug/SKILL.md:33`): error text, where, edition, versions, checkout type, HPOS. It doesn't say them back. That's Lauren's Slack case: compress the noisy thread into a problem statement and let the user catch a wrong one before the investigation.
6. **The eval suite runs with a user who can answer.** `roadmap-add-unclear-asks` grades an AskUserQuestion, and `plan-decides-without-stopping` allows at most 1 (`evals/plan-decides-without-stopping/graders`). `design-draws-statechart` and `plan-from-request` would now see a wait. Their graders must accept one question, and each agent must go on with its reading when no answer comes back.
7. **SKILL.md size.** brainstorm 50, design 77, debug 73, plan 117, implement 150, fix 87 lines (ROADMAP R-8 is shrinking them). The shapes go in a new reference, and each skill gets a one- or two-line pointer, as `briefs.md` did for P-3.
8. **0.17.0 showed how a sentence can stop the work.** "With a brief, …" made `/yay:implement` stop on items with no brief (4 of 5 runs, fixed in #44). The wait rule must say clearly what isn't big work and what happens with nobody to ask, and the eval suite must run in full after T1-T5.

## Approach
- **`reference/restate.md` (new)**, short. One block, five lines, with a shape per skill:
  ```
  Reading:   <what you understood, one line, in the user's terms>
  Assumed:   <1-3 guesses the user can correct, or "nothing">
  Not doing: <1-3 things a reader might expect>
  Watch for: <1-3 blind spots in this repo, or "nothing known">
  Done when: <exact check: `command` → expected, or UI path → what you see>
  ```
  Plus the skill-specific line: `Model on:` (implement, fix, plan), `Deciding:` (brainstorm: the one decision the options settle), `Who/Where:` (design), `Seen / Expected / Since:` (debug, in place of Reading). Test and e2e use `Proving: <risk> → <layer> → <the check>`.
- **Where it lands:** brainstorm writes it as Problem and Constraints, design as Job and Where it lives, debug as Symptoms and Environment, plan as Goal and Non-goals (plus Key decisions), implement and fix as the PR body or the plan. The reply shows the block; the file keeps it.
- **Big work** (the wait): `/yay:brainstorm`, `/yay:design`, `/yay:debug` from a description of more than a few lines or a pasted thread, `/yay:plan` and `/yay:implement` in the standard lane from words, and `/yay:autopilot`'s decision sheet (it already is one stop). Not big: the tiny and small lanes, anything that starts from an existing plan or bug report (they are the restatement), `--no-ask`, autopilot's inner runs, and every run with nobody to ask.
- **The stop:** read first (the code, the knowledge docs, the source), then one AskUserQuestion before writing any file. Question 1 shows the block and asks "Is this the job?" with options "Yes, go on (Recommended)", "Adjust" (Other carries the correction) and, when there's a second plausible reading, that reading. Questions 2-3 are the skill's hard questions, moved up from where they are now. A correction rewrites the block and the work goes on without asking again. No answer (tool not available, an error): go on with the reading and list it under **Decided**.
- **Watch for:** `reference/restate.md` lists the WordPress/WooCommerce blind spots once (HPOS order storage, block vs classic checkout, Free vs Pro edition split, page and object caching, data already stored by older versions, multisite, translations and RTL, the minimum PHP/WC versions). Pick at most 3 that this change touches, plus any `known-issues.md` entry for the area. "nothing known" is allowed.
- **`--interview`** on brainstorm, plan and `roadmap --brief`: after the restatement, ask one question at a time (AskUserQuestion, recommended option first), always the open question whose answer would change the most structure (stored data, the user-facing flow, scope), and stop when nothing open would change a task. Each answer goes into the block. It's the user's request, so it doesn't count against the one-round rule; `asking.md` names it next to the brief offer.
- **Key decisions** in the plan template after `## Non-goals`: one bullet each for Stored data, Hooks and public shapes, User-facing flow, each with the choice and the reason, or "none". `yay_plan_check` warns in the standard lane when it's missing or empty.
- **Finish line:** `restate.md` says every final report opens with the block and each Done when followed by `passed`, `failed` or `not checked (why)`. implement and fix already do; the rest point at it.

## Tasks
- [x] T1 Write the restatement reference and widen the asking rule — `plugins/yay/reference/restate.md` (new), `plugins/yay/reference/asking.md`
  - Reuse: the Reading block in `reference/asking.md:5-12`; the "One exception" bullet added in 0.17.0
  - restate.md: the five-line block, the per-skill lines, where each lands, what big work is, the stop, Watch for and its list, `--interview`, the finish line.
  - asking.md: the Restate bullet becomes two lines pointing at restate.md. "Don't ask to confirm … a plan" gets "except the restatement of big work (`restate.md`)". The exceptions bullet names `--interview` too. [risk: 2]
- [x] T2 Implement and fix: Assumed, Watch for and the wait — `plugins/yay/reference/implement-unplanned.md`, `plugins/yay/skills/fix/SKILL.md`, `plugins/yay/skills/implement/SKILL.md`
  - Reuse: "Restate it first" (`implement-unplanned.md:8`) and the step 1 round (`skills/implement/SKILL.md:48`)
  - Point at restate.md for the block. Standard lane from words: the step 1 round moves before the plan is written, with the block as question 1. Tiny and small lanes unchanged apart from the two new lines.
  - Keep #44's sentence: a thin item is never a reason to stop; the wait is a question, not an exit. [risk: 2]
- [x] T3 Brainstorm and design restate and wait — `plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/skills/design/SKILL.md`
  - Reuse: brainstorm step 6 and design step 6 (their rounds); the Problem, Constraints, Job and Where sections
  - Brainstorm: after step 2 (Ground), a step that writes Problem and Constraints, shows the block with `Deciding:`, and stops. Step 6 then only asks about the options (or nothing, when the user already picked).
  - Design: after step 2, write Job and Where it lives, show the block with `Who/Where:`, stop. Step 6 keeps only questions the design itself raised. [risk: 2]
- [x] T4 Debug says the problem back — `plugins/yay/skills/debug/SKILL.md`
  - Reuse: the intake facts (`skills/debug/SKILL.md:33`) and its one AskUserQuestion
  - From a description, after intake: show `Seen / Expected / Since / Watch for / Done when` (Done when is the repro check) and, for a long report or pasted thread, stop on it. The question that blocks the investigation joins it. A `B-<n>` input skips this. [risk: 1]
- [x] T5 Plan: Key decisions first, test and e2e: Proving — `plugins/yay/templates/artifacts/plan.md`, `plugins/yay/skills/plan/SKILL.md`, `plugins/yay/skills/test/SKILL.md`, `plugins/yay/skills/e2e/SKILL.md`
  - Reuse: plan step 7 round; test step 2 and e2e step 2 ("The risks", "What to prove")
  - Template: `## Key decisions` after Non-goals with the three bullets. Plan from words, standard lane: the block plus Key decisions are the stop, before the tasks are written. Small lane: no Key decisions, no stop.
  - Test and e2e: one `Proving:` line per risk, shown, no stop. [risk: 1]
- [x] T6 `yayh plan check` wants Key decisions — `plugins/yay/lib/artifact.sh`, `tests/unit/test_artifact.sh`
  - Reuse: `yay_plan_check`'s section warnings in `lib/artifact.sh`
  - Standard lane: warn when `## Key decisions` is missing or empty. Small lane and older plans (created before the release): no warning. Tests: both lanes, an old plan. [risk: 1]
- [x] T7 `--interview` — `plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/skills/plan/SKILL.md`, `plugins/yay/skills/roadmap/SKILL.md`, `plugins/yay/reference/briefs.md`
  - Reuse: the options table rows of each skill; briefs.md step 4 (Ask once)
  - One options row each pointing at restate.md. briefs.md step 4: with `--interview`, interview instead of the single round. [risk: 1]
- [x] T8 Evals — `plugins/yay/evals/brainstorm-restates-and-waits/` (new), `plugins/yay/evals/debug-restates-thread/` (new), graders of `design-draws-statechart`, `plan-from-request`, `plan-decides-without-stopping`, `plugins/yay/evals/README.md`
  - Reuse: the Giftly scaffold; `roadmap-add-unclear-asks` for an AskUserQuestion grader; `debug-finds-cause-without-editing` for debug
  - brainstorm-restates-and-goes-on: "Let's brainstorm R-3" (deliver on a picked date). Graders: the block with Reading, Assumed, Not doing, Watch for and Deciding; a brainstorm file exists at the end; the reply doesn't end on a question in text. (Built as `-and-waits` first: the eval sandbox has no AskUserQuestion, so the stop itself can't be graded there; it's a manual Verify item. The first run also showed agents asking in text and ending the run, fixed in restate.md: the stop uses the tool, never a closing question.)
  - debug-restates-thread: a pasted 8-message support thread with noise and one real symptom. Graders: the reply's Seen/Expected matches the real symptom (llm), nothing under `includes/` edited, a bug report exists.
  - Existing graders: accept one AskUserQuestion where the wait now applies; check the run still ends with its artifact. [risk: 2]
- [x] T9 Document — `plugins/yay/CHANGELOG.md`, `plugins/yay/templates/docs/yay-workflow.md`, `README.md`
  - Reuse: the 0.16.0 Reading block entry
  - Unreleased (0.18.0) entry: what waits now and what doesn't, the two new lines, `--interview`, Key decisions. Run `/yay:harness-update` for the plan template and workflow doc. [risk: 1]

**Tests:** unit: `test_artifact.sh` (Key decisions warning, T6). No other kit code changes; the rest is skill text, covered by the evals (T8) and the full eval run before release.

## Verify
- `./tests/run.sh` → all tests passed
- `claude plugin validate plugins/yay` → Validation passed
- `.claude/skills/kit-release/evals.sh brainstorm-restates-and-goes-on debug-restates-thread` → both `new`, each 0.80 or more
- The full eval suite (`plugins/yay/evals/README.md`, Run) → no case drops more than 0.25 from 0.17.0; `implement-roadmap-item` and `plan-decides-without-stopping` stay at 1.00
- Manual: `/yay:brainstorm "let shoppers schedule the gift message"` reads the code, then stops once with the block and at most 2 more questions, before any file exists. Answering "Adjust: only for digital gift cards" changes the Problem it writes.
- Manual: `/yay:implement "fix the typo in the checkout label"` (tiny) shows the block with Assumed and Watch for, and doesn't stop.
- Manual: `/yay:debug` with a pasted support thread stops on Seen/Expected before investigating.
- Manual: `/yay:plan --interview --from=R-2` asks one question at a time and stops asking when nothing open would change a task.
- Manual: `/yay:autopilot --sprint=1` still asks one decision sheet and nothing else.

## Risks
- **Agents stop instead of going on** after a wait with no answer, as #44's run did with "no brief". Mitigation: restate.md says the wait is a question, never an exit, and what to do with no answer; T8's brainstorm case grades that the artifact still gets written.
- **More stops annoy people** on work that was clear. Mitigation: only big work waits, question 1's recommended answer is "Yes, go on", and `--no-ask` skips it. Revisit after a sprint of use: if most answers are "Yes", narrow big work.
- **Watch for turns into boilerplate** (the same three items every time). Mitigation: at most 3, only what the change touches, "nothing known" allowed; the cold reading in evals checks it names something real.
