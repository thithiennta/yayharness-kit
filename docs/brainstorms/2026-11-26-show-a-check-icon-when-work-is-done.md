---
id: BS-3
title: Show a check icon when work is done
status: decided
from:
decision: A + C: icon rule in reports, plus icons in rendered tracked docs
created: 2026-11-26
---
# BS-3 Show a check icon when work is done

## Problem
When a skill finishes, the user sees its result only as words: "pass", "ok", "done", "clean", "fail". In a long report these words all look the same, so it's hard to see at a glance what finished and what didn't. The user asked for a check icon on finished work.

Where these words come from today:

- **`yayh` output is TSV for the agent, not for people.**
  - `yayh doctor` prints `ok|warn|fail` (`plugins/yay/lib/doctor.sh:6,15`)
  - `yayh verify --run` prints `pass|fail|manual` (`plugins/yay/lib/verify.sh:30-31`)
  - `yayh status` prints a stage word (`plugins/yay/lib/status.sh:191`)
  
  Skills parse all three, and the user usually sees only the agent's summary of them, not the raw output.
- **The agent's report is what people actually read.** `/yay:implement` step 6 lists "the checks and their results" and a **Reviews** block where each reviewer says "clean" (`plugins/yay/skills/implement/SKILL.md:136-144`). `/yay:go` shows a short table of `yayh status` rows (`plugins/yay/skills/go/SKILL.md:18`). `/yay:setup` reports doctor rows. None of these has a rule for how to mark a result, so each run words it differently.
- **Icons already exist, but only in one place.** The wp.org report uses `✔`/`✅`/`❌` because the Plugins Team does (`plugins/yay/skills/wporg/references/report-template.md:8,21`). Nothing else uses them.

## Constraints
- **Parsers must not change.** Skills, `yayh next`, evals and the hooks read the TSV words (`ok`, `pass`, `done`, `decided`…). Icons must not go into TSV, front-matter statuses, `- [ ]`/`- [x]` task lines or roadmap `status:` values (`plugins/yay/reference/artifacts.md:91,125`).
- **The terminal renders GitHub-flavored markdown.** Emoji show up. Colour does not reach the user from Bash output, because tool output isn't reliably shown to them.
- **Shared rules live in `reference/asking.md`** (the report rules every `/yay:*` skill follows). Skill descriptions have a length limit (PR #53), so the rule can't go there.
- **Lesson from PR #52:** keep it a small, checkable rule, not a new step in every skill.
- **Evals:** report cases (`report-*`, `go-*`, implement and fix cases) that match result words would need a re-score if the wording changes. Keeping the word next to the icon (`✅ pass`) avoids that.
- No edition, PHP or WooCommerce impact. This is a kit-only change.

## Options
### A. One status-icon rule for every report
- How: add a short "Mark results" rule to `plugins/yay/reference/asking.md`, next to "End with one next step". It gives one fixed set, always with the word:
  - `✅` done, pass, ok, clean
  - `❌` fail
  - `⚠️` warn, pre-existing failure, or blocked
  - `⏭️` skipped or not run
  - `⬜` manual check left for a person
  
  Put the icon at the start of each result line: the checks, the Reviews lines, Verify items, doctor rows, the `/yay:go` table's stage column and the roadmap `--status` items. Update the `/yay:implement` Reviews example block (`skills/implement/SKILL.md:139-143`) so the model sees the rule in use there.
- Pros: it fixes the place people actually read. One rule covers every skill. No code change, no parser change, the TSV stays the same. Keeping the word next to the icon keeps screen readers, grep and the evals working.
- Cons: the model follows it, but nothing enforces it, so a run can drift. It only touches what the agent writes, not raw `yayh` output.
- Risks: icons everywhere get noisy. The rule should cover result lines only, not headings or prose.
- Size: S (one reference rule, one example block, spot-check two or three report evals)

### B. A human view in `yayh` itself
- How: add `--pretty` (or auto when stdout is a TTY) to `yayh doctor`, `yayh verify` and `yayh status`, mapping `ok/pass/done` → `✅`, `fail` → `❌`, `warn` → `⚠️` in aligned columns. The TSV stays the default for skills, and skills show the pretty output to the user as is.
- Pros: the icons come from code, so they're always the same, and testable in `tests/unit`. It's also useful when a developer runs `yayh` in their own shell.
- Cons: the user rarely sees raw `yayh` output in a session. The agent still rewrites results in its report, so without A's rule the report stays text-only. More code: three formatters, an `isatty` check and tests.
- Risks: if the TTY detection is wrong, a skill gets pretty output where it expects TSV and its parse breaks.
- Size: M

### C. Icons in the tracked files
- How: put the icons into the markdown the kit writes. `yayh roadmap render` adds `✅` before `done`/`shipped` items, the `/yay:go` and archive tables show an icon column, and verify ticks in plans render as `✅`.
- Pros: it's visible on GitHub and in editors, not only in the terminal.
- Cons: the parsers read these files. Statuses and `- [x]` lines must stay exact, so the icon can only go in rendered or extra text, and it can drift from the real status. GitHub already renders `- [x]` as a checked box. It changes 12 repos' docs on the next render. It overlaps with BS-2 (making the output files easier to read).
- Size: M

## Recommendation
**A.** The text the user finds hard to see is the agent's report, and A is the only option that changes that text. It's one rule in the file every skill already follows, with no parser or TSV risk. Keeping the word after the icon means nothing that greps for `pass` or `clean` breaks. B is a good follow-up if developers want the same icons in their own shell, and A's set gives B its icon table. C belongs in BS-2's work on the files, not here.

I'd change my mind if the user mostly means raw `yayh` output they run themselves (then B), or the rendered roadmap on GitHub (then C, folded into BS-2).

**Decided (2026-11-26): A + C, with emoji (`✅ ❌ ⚠️`).** The user wants the icons in the agent's reports and in the tracked docs. Conditions for the plan:
- Do A first. Its icon set is the one table C uses too.
- C puts icons only in rendered or display text (`yayh roadmap render` output, the tables the kit writes). It never goes in front-matter `status:`, roadmap `- status:` bullets, `- [ ]`/`- [x]` task lines or TSV. Parsers and `plan check` keep reading the plain words, and a unit test proves an icon-bearing file still parses.
- Line C up with BS-2 so the two changes to the templates and files don't collide.

## Open questions
- **Scope of the rule:** result lines only (recommended), or also the `Next:` line and section headings?
- **C's reach:** which tracked files get icons: only the rendered roadmap, or also the archive table and the plans' Verify lists? Do existing repos get them on their next render, or only new files?
- **Order with BS-2:** ship C inside BS-2's template work, or on its own first?
