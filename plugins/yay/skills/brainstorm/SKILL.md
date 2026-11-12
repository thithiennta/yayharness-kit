---
name: brainstorm
description: Explore options for a Yay plugin change before planning. Use when the user says "brainstorm", "explore options", "how should we approach", or starts a roadmap item, backlog idea or unclear fix. Grounds 2-4 options in the code with tradeoffs and sizes, recommends one, and records it as docs/brainstorms/ BS-<n>.
argument-hint: "<topic> [--from=R-<n>|BL-<n>|B-<n>] [--options=2-4] [--quick] [--research] [--decide] [--commit]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, WebSearch
---

# /yay:brainstorm

Arguments: `$ARGUMENTS`

Turn a topic into a recorded decision: a `BS-<n>` file that `/yay:plan` builds on. The format is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Brainstorm). This skill writes **only** the new brainstorm file. It doesn't change code or other docs.

## Options

| Option | Effect |
|---|---|
| `<topic>` | What to explore, in a few words. Optional when `--from` names the source. |
| `--from=R-<n>\|BL-<n>\|B-<n>` | Start from a roadmap item, backlog idea or bug. Read it, and record it in `from:`. |
| `--options=N` | How many options to develop (2–4, default 3). |
| `--quick` | One pass, no subagents: two options and a recommendation. Fine for small, clear choices. |
| `--research` | Also look outside the repo, for how WooCommerce core or common plugins solve this, or the relevant WP/WC APIs, using WebSearch. Cite the sources. |
| `--decide` | After recommending, ask the user to pick an option (one round, at most 3 questions) and record it (`status: decided`). Without it, ask only if the user is around to answer. |
| `--commit` | Commit the file when you're on a non-base branch (`docs(plan): add BS-<n> …`), with its `docs/assets/BS-<n>` screenshots, if any. |

## Steps

1. **Source.** With `--from`, run `yayh artifact resolve <id>` and read it. For a roadmap item, `resolve` gives its sprint file (`docs/roadmap/sprint-<n>.md`, or `docs/roadmap.md` in an older repo): read its `### R-<n>` entry. Its `acceptance` line is a constraint every option must meet. Look for an existing brainstorm on the same topic (`yayh artifact list brainstorm`) and offer to continue it rather than duplicating it.
2. **Ground it.** Read the CLAUDE.md project block and the relevant `docs/knowledge/` docs (follow the "Read when…" links), then the code the topic touches. Note the constraints that really bind:
   - editions: what's Free and what's Pro (`yayh config get editions`)
   - the PHP floor
   - WooCommerce surfaces: block vs classic checkout, HPOS, emails
   - existing data and options that must keep working
   - hard rules
3. **Develop the options.** Each option says how it works (citing files and hooks), pros, cons, risks, the edition split, and a size (S/M/L). Make them really different approaches, not variations on one. With `--research`, add what you learned, with links. For big topics, you may run one `Explore` agent per option in parallel to check feasibility in the code, with the Agent tool's `model` and `effort` both set from `yayh model resolve feasibility` (model routing: `${CLAUDE_PLUGIN_ROOT}/reference/models.md`).
4. **Recommend.** Pick one and say why in a paragraph, plus what would change your mind. Be honest when two are close.
5. **Write it.**
   - `yayh artifact new brainstorm "<title>" from=<id>` prints the path.
   - A screenshot attached to the request (a UI to match, a bug, a layout): record it and keep it as in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Screenshots).
   - Fill in every section: Problem, Constraints, Options, Recommendation, and Open questions (what only a human can answer: product intent, pricing tier, support load).
6. **Decide** (with `--decide`, or when the user is present). Use one AskUserQuestion: the first question is the options, as choices, with the recommended one first and marked "(Recommended)". Add at most 2 more questions, and only for open questions the chosen option depends on. Leave the rest under **Open questions** for `/yay:plan`. Then:
   - set `yayh fm set <file> decision "<option letter and name>"`
   - set `yayh fm set <file> status decided`
   - write any extra conditions the user gave into Recommendation
7. **Report.** Give the file, the recommendation and the decision (if made), the open questions, and end with the **Next** line (`reference/asking.md`), usually `/yay:plan --from=BS-<n>`.

## Don'ts
- Don't write a plan here: no task lists and no file-by-file changes. That's `/yay:plan`.
- Don't edit tracked docs such as the roadmap or an older brainstorm. The roadmap status changes when `/yay:implement` starts.
- Don't present options you haven't checked against the code as feasible.
