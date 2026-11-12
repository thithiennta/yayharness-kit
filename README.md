# yayharness

The marketplace for **`yay`**, the shared Claude Code harness for YayCommerce WordPress plugins. The plugin lives in [`plugins/yay/`](plugins/yay/README.md), and the build plan and its progress are in [`PLAN.md`](PLAN.md).

**New to the team? Start with [`ONBOARDING.md`](ONBOARDING.md)**: install, the daily workflow, git rules and troubleshooting. For a worked example from roadmap to release, see [`docs/yay-workflow.md`](plugins/yay/templates/docs/yay-workflow.md) (every plugin repo gets a copy).

```bash
./tests/run.sh --quick         # while editing: only the tests covering your uncommitted changes, jq only
./tests/run.sh                 # before committing: all tests, once per available JSON engine, in parallel
./tests/run.sh git hooks       # only tests/unit/*git* and *hooks*
./tests/run.sh --changed=main  # what this branch changed, on every engine
./tests/run.sh --tested        # exit 0 if a green full run already tested the kit code as it is now
claude plugin validate .       # marketplace manifest
claude plugin validate plugins/yay
```

Working on the kit itself, two repo-local skills do the git work: **`/kit-ship`** takes the working tree to a merged PR on `main` (branch, CHANGELOG entry, tests, commit, PR, merge), and **`/kit-release`** releases a version (bump, dated CHANGELOG, eval score, PR, merge). A release re-runs the tests only when no green full run covers the code, and the eval suite only when skill text changed since the last scored version (`.claude/skills/kit-release/gate.sh` decides).
