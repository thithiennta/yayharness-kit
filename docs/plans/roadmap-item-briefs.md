---
id: P-3
title: Product briefs for roadmap items
status: done
from: conversation 2026-11-23 (product manager wants to hand developers a clear "what it is" per roadmap item)
roadmap:
design:
trello:
type: feat
branch: feat/p-3-roadmap-item-briefs
pr:
editions: [free, pro]
created: 2026-11-23
---
# P-3 Product briefs for roadmap items

## Goal
A product manager working in Claude Code with the repo can give any roadmap item a **brief**: one plain-language page that says clearly what the item is, so developers (and Claude in brainstorm, design, plan and autopilot) stop guessing. The developers still decide how to build it.

- `/yay:roadmap --brief=R-12 "<rough idea>"` interviews the PM once, then writes `docs/briefs/R-12-<slug>.md` and links it from the item (`- brief: docs/briefs/R-12-<slug>.md`).
- `/yay:roadmap --brief "<rough idea>"` with no id first adds the item to Later, so a PM can describe work before it's scheduled.
- **Briefs are offered once the roadmap is decided.** After `/yay:roadmap` has written and committed a plan, a version plan or `--add` items, and the user is there, it offers to brief every item it just added or scheduled that has none, whatever its size (decided with the user 2026-11-23: all items, same brief). The offer never comes mid-planning: the schedule is settled first.
- Every skill that starts from a roadmap item reads its brief when there is one. The plan's Goal starts from the brief, and every **Done when** line becomes a Verify check.
- An item with no brief works exactly as today: no block, no warning.

Done means:
- `yayh brief new|check|path|render` work, in English and Vietnamese, with unit tests
- brainstorm, design, plan and autopilot read the brief, and `yayh plan check` warns when a plan covers fewer checks than its brief's Done when
- `/yay:archive` removes a brief with its item
- one eval case passes (`brief-from-rough-idea`), `./tests/run.sh` is green

