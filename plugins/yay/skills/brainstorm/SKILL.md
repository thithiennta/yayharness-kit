---
name: brainstorm
description: Explore options for a Yay plugin change before planning. Use when the user says "brainstorm", "explore options", "how should we approach", or starts a roadmap item, backlog idea or unclear fix. Grounds 2-4 options in the code, recommends one, writes docs/brainstorms/ BS-<n>, then asks you to pick.
argument-hint: "<topic> [--from=R-<n>|BL-<n>|B-<n>] [--quick] [--research]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, AskUserQuestion, WebSearch
---

# /yay:brainstorm

Arguments: `$ARGUMENTS`

Turn a topic into a `BS-<n>` file that `/yay:plan` builds on. This skill writes **only** that file.

## Options

| Option | Effect |
|---|---|
| `<topic>` | What to explore. Optional with `--from`. |
| `--from=R-<n>\|BL-<n>\|B-<n>` | Start from a roadmap item, backlog idea or bug, recorded in `from:`. |
| `--quick` | Two options, for small choices. |
| `--research` | Also search the web (WooCommerce core, common plugins, WP/WC APIs). Cite the sources. |

## Steps

1. **Source.** With `--from`, run `yayh artifact resolve <id>` and read it.
   - **Roadmap item:** its `acceptance` line binds every option. If it has a brief (`yayh brief path R-<n>`), read it first: its rules, edge cases and Out of scope bind every option too (`${CLAUDE_PLUGIN_ROOT}/reference/briefs.md`, For developers' skills).
   - **Bug:** start from its root cause and fix options. **Backlog note:** its question and default become the Problem and option A.

   If a brainstorm on the same topic exists (`yayh artifact list brainstorm`), offer to continue it instead.
2. **Ground it.** Read the project block, the relevant `docs/knowledge/` docs and the code the topic touches. Note what binds: the editions (`yayh config get editions`) and the existing data and options that must keep working.
3. **Options.** 2-4 approaches, only as many as really differ, each checked against the code (cite files and hooks) and sized S/M/L. With `--research`, add what you learned, with links.
4. **Recommend** one, and say what would change your mind.
5. **Write it.** `yayh artifact new brainstorm "<title>" from=<id>` prints the path. Fill in the template, `status: open`. Open questions are only what a human must answer. Keep an attached screenshot as in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Screenshots).
6. **Pick.** Show each option in 1-2 plain lines with its size, and the recommendation. Then ask one AskUserQuestion: the options (recommended first, marked "(Recommended)"), plus at most 2 open questions the choice depends on. On a pick, run `yayh fm set <file> decision "<letter and name>"` and `yayh fm set <file> status decided`, and write the answers into Recommendation. With "don't ask", or no answer, leave it `open`. Inside `/yay:implement --explore`, skip this step: that skill asks.
7. **Report.** Give the file, the decision (or that it's open) and the open questions, and end with the **Next** line (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`), usually `/yay:plan --from=BS-<n>`.

## Don'ts
- Don't write a plan here (no tasks, no file-by-file changes).
- Don't edit tracked docs such as the roadmap or an older brainstorm.
