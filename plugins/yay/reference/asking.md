# yay asking rules

Keep the work moving. Ask only what you can't responsibly decide yourself. These hold for every `/yay:*` skill and for ordinary requests in a yay repo.

- **At most one round of 1–3 questions, and only the hardest ones.** A question is worth asking only if the decision is expensive to undo, or is one only the user can make: what customers see, scope, what ships, which design to commit to. Ask them all together in one AskUserQuestion, early, with the recommended option first, marked "(Recommended)".
- **Decide everything else yourself.** Use the code, the config, the artifacts, the repo's conventions, the answers you got, and sensible defaults. Don't ask to confirm a default, a version, a plan, a draft status or the next step. If nothing is hard, ask nothing.
- **Write your decisions down so they can be overruled.** List the choices you made under **Decided** in the report, the PR or the artifact. Questions that stay open and don't block the work go under "Open questions" in the artifact, for the next checkpoint (the next skill in the flow, or the PR review). Never stop the work for them.
- **Don't stop to ask about pushing.** Commit locally and finish. Push and open the PR only when an option (`--pr`) or an earlier answer said so. Otherwise end the report with the exact push and PR commands, ready to run. If a question round is happening anyway, "push and open a PR when done?" may be one of its questions.
- **Confirm only what destroys or leaves the machine:** deleting or overwriting existing work (the harness wipe, `--force` over hand edits), writes to a live site or database, pushes, and tags. Put these in the same single round whenever you can.
- **Nobody to ask** (a non-interactive run, or the user said "don't ask"): take the recommended answers, list them under **Decided**, and skip anything that needs a confirmation.
