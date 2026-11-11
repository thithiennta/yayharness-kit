---
name: go
description: The front door to the Yay harness. Use when the user types /yay:go, says "what's next", "where are we", "continue", "go on", or asks for Yay work in plain words ("fix the coupon bug", "build R-12", "ship it", "plan the next sprint") without naming a skill. Shows the work in flight and runs the next step, or routes the request to the right /yay:* skill with the right options.
argument-hint: "[what you want, in plain words | R-<n> | P-<n> | BS-<n> | B-<n> | UX-<n>]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Skill, AskUserQuestion
---

# /yay:go

Arguments: `$ARGUMENTS`

One entry point, so nobody has to remember every skill and its options. This skill only routes: the skill it hands off to does the work, under its own rules. It writes nothing itself.

## No argument, or "next" / "continue" / "go on"

1. `yayh status` (scope, id, stage, next command, title; most urgent first).
2. Nothing in flight: say so, and offer `/yay:roadmap` (plan the next sprint) or a request in plain words.
3. Otherwise show the top 5 rows as a short table and say what the first one is. When the request was "next", "continue" or "go on", or the top row is this branch's own work (`here`), run it now: hand its `next` command to the Skill tool (or run it with Bash when it's a `git` or `gh` command). Otherwise end with `Next: <the top command>`, and run it if the user says "go".

## An id

`yayh next <id>` gives the command for that piece of work. Run it.

## Plain words

Route by what the user wants, not by keywords. Pass the user's own words on as the topic, and add only the options the request clearly implies.

| The user wants… | Run |
|---|---|
| to know where things stand, the sprint's progress | `/yay:roadmap --status` |
| to plan or re-plan sprints, add, move or drop roadmap items | `/yay:roadmap` (`--add="…"`, `--move=R-<n>:<n>`, `--drop=R-<n>`) |
| options for an idea, "how should we…" | `/yay:brainstorm "<topic>"` (`--from=R-<n>` when it names an item) |
| a design for a screen, modal or email | `/yay:design "<topic>"` |
| a plan, "break this down" | `/yay:plan "<topic>"` or `--from=<id>` |
| something built or changed: "add…", "make…", "rename…", "build R-12" | `/yay:implement "<requirement>"` or `<id>` (it picks the lane: tiny, small or standard). Add `--explore` when they say "from scratch", "explore first" or "end to end", or ask to compare approaches. |
| a whole sprint or many items done | `/yay:autopilot` (`--sprint=current`, or the ids) |
| to know why something breaks: a symptom, an error, a log | `/yay:debug "<symptom>"` |
| a bug fixed: a `B-<n>`, or a bug whose cause is already clear | `/yay:fix B-<n>`; an unexplained bug goes to `/yay:debug` first |
| tests for a behaviour, or failing tests explained | `/yay:test "<behaviour>"` / `--triage` |
| a browser test for a flow | `/yay:e2e "<flow>"` |
| a QA build | `/yay:release --bundle` |
| to ship, "release it", "ship it" | `/yay:release` (after the PR merges: `--tag-only`) |
| what goes in the next release, the changelog | `/yay:changelog --dry-run` |
| the docs brought up to date with the code | `/yay:knowledge-update` |
| the harness updated, "harness is outdated" | `/yay:harness-update` |
| the machine or repo checked, "is everything installed", a tool or Docker missing | `/yay:setup` (`--check` to only look) |
| a repo set up for the first time | tell the user to run `/yay:harness-init` themselves: it wipes files, so it's never started for them |

- **Words become options:** "dry run", "no PR", "draft", "hotfix", "quick", "status" and the like mean the skill's matching option.
- **Unclear between two skills:** pick the one that changes less (debug before fix, brainstorm before plan, `--dry-run` or `--status` before a write), and say which you picked and why. Ask only when the two readings would do very different, hard-to-undo things (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`).
- **Not Yay work** (a general question, an edit outside the workflow): just help, and don't force it into a skill.

Before handing off, say in one line what you're running (`→ /yay:fix B-7`). Then invoke it with the Skill tool, with the skill name (`yay:fix`) and the arguments. Don't repeat its report afterwards.

## Don'ts
- Don't do a skill's work here, and don't skip a skill's own questions or checks.
- Never start `/yay:harness-init`, or anything that deletes, for the user.
