---
id: P-4
title: Show a check icon when work is done
status: in-progress
from: BS-3
roadmap:
design:
trello:
type: feat
branch: feat/p-4-show-a-check-icon-when-work-is-done
pr:
editions: [free, pro]
lane: standard
created: 2026-11-26
---
# P-4 Show a check icon when work is done

## Goal
Finished work is easy to spot in the agent's reports, in the generated roadmap pages and in the plans' Verify lists (BS-3, decision A + C, emoji). The kit gains a command that adds the icons to the pages that already exist, and it runs after the kit release.

Done means:
- every `/yay:*` report starts each result line with a fixed icon, followed by the word: ✅ done/pass/ok/clean, ❌ fail, ⚠️ warn/blocked/pre-existing failure, ⏭️ skipped/not run, ⬜ manual check left for a person
- in the generated `docs/roadmap/v<x.y.z>.md` tables, a `done` or `shipped:<v>` item's Status cell reads `✅ done` / `✅ shipped:1.5.0`
- `yayh verify P-<n> --run --mark` writes `✅` or `❌` at the start of each command check in the plan's `## Verify`, and `/yay:implement` uses it, so a finished plan shows which checks passed
- marked Verify lists still parse: `yayh verify` and `yayh plan check` read them as before
- `yayh verify --backfill` marks ✅ on the Verify items of every `done` plan, and `yayh roadmap render` adds the icons to existing version pages, ready for the rollout
- no TSV output, front-matter status, roadmap `- status:` bullet or `- [ ]` task line changes

## Non-goals
- Icons in raw `yayh` TSV output (BS-3 option B). A `--pretty` view can come later.
- Icons in `docs/archive.md`, sprint files, brainstorms, bugs or backlog notes.
- **Rollout to the existing repos (deferred until after the kit release).** In this kit repo and each of the 12 harness repos, once they're on the new kit version (`/yay:harness-update`): on a `docs/check-icons` branch, run `yayh roadmap render` (split layout only), `yayh verify --backfill` and `yayh roadmap check`. Commit the changed `docs/roadmap/v*.md` and `docs/plans/*.md` as `docs: mark finished work with ✅`, open one PR per repo and merge it with a merge commit. No backlog note was written, because `yayh artifact new` doesn't run in the kit repo (no `.yay/config.json`).
- Running the old plans' Verify commands again during the backfill. The code has moved on since, so many would fail for reasons that have nothing to do with the plan.

## Findings
1. The Verify parser treats an item as a command check only when the text after the bullet **starts** with a backtick (`plugins/yay/lib/verify.sh:17`). A `✅ ` prefix would turn every marked command check into a manual one, so T1 strips a leading result icon before that test.
2. `plan check` finds command checks with an unanchored regex (`plugins/yay/lib/artifact.sh:234`) and counts items by bullet (`:257`, `:280`), so icons don't affect it. T1's test covers that anyway.
3. `/yay:harness-update` is forbidden to touch plans or the roadmap (`plugins/yay/skills/harness-update/SKILL.md:50`), so updating the existing pages can't go there. T3 adds a one-off command, and the deferred rollout (Non-goals) runs it in each repo through its own PR.
4. Nothing reads the generated `v*.md` tables except render's own `--check` comparison (`plugins/yay/lib/roadmap.sh:499`). Every repo's `roadmap check` warns until it re-renders, which the deferred rollout does.
5. `/yay:implement` step 3 already runs `yayh verify P-<n> --run` and pastes the result into the PR (`plugins/yay/skills/implement/SKILL.md:97`). That's the caller for `--mark`, and the marks then land in the same branch as the code.

## Approach
Model on: `yay_verify` in `plugins/yay/lib/verify.sh:32` — it already reads every Verify item and gives a pass or fail for each. `--mark` writes that same result back into the plan, and the roadmap icon follows `cell()` (`plugins/yay/lib/roadmap.sh:975`).
- **One icon set**, defined once in `reference/asking.md` (T5). The code uses only ✅ and ❌, and the model uses the whole set in reports.
- **Parsing:** `_yay_verify_items` strips `^(✅|❌|⚠️|⏭️|⬜)[[:space:]]+` from the item text before telling command checks from manual ones. The `text` column keeps the line without the icon.
- **`--mark`** (needs `--run`): rewrite only the `## Verify` section, through a temp file and `mv`. Each command item gets its new icon, replacing an old one. Manual items keep whatever icon a person gave them. `/yay:implement` puts ✅ on the manual checks it did by hand and ⬜ on those left for the reviewer.
- **`--backfill`**: for each plan whose `status` is `done` (`yay_artifact_list plan`), add ✅ to every Verify item that has no icon yet. Without running anything, ✅ here means "passed when the plan was finished", which is what `done` already claims. It prints `marked<TAB><path>` for each changed file, does nothing on a second run, and never touches plans that aren't `done`.
- **Roadmap:** in the version-page loop, the Status cell shows `✅ ` + status for `done` and `shipped*`. The comparisons and counts keep using `I_st`.

## Tasks
- [x] T1 Let marked Verify items parse: strip a leading result icon in `_yay_verify_items`, and add a test that a marked plan lists the same kinds, commands and expectations, and that `plan check` gives the same result — `plugins/yay/lib/verify.sh`, `tests/unit/test_verify.sh`
  - Reuse: `_vplan` fixture in `tests/unit/test_verify.sh`
