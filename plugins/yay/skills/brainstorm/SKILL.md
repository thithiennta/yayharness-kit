---
name: brainstorm
description: Explore options for a Yay plugin change before planning. Use when the user says "brainstorm", "explore options", "how should we approach", or starts a roadmap item, backlog idea or unclear fix. Grounds 2-4 options in the code with tradeoffs and sizes, recommends one, previews them in plain words and discusses until you pick, then records docs/brainstorms/ BS-<n>.
argument-hint: "<topic> [--from=R-<n>|BL-<n>|B-<n>] [--quick] [--research] [--yes]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, WebSearch
---

# /yay:brainstorm

Arguments: `$ARGUMENTS`

Turn a topic into a recorded decision: a new `BS-<n>` file that `/yay:plan` builds on. This skill writes **only** that file.

## Options

| Option | Effect |
|---|---|
| `<topic>` | What to explore. Optional with `--from`. |
| `--from=R-<n>\|BL-<n>\|B-<n>` | Start from a roadmap item, backlog idea or bug. Read it, and record it in `from:`. |
| `--quick` | Two options, no subagents. Fine for small, clear choices. The preview still runs. |
| `--research` | Also search the web for how WooCommerce core or common plugins solve this, or the WP/WC APIs involved. Cite the sources. |
| `--yes` | Skip the preview (step 5) and write the brainstorm as `open`. |

## Steps

1. **Source.** With `--from`, run `yayh artifact resolve <id>` and read it. For a roadmap item, read its `### R-<n>` entry in the sprint file `resolve` gives. Its `acceptance` line is a constraint every option must meet. If the item has a brief (`yayh brief path R-<n>`), read it first: it's the product source of truth (`${CLAUDE_PLUGIN_ROOT}/reference/briefs.md`, For developers' skills). Its rules, edge cases and Out of scope bind every option too, and an option that breaks one says so. For a bug, its root cause and fix options are the starting point. For a backlog note, its question and default become the Problem and option A. Look for an existing brainstorm on the same topic (`yayh artifact list brainstorm`) and offer to continue it instead.
2. **Ground it.** Read the CLAUDE.md project block and the relevant `docs/knowledge/` docs (follow the "Read when…" links), then the code the topic touches. Note the constraints that really bind:
   - editions: what's Free and what's Pro (`yayh config get editions`)
   - the PHP floor
   - WooCommerce surfaces: block vs classic checkout, HPOS, emails
   - existing data and options that must keep working
   - hard rules
3. **Develop the options:** 2-4 really different approaches, not variations on one, and only as many as really exist. Each option says how it works (citing files and hooks), pros, cons, risks, the edition split, and a size (S/M/L). With `--research`, add what you learned, with links. For big topics, you may check feasibility with one `Explore` agent per option, in parallel, its `model` and `effort` both from `yayh model resolve feasibility` (`${CLAUDE_PLUGIN_ROOT}/reference/models.md`).
4. **Recommend.** Pick one and say why in a paragraph, plus what would change your mind. Be honest when two are close.
5. **Preview.** Before writing the file, run the preview loop in `${CLAUDE_PLUGIN_ROOT}/reference/preview.md`. It's skipped only with `--yes`, "just write it" or "don't ask", autopilot, or another skill's flow such as `/yay:implement --explore`; never on a guess about the environment.
   - **The summary:** read `${CLAUDE_PLUGIN_ROOT}/skills/brainstorm/preview-summary.md` and show the summary in exactly that format, ending with its prompt line.
   - **Accepting:** picking an option, or "ok", "go", "write it" for the recommended one, accepts as **decided**. "Leave it open" accepts as **open**.
6. **Write it.**
   - `yayh artifact new brainstorm "<title>" from=<id>` prints the path.
   - A screenshot attached to the request (a UI to match, a bug, a layout): record it and keep it as in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Screenshots).
   - Fill in every template section from the accepted draft. Open questions are only what a human must answer (product intent, pricing tier, support load). Answers given in the preview go into Recommendation or the option they shape.
   - **Decided:** set `yayh fm set <file> decision "<option letter and name>"` and `yayh fm set <file> status decided`, and write any conditions the person gave into Recommendation.
   - **Preview skipped:** leave it `open`.
7. **Report.** Give the file, the preview rounds and what changed in them, the recommendation and the decision (if made), the open questions, and end with the **Next** line (`reference/asking.md`), usually `/yay:plan --from=BS-<n>`. If the arguments named `--decide`, `--options` or `--commit`, say in one line that they're gone: pick in the preview, ask for a number of options, or say "commit it".

## Don'ts
- Don't write a plan here: no task lists and no file-by-file changes. That's `/yay:plan`.
- Don't edit tracked docs such as the roadmap or an older brainstorm. The roadmap status changes when `/yay:implement` starts.
- Don't present options you haven't checked against the code as feasible, in the file or in the preview.
