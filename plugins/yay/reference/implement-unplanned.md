# /yay:implement: work with no plan yet

Read by `/yay:implement` when its argument is a requirement, or an `R-`/`BS-`/`B-<n>` with no plan made from it. The other steps are in `skills/implement/SKILL.md`.

## Pick the lane, then plan it
Skip this when the argument is a plan: a `P-<n>`, or text that `yayh artifact resolve` finds under `docs/plans/`.

**Pick the lane** from the requirement and the code it touches (or take `--lane`), and say which one under **Decided**:
- **tiny:** one or two files, about 30 changed lines or fewer, no customer-visible decision, and no data, storage or settings change. A label, a typo, a guard clause, a small compat fix. **No plan file.** Go to **Tiny lane** below.
- **small:** an S item or a clear change in one area (at most about 3 tasks). Write a small plan (`/yay:plan`'s **Lanes**, `lane=small`) in step 2 below, then build it as usual.
- **standard:** everything else. Follow steps 1–3 below.
1. **Find an existing plan.** For `R-<n>`, `BS-<n>` or `B-<n>`, look for a plan made from it: `yayh roadmap queue R-<n>` (its artifact column is a `P-<n>` once one exists), or `yayh artifact list plan` and match the plan's `from:`. For text, check `yayh artifact list plan` for a plan on the same topic. Ignore `done` and `dropped` plans. Found one: use it and go to the skill's step 1.
2. **Write the plan.** Follow `/yay:plan` (`${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`): steps 1–6 with the requirement as the topic (or `--from=<id>`), the `--type` given (`fix` for a `B-<n>`), and `roadmap=` when the source is a roadmap item. Ground it in the code as usual: open every file the tasks name, give each task its `Reuse:` line, and get `yayh plan check` to no errors.
   - Don't run `/yay:plan`'s question round. Carry its hard questions (tests when the repo's rules need approval, the one biggest open design decision) into the skill's step 1 round, so the whole run still asks **at most one round**.
   - A requirement too vague to plan responsibly (no clear user-visible outcome) is itself the hard question. With nobody to ask, plan the most likely reading and record it under **Decided**.
   - More than about 8 tasks, or unrelated areas: plan with `--split`. Build the first slice now, and list the others in the report with `/yay:autopilot P-<a> P-<b>…` to build them.
   - When the skill's step 1 round leaves nothing open, mark it ready: `yayh fm set <plan> status ready`.
3. The plan is a new, untracked file in the main checkout, like any plan. It's carried into the branch in the skill's step 2, so it's committed with the code. Report it as "planned by /yay:implement".

## Tiny lane (no plan)
1. Find the code and the existing helpers it should call, as for any task (the skill's step 3.1 reuse rules).
2. Branch as in the skill's step 2.1–2.2, with a branch type that fits the change (`fix`, `chore`, `feat`). There's nothing to carry or set.
3. Make the change. Verify as in the skill's step 3.2: lint, plus the existing tests that cover those files. Add a test only for a real risk, at the cheapest layer.
4. Commit: `<type>(<scope>): <summary>`, with `Roadmap: R-<n>` or `Fixes: B-<n>` when the change came from one.
5. Finish with the skill's step 4.1 (the checks), 4.4 (debug markers) and 4.5 (review), then step 5. The PR body says "tiny lane, no plan", and puts the **Goal** (one line) and the exact **Verify** checks in place of the plan link.
6. If the change grows past the tiny limits while you work, stop and write a small plan whose ticked T1 is what's done. Then continue from the skill's step 1.