- [x] T2 Add `--mark` to `yayh verify`: with `--run`, write ✅/❌ for each command item into the plan's Verify section (replacing an old icon, leaving manual items alone). Update the usage line and the `yayh` help — `plugins/yay/lib/verify.sh`, `plugins/yay/bin/yayh`, `tests/unit/test_verify.sh`
  - Reuse: `yay_verify`'s loop and `_yay_verify_items` (`plugins/yay/lib/verify.sh`), `yay_artifact_resolve`
  - Callers: `_yay_verify_mark()` → `yay_verify --mark`; `yayh verify --run --mark` → `/yay:implement` step 3 (T6)
- [x] T3 Add `yayh verify --backfill`: mark ✅ on every unmarked Verify item of each `done` plan. It prints the changed paths, a second run changes nothing, and plans that aren't `done` stay untouched — `plugins/yay/lib/verify.sh`, `plugins/yay/bin/yayh`, `tests/unit/test_verify.sh`
  - Reuse: `yay_artifact_list plan` (`plugins/yay/lib/artifact.sh:105`), `_yay_verify_mark()` from T2
  - Callers: `yay_verify_backfill()` → `yayh verify --backfill` → the deferred rollout (Non-goals)
- [ ] T4 In the version-page renderer, show the Status cell as `✅ <status>` for `done` and `shipped*` items, leaving counts and the `.versions` index plain. Extend the render test — `plugins/yay/lib/roadmap.sh`, `tests/unit/test_roadmap.sh`
  - Reuse: `cell()` in the render awk (`plugins/yay/lib/roadmap.sh:975`), the `test_vision_paragraph_survives_split_add_and_render` fixture (`tests/unit/test_roadmap.sh:394-419`)
- [ ] T5 Add a "Mark results" rule with the icon table to the shared report rules, right after "End with one next step". It covers result lines only (checks, Reviews lines, Verify items, doctor rows, `/yay:go` stage cells, roadmap `--status` items), and never headings, prose, TSV or front-matter. Document the Verify icons (`--mark`, `--backfill`) in the Plan section and the version-page icon in the Roadmap section of the artifacts reference — `plugins/yay/reference/asking.md`, `plugins/yay/reference/artifacts.md`, `plugins/yay/reference/testing.md` [risk: 1]
  - Reuse: the icons already used in `plugins/yay/skills/wporg/references/report-template.md:8`
- [ ] T6 Use the rule in the skills: in `/yay:implement` step 3, run `yayh verify P-<n> --run --mark` and mark the manual checks (✅ done by hand, ⬜ left for the reviewer); in step 6, update the Reviews example to `✅ clean` or a marked finding. `/yay:roadmap --status` and the `/yay:go` table point to the rule — `plugins/yay/skills/implement/SKILL.md`, `plugins/yay/skills/roadmap/SKILL.md`, `plugins/yay/skills/go/SKILL.md` [risk: 1]
  - Reuse: T5's rule (link to it by name, don't repeat the table)

**Tests:** [unit] test_verify_reads_marked_items (tests/unit/test_verify.sh) — an icon before a command check still parses as cmd, and plan check doesn't change; [unit] test_verify_mark_writes_icons (tests/unit/test_verify.sh) — pass becomes ✅, fail becomes ❌, a re-run replaces the icon, manual items keep theirs, other sections are untouched; [unit] test_verify_backfill_marks_done_plans_once (tests/unit/test_verify.sh) — only `done` plans change, existing icons stay, the second run prints nothing; [unit] test_vision_paragraph_survives_split_add_and_render, extended (tests/unit/test_roadmap.sh) — done and shipped items render ✅, `todo` stays plain, `render --check` is clean after a second render

**E2E:** none

## Verify
- `./tests/run.sh test_verify` → exit 0 (unit)
- `./tests/run.sh test_roadmap` → exit 0 (unit)
- `./tests/run.sh` → exit 0
- `grep -q 'Mark results' plugins/yay/reference/asking.md && grep -q '✅' plugins/yay/reference/asking.md` → exit 0
- `grep -n 'Mark results' plugins/yay/skills/implement/SKILL.md plugins/yay/skills/roadmap/SKILL.md plugins/yay/skills/go/SKILL.md` → exit 0
- `grep -q 'verify P-<n> --run --mark' plugins/yay/skills/implement/SKILL.md` → exit 0
- `test -z "$(git diff main -- plugins/yay/lib/status.sh plugins/yay/lib/doctor.sh plugins/yay/templates)"` → exit 0
- Run `/yay:go` in a plugin repo with work in flight: the stage column and any result lines start with an icon followed by the word.

## Risks
- **A parser misreads marked items.** T1 lands first, and its test proves it. Rollback: revert T1–T3. Marked files still read as manual checks, so they don't break, only lose their command checks.
- **`--mark` damages a plan.** It rewrites only `## Verify` through a temp file, and the plan is tracked, so `git checkout -- <plan>` restores it. T2's test checks that the other sections stay byte-identical.
- **Backfill claims too much.** It touches only `done` plans and runs nothing, so ✅ means "passed when the plan was finished". The rule in T5 says so.
- **Until the rollout, the repos' `roadmap check` doesn't warn.** It only warns after a repo moves to the new kit version, because the new renderer's output then differs from the old pages. Do the rollout soon after the kit release.
- **Report evals** match result words. The word stays after the icon, and `/kit-release` re-scores the cases whose skill text changed.