## Non-goals
- **Blocking or warning on items without a brief.** Decided with the user: no brief means today's behaviour.
- **Putting the brief inside the sprint file.** The sprint file stays the schedule; the brief is the spec (decided 2026-11-23: sprint files stay scannable, real headings, roadmap commands don't read every brief, a brief can exist before scheduling, and it renders as one page).
- **Importing briefs from Trello, Google Docs or Claude Docs.** The PM works in Claude Code for now. Revisit if that changes (option D of the brainstorm).
- **Technical design in the brief.** How it's built stays in `/yay:brainstorm`, `/yay:design` and `/yay:plan`. The brief may have an optional, folded For developers section for known constraints, nothing more.
- **A new id prefix.** A brief belongs to one `R-<n>` and is found by it; it never takes an `id:` (that would make `yayh artifact resolve R-<n>` ambiguous, `lib/frontmatter.sh:79-86`).

## Findings
1. **Name clash with release briefs.** `yayh roadmap brief <x.y.z>` already writes `docs/roadmap/release-<v>.md` (`lib/roadmap.sh:1124-1130`, `skills/roadmap/SKILL.md:146`). Docs and messages call the new one an **item brief**, its command is `yayh brief …` (not `yayh roadmap brief`), and it lives in `docs/briefs/`, not `docs/roadmap/`.
2. **Items already carry a one-line `acceptance`** that the plan's Goal and Verify start from (`skills/plan/SKILL.md:46,53`, `lib/roadmap.sh:438-478`). The brief doesn't replace it: the acceptance stays the item's one-line summary, so `roadmap check` keeps working, and the brief's Done when is the full list.
3. **Item text is moved as a block** by `yayh roadmap move` (`lib/roadmap.sh:331-355`), and `roadmap set` appends a bullet after the last one (`lib/roadmap.sh:263-298`), so `- brief:` is just another bullet; no parser change.
4. **The plain-language checker exists** in `lib/report.sh` (`yay_report_check`): sections from stdin, language limits, code, HTML, emoji, jargon, a folded developer section, and the cold reader in `skills/report/SKILL.md`. The brief reuses it rather than a second copy (T1).
5. **Archive works per folder with `id:` front-matter** (`lib/archive.sh:72-107`) and roadmap items separately (`:91-104`). A brief has no id, so it's archived with its item, not on its own (T6).
6. **Where the item is read:** `/yay:brainstorm` step 1 (`skills/brainstorm/SKILL.md:28`), `/yay:design` step 1 (`skills/design/SKILL.md:29`), `/yay:plan` Acceptance (`skills/plan/SKILL.md:46`), `/yay:implement` with no plan (`reference/implement-unplanned.md`), and autopilot's prepare agents, which follow the brainstorm and plan skills (`skills/autopilot/SKILL.md:47`). One "read the brief" line in each covers them all.
7. **`report.lang` hasn't shipped** (0.17.0 is unreleased), so it can be renamed for free now that briefs need it too (T7).

## Approach
- **The brief file** `docs/briefs/R-<n>-<slug>.md`:
  ```
  ---
  item: R-12
  title: Express checkout buttons
  status: draft | ready
  lang: en
  author: …
  created: 2026-11-23
  ---
  # R-12 Express checkout buttons
  ## In one line          what it is and why, for the busy reader
  ## Problem              who has it, how we know (tickets, reviews, numbers)
  ## What the user sees   the main flow, numbered, in screen words
  ## Rules and edge cases one rule per bullet: limits, conflicts, empty states, Free vs Pro
  ## Out of scope         what we deliberately don't do (at least one line)
  ## Done when            - [ ] 3-7 checks a tester could tick
  ## Open questions       what developers must not decide alone, or "None"
  ## For developers       optional, last, folded: known constraints only
  ```
  Vietnamese headings come from the same table as reports (Tóm tắt, Vấn đề, Người dùng thấy gì, Quy tắc và trường hợp đặc biệt, Ngoài phạm vi, Xong khi, Câu hỏi mở, Dành cho lập trình viên).
- **Check** (`yayh brief check`): the report checker with the brief's sections and limits (700 words, 1000 in Vietnamese; 8 bullets per section, 12 steps in What the user sees), plus three brief rules: Done when has 3-7 `- [ ]` lines (error below 3, warn above 7); Out of scope isn't empty or only "none" (warn); Open questions left open keeps `status: draft` (the skill marks `ready` only when check passes and every question is answered or says "None").
- **Interview** (`reference/briefs.md`, called from `/yay:roadmap --brief`): read the item, its evidence and screenshots; draft the brief from the PM's words; ask **one** AskUserQuestion round (at most 3 questions) on the gaps PMs usually leave: an edge case the flow implies, what's out of scope, how we'll know it's done. Then check, then a cold reader: a developer new to the repo reads only the brief and says what they would have to guess. Rewrite until it guesses nothing important, at most 2 rounds. Share as a page (`yayh brief render`, same locked template as reports) when the PM wants to send it.
- **The offer after planning** (T9). Where it runs: the last step of Plan (after step 8, write and commit), of Version plan (after step 5) and of `--add`, after the report of what was written. Never in `--status`, `--close`, `--dry-run`, `--multi-agent`, autopilot or any run with nobody to answer; there it's only a **Next** line: `/yay:roadmap --brief=R-<n>` for each candidate.
  1. Candidates: every item this run added or scheduled with no brief yet (`yayh brief path` exits 3), S, M and L alike. None: no offer.
  2. One AskUserQuestion: "The roadmap is written. Write briefs for these items now?", with options: all candidates (Recommended, listing them), only the first sprint's, pick in chat, not now. With many items, the round's questions go first to the items whose brief has the biggest gaps (usually M and L); the others keep their gaps as Open questions. With "not now" the run ends, and the Next line names the commands.
  3. For the chosen items, draft every brief first from what the run already gathered (evidence, why, acceptance, screenshots), then ask **one** round for all of them together: at most 4 questions, on the gaps that matter most across the briefs (an edge case, out of scope, how we'll know it's done), each question naming its item. Gaps that didn't make the round go into that brief's Open questions, and the brief stays `draft`.
  4. Check, cold reader and commit as in `--brief`, one commit for all briefs (`docs(roadmap): brief R-3, R-5`).

  Asking rules: `reference/asking.md` allows one round per run. The offer is a second, optional round that starts a new job only after the first one is finished and written, so briefs.md states it as the one exception, and a run that needed no planning question asks only this.
- **Developers' side:** one line in each reading skill: "If the item has a brief (`yayh brief path R-<n>`), read it first. It's the product source of truth: the Goal starts from In one line, Rules and edge cases bind every option, Out of scope is a Non-goal, and every Done when line becomes a Verify check. An open question there goes to the run's one question round or becomes a backlog decision note." `yayh plan check` warns when the plan's roadmap item has a brief with N Done when lines and the plan's Verify has fewer than N items.

## Tasks
- [x] T1 Share the plain-language checker between reports and briefs — `plugins/yay/lib/report.sh`, `tests/unit/test_report.sh`
  - Reuse: `yay_report_check`'s awk, `_report_limits`, `_report_dev`, `_report_md2html`/`_report_md2text`, `page.html`
  - Extract `_plain_check <file> <sections> <limits> <options>` (options: devs, steps heading, steps max, bullets max) from `yay_report_check`; `yay_report_check` calls it with no behaviour change. Same for `_plain_render <file> <lead> <dev> [--text]`.
  - Callers: `yay_report_check`, `yay_report_render` (T1), `yay_brief_check`, `yay_brief_render` (T2). The existing report tests must pass unchanged. [risk: 2]
- [x] T2 `yayh brief new|check|path|render` — `plugins/yay/lib/brief.sh` (new), `plugins/yay/bin/yayh`, `plugins/yay/templates/brief/brief.md`, `plugins/yay/templates/brief/vi/brief.md`, `tests/unit/test_brief.sh` (new)
  - Reuse: `_plain_check`/`_plain_render` (T1), `_report_slug` (Vietnamese slugs), `yay_roadmap_get`/`yay_roadmap_set` for the item and the `- brief:` bullet, `yay_fm_get`
  - `new R-<n> [--lang=]`: fails when the item doesn't exist or already has a brief; title from the item; writes the file, sets `- brief:` on the item, prints the path. `path R-<n>`: the brief's path, exit 3 when none. `check`: T1 plus the Done when, Out of scope and status rules above. `render [--text]`: the page next to nothing in git: `.yay/briefs/R-<n>.html` (gitignored), or text.
  - Callers: `/yay:roadmap --brief` (T4), the reading skills (T5), `yayh plan check` (T5), archive (T6). [risk: 2]
- [x] T3 Register the folder — `plugins/yay/templates/registry.tsv`, `plugins/yay/templates/gitignore.lines`, `plugins/yay/reference/artifacts.md`, `plugins/yay/templates/CLAUDE.managed.md`, `plugins/yay/templates/docs/yay-workflow.md`
  - Reuse: the `docs/designs/.gitkeep` seed row; the `.yay/reports/` gitignore line; the Design section of `artifacts.md` as the model for a new **Item brief** section (and a note that it's not the release brief)
  - CLAUDE.md row: "Describe an item for developers | `/yay:roadmap --brief=R-<n>` | `docs/briefs/`". [risk: 1]
- [x] T4 The interview — `plugins/yay/reference/briefs.md` (new), `plugins/yay/skills/roadmap/SKILL.md`, `plugins/yay/skills/go/SKILL.md`
  - Reuse: `reference/asking.md` (one round, recommended answer first), "Restate, then ask once" in `reference/roadmap-extras.md:26`, the cold reader in `skills/report/SKILL.md` step 5 with `yayh model resolve reader`, screenshots in `reference/artifacts.md`
  - roadmap SKILL.md: one Options row (`--brief[=R-<n>] "<notes>"`) pointing at briefs.md; no other growth (it's long already, ROADMAP R-8). `/yay:go`: "describe a roadmap item for the team, write a spec or brief" → `/yay:roadmap --brief`.
  - The brief commit: on a non-base branch `docs(roadmap): brief R-<n>`, like other roadmap writes. [risk: 1]
- [x] T5 Developers' skills read the brief — `plugins/yay/skills/brainstorm/SKILL.md`, `plugins/yay/skills/design/SKILL.md`, `plugins/yay/skills/plan/SKILL.md`, `plugins/yay/reference/implement-unplanned.md`, `plugins/yay/lib/artifact.sh`, `tests/unit/test_artifact.sh`
  - Reuse: the Acceptance bullet in `skills/plan/SKILL.md:46`; `yay_plan_check` warnings in `lib/artifact.sh`
  - The one line from Approach in each skill's source step. `yay_plan_check`: when `roadmap:` names an item with a brief, warn "brief R-<n> has N Done when checks; Verify has M". Test: a plan with fewer Verify items than Done when lines warns, one with as many doesn't, and no brief means no warning. [risk: 1]
- [x] T6 Archive briefs with their item — `plugins/yay/lib/archive.sh`, `tests/unit/test_archive.sh`
  - Reuse: the roadmap branch of `_yay_archive_records` (`lib/archive.sh:91-104`) and the archive row format
  - When an item is archived, its brief (by `item:`) goes too, with its own row (`R-<n> brief`, same commit column). A brief whose item stays is kept. Test both. [risk: 2]
- [x] T7 One language key for reports and briefs — `plugins/yay/lib/report.sh`, `plugins/yay/lib/harness.sh`, `plugins/yay/reference/config.md`, `plugins/yay/reference/config.schema.json`, `plugins/yay/skills/report/SKILL.md`, `plugins/yay/CHANGELOG.md`, `tests/unit/test_report.sh`
  - Reuse: the `report.lang` code paths added in 0.17.0
  - Rename `report.lang` to `language` (top level, `en|vi`), read by reports and briefs. It hasn't shipped, so no migration. [risk: 1]
- [x] T9 Offer briefs once the roadmap is decided — `plugins/yay/reference/briefs.md`, `plugins/yay/skills/roadmap/SKILL.md`, `plugins/yay/reference/asking.md`
  - Reuse: the interview from T4 (drafting, one round, check, cold reader); `yayh brief path` (T2) to find items without a brief; the Next line rule in `reference/asking.md`; Plan step 8, Version plan step 5 and Quick edits `--add` in `skills/roadmap/SKILL.md`
  - briefs.md: an **Offer after planning** section with the four steps above. roadmap SKILL.md: one line at the end of Plan, Version plan and `--add`: "Then offer briefs (`reference/briefs.md`, Offer after planning)". asking.md: one line naming the exception (an optional follow-up round after the work is written, never before). [risk: 1]
- [x] T8 Eval and changelog — `plugins/yay/evals/brief-from-rough-idea/` (new), `plugins/yay/evals/README.md`, `plugins/yay/CHANGELOG.md`
  - Reuse: `evals/report-done-from-tech-notes/` as the model; the Giftly scaffold
  - Prompt: a PM's rough paragraph for an existing `R-2`. Graders: fires the roadmap skill, `docs/briefs/R-2-*.md` exists, the item gets `- brief:`, Done when has 3-7 checkable lines, Out of scope has a real line, no code outside For developers, nothing invented, product code untouched. [risk: 1]

**Tests:** unit: `test_brief.sh` (new, sub-commands, both languages, the three brief rules), `test_report.sh` (unchanged results after T1), `test_artifact.sh` (plan check warning), `test_archive.sh` (brief goes with its item). Eval: `brief-from-rough-idea`.

## Verify
- ✅ `./tests/run.sh` → all tests passed
- ✅ `claude plugin validate plugins/yay` → Validation passed
- ✅ `cd "$(mktemp -d)" && git init -q && printf -- '---\nhorizon: 2027-01-01\nsprint_length: 2w\n---\n# Roadmap\n\n## Later\n\n### R-1 Gift wrap\n- status: todo\n- size: M\n' > r.md && mkdir -p docs && mv r.md docs/roadmap.md && yayh brief new R-1 && yayh roadmap get R-1 brief` → docs/briefs/R-1-gift-wrap.md
- ✅ `yayh brief check R-1` on the empty template → exit 1
- ✅ Manual: `/yay:roadmap --brief=R-1 "customers want gift wrap at checkout"` asks one round, writes a brief that passes check, and the cold reader lists nothing important to guess.
- ✅ Manual: `/yay:roadmap --add="Gift wrap; Gift receipts" --size=M`: the items are written and committed first, then one question offers briefs for both; picking "all" drafts both and asks at most 4 questions in one round, each naming its item.
- ✅ Manual: an `--add` of one S item also gets the offer.
- ✅ Manual: `/yay:roadmap --status` and `/yay:roadmap --dry-run` never offer briefs.
- ✅ Manual: `/yay:plan --from=R-1` with that brief: the Goal starts from In one line, and Verify has a check per Done when line.
