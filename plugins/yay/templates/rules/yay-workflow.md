<!-- Kit-managed by the yay plugin {{kit.version}}. Run /yay:harness-update instead of editing; put repo-specific rules in a .claude/rules/ file without the yay- prefix. -->
# Workflow rules

- **Start from an artifact.** Feature work goes roadmap item → brainstorm → plan → implement. Bug work goes debug → fix. Before starting, look for the matching `R-`, `BS-`, `P-` or `B-` file, and link it in front-matter (`from:`), commit trailers and the PR. If there isn't one, say so and offer to create it. Don't refuse to continue.
- **Plans are the contract.** `/yay:implement` does only what the plan's tasks say. If the work needs to change, update the plan first (tasks, files, `**Tests:**`) and tell the user.
- **No fix without a cause.** Edit product code for a bug only once a root cause is written down with `file:line` evidence. A one-line inline cause is enough for trivial bugs.
- **Tests only when they earn their keep.** Propose a test (name, file, what risk it guards) and write it only after the user accepts it. Otherwise write down an exact manual check: the command or UI action, and the result that means it passed.
- **Verify before saying done.** Run the configured `lint`, `typecheck` and `test` commands that apply to what changed (`yayh config get commands.<name>`). A failure that also happens on `{{git.baseBranch}}` is pre-existing: report it, don't fix it unasked, and don't add to it.
- **Front-matter is machine-read.** Keep it flat, one `key: value` per line. Set it with `yayh fm set` whenever possible.
- **Knowledge drifts.** When a change makes `CLAUDE.md` or `docs/knowledge/` wrong, update them in the same PR, or suggest `/yay:knowledge-update`.
