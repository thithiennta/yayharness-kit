---
name: brainstorm
description: Explore options for a Yay plugin change before planning. Use when the user says "brainstorm", "explore options", "how should we approach", or starts a roadmap item, backlog idea or unclear fix. Challenges the idea, tries 2-4 directions against the code, throws most away, writes docs/brainstorms/ BS-<n> with the chosen direction and why, then asks you to pick.
argument-hint: "<topic> [--from=R-<n>|BL-<n>|B-<n>] [--quick] [--research]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, AskUserQuestion, WebSearch
---

# /yay:brainstorm

Arguments: `$ARGUMENTS`

Diverge: look at the problem and the range of answers, then choose a direction. "What if…?", with no commitments yet. The output is a `BS-<n>` file: the direction and why. It can be opinionated, and most ideas get thrown away. Breaking it into tasks is `/yay:plan`'s job. This skill writes **only** that file.

## Options

| Option | Effect |
|---|---|
| `<topic>` | What to explore. Optional with `--from`. |
| `--from=R-<n>\|BL-<n>\|B-<n>` | Start from a roadmap item, backlog idea or bug, recorded in `from:`. |
| `--quick` | Two directions, no challenge round. For small choices. |
| `--research` | Also search the web (WooCommerce core, common plugins, WP/WC APIs). Cite the sources. |

## Steps

1. **Source.** With `--from`, run `yayh artifact resolve <id>` and read it.
   - **Roadmap item:** its `acceptance` line binds every direction. If it has a brief (`yayh brief path R-<n>`), read it first: its rules, edge cases and Out of scope bind too (`${CLAUDE_PLUGIN_ROOT}/reference/briefs.md`, For developers' skills).
   - **Bug:** start from its root cause and fix options. **Backlog note:** its question and default are the starting point.

   If a brainstorm on the same topic exists (`yayh artifact list brainstorm`), offer to continue it instead.
2. **Ground it.** Read the project block, the relevant `docs/knowledge/` docs and the code the topic touches. Note what binds: the editions (`yayh config get editions`) and the existing data and options that must keep working.
3. **Challenge it.** List the assumptions behind the request (who it's for, what problem it really solves, what must not change) and check each against the code and the source. When the input is rough (a pain point or idea with no clear outcome) and not `--quick`, ask one AskUserQuestion of at most 3 questions whose answers change the direction, recommended answer first (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`). A clear request skips the question: write the assumptions down instead.
4. **Diverge.** Try 2-4 really different directions, each checked against the code (files and hooks) and sized S/M/L. Throw away the weak ones fast, with one line on why. With `--research`, add what you learned, with links.
5. **Choose.** Pick the direction you'd build and say why, and what would change your mind. List the risks and edge cases of the problem itself: data that exists, editions, block vs classic checkout, upgrades, what a merchant could break.
6. **Write it.** `yayh artifact new brainstorm "<title>" from=<id>` prints the path. Fill in the template with `status: open`: Problem (with the assumptions and the answers), Direction, Discarded, Risks and edge cases, Open questions (only what a human must answer). Keep an attached screenshot as in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Screenshots).
7. **Pick.** Show the direction and the discarded ideas in 1-2 plain lines each, then ask one AskUserQuestion: the chosen direction first, marked "(Recommended)", then the strongest discarded ones, plus at most 2 open questions. On a pick, run `yayh fm set <file> decision "<name>"` and `yayh fm set <file> status decided`. If they picked another direction, rewrite Direction to it and move yours to Discarded. With "don't ask", or no answer, leave it `open`. When `/yay:implement` runs this in its own flow, skip step 3's question and step 7: it asks.
8. **Report.** Give the file, the decision (or that it's open) and the open questions, and end with the **Next** line (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`), usually `/yay:plan --from=BS-<n>`.

## Don'ts
- Don't write a plan here: no task lists, no file-by-file changes.
- Don't edit tracked docs such as the roadmap or an older brainstorm.
