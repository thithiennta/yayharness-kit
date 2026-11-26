---
name: brainstorm
description: Explore options for a Yay plugin change before planning. Use when the user says "brainstorm", "explore options", "how should we approach", or starts a roadmap item, backlog idea or unclear fix. Grounds 2-4 options in the code with tradeoffs and sizes, recommends one, previews them in plain words and discusses until you pick, then records docs/brainstorms/ BS-<n>.
argument-hint: "<topic> [--from=R-<n>|BL-<n>|B-<n>] [--options=2-4] [--quick] [--research] [--decide] [--yes] [--commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, WebSearch
---

# /yay:brainstorm

Arguments: `$ARGUMENTS`

Turn a topic into a recorded decision: a `BS-<n>` file that `/yay:plan` builds on. The format is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Brainstorm). This skill writes **only** the new brainstorm file. It doesn't change code or other docs. Before writing, it shows the options as a plain summary and discusses them with the person until they pick one or leave it open (step 5).

## Options

| Option | Effect |
|---|---|
| `<topic>` | What to explore, in a few words. Optional when `--from` names the source. |
| `--from=R-<n>\|BL-<n>\|B-<n>` | Start from a roadmap item, backlog idea or bug. Read it, and record it in `from:`. |
| `--options=N` | How many options to develop (2–4, default 3). |
| `--quick` | One pass, no subagents: two options and a recommendation. Fine for small, clear choices. |
| `--research` | Also look outside the repo, for how WooCommerce core or common plugins solve this, or the relevant WP/WC APIs, using WebSearch. Cite the sources. |
| `--decide` | The preview must end in a picked option: "leave it open" isn't offered. When the preview is skipped, ask the user to pick an option in one round (at most 3 questions) and record it (`status: decided`). |
| `--yes` | Skip the preview (step 5) and write the brainstorm straight away, `status: open` unless `--decide`. Plain words work too: "no preview", "just write it". |
| `--commit` | Commit the file when you're on a non-base branch (`docs(plan): add BS-<n> …`), with its `docs/assets/BS-<n>` screenshots, if any. |

## Steps

1. **Source.** With `--from`, run `yayh artifact resolve <id>` and read it. For a roadmap item, `resolve` gives its sprint file (`docs/roadmap/sprint-<n>.md`, or `docs/roadmap.md` in an older repo): read its `### R-<n>` entry. Its `acceptance` line is a constraint every option must meet. If the item has a brief (`yayh brief path R-<n>`), read it first: it's the product source of truth (`${CLAUDE_PLUGIN_ROOT}/reference/briefs.md`, For developers' skills). Its rules, edge cases and Out of scope bind every option too, and an option that breaks one says so. Look for an existing brainstorm on the same topic (`yayh artifact list brainstorm`) and offer to continue it rather than duplicating it.
2. **Ground it.** Read the CLAUDE.md project block and the relevant `docs/knowledge/` docs (follow the "Read when…" links), then the code the topic touches. Note the constraints that really bind:
   - editions: what's Free and what's Pro (`yayh config get editions`)
   - the PHP floor
   - WooCommerce surfaces: block vs classic checkout, HPOS, emails
   - existing data and options that must keep working
   - hard rules
3. **Develop the options.** Each option says how it works (citing files and hooks), pros, cons, risks, the edition split, and a size (S/M/L). Make them really different approaches, not variations on one. With `--research`, add what you learned, with links. For big topics, you may run one `Explore` agent per option in parallel to check feasibility in the code, with the Agent tool's `model` and `effort` both set from `yayh model resolve feasibility` (model routing: `${CLAUDE_PLUGIN_ROOT}/reference/models.md`).
4. **Recommend.** Pick one and say why in a paragraph, plus what would change your mind. Be honest when two are close.
5. **Preview** (`${CLAUDE_PLUGIN_ROOT}/reference/preview.md`). Before writing the file, show the draft as a plain summary and discuss it with the person until they accept: answer their questions, apply their changes, and show the summary again whenever the draft changes (an option added, dropped or reworked, the recommendation moved, a data line changed). The loop rules, and when it's skipped (only `--yes`, "just write it" or "don't ask", autopilot, or another skill's flow such as `/yay:implement --explore`; never a guess about the environment), are in `preview.md`.
   - **The summary** goes in your reply, about 15-30 lines of plain words. Name screens, settings and flows the way a merchant or the team would, not file, class or function names (`file:line` only when a Must keep needs it). Each option's **Data** line is the exception: it names the exact option, meta key, table or column the option adds or changes, because where data lives is often what separates the options and what's hardest to undo. Full shapes, upgrades and uninstall belong in the plan.
     ```
     Brainstorm preview, nothing written yet: <title> (from <id>)
     Changed: <one line per change since the last summary>   (round 2 on)
     Problem: <1-2 lines>
     Must keep: <the constraints that bind: editions, block/classic checkout, existing data, the brief's rules>

     A. <name> (<S|M|L>)
        How: <1-2 lines>
        ✅ <main pros>  ⚠️ <main cons and risks>
        Data: <`key`/table and where it lives, or none>
     B. …

     Recommend: <letter>, because <why>. I'd switch to <letter> if <what would change your mind>.
     Open: <questions only a human can answer, each with the default, or none>
     ```
   - **Prompt:** `→ Reply with a letter to pick it, "ok" for <recommended letter>, "leave it open", or ask or change anything.` Leave out "leave it open" with `--decide`. Picking an option, or "ok", "go", "write it" for the recommended one, accepts as **decided**. "Leave it open" accepts as **open**. An answer that adds or replaces an option means grounding it in the code (step 3) before showing it.
6. **Write it.**
   - `yayh artifact new brainstorm "<title>" from=<id>` prints the path.
   - A screenshot attached to the request (a UI to match, a bug, a layout): record it and keep it as in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Screenshots).
   - Fill in every section from the accepted draft: Problem, Constraints, Options, Recommendation, and Open questions (what only a human can answer: product intent, pricing tier, support load). Answers given in the preview go into Recommendation or the option they shape, not Open questions.
   - **Decided:** set `yayh fm set <file> decision "<option letter and name>"` and `yayh fm set <file> status decided`, and write any conditions the person gave into Recommendation.
   - **Preview skipped:** with `--decide`, ask one AskUserQuestion whose first question is the options as choices, the recommended one first and marked "(Recommended)", plus at most 2 open questions the choice depends on, then record the decision as above. Without `--decide`, leave it `open`.
7. **Report.** Give the file, the preview rounds and what changed in them, the recommendation and the decision (if made), the open questions, and end with the **Next** line (`reference/asking.md`), usually `/yay:plan --from=BS-<n>`.

## Don'ts
- Don't write a plan here: no task lists and no file-by-file changes. That's `/yay:plan`.
- Don't edit tracked docs such as the roadmap or an older brainstorm. The roadmap status changes when `/yay:implement` starts.
- Don't present options you haven't checked against the code as feasible, in the file or in the preview.
