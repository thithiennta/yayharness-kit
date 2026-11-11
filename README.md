# yayharness

The marketplace for **`yay`**, the shared Claude Code harness for YayCommerce WordPress plugins. The plugin lives in [`plugins/yay/`](plugins/yay/README.md), and the build plan and its progress are in [`PLAN.md`](PLAN.md).

**New to the team? Start with [`ONBOARDING.md`](ONBOARDING.md)**: install, the daily workflow, git rules and troubleshooting.

```bash
./tests/run.sh --quick         # while editing: only the tests covering your uncommitted changes, jq only
./tests/run.sh                 # before committing: all tests, once per available JSON engine, in parallel
./tests/run.sh git hooks       # only tests/unit/*git* and *hooks*
./tests/run.sh --changed=main  # what this branch changed, on every engine
claude plugin validate .       # marketplace manifest
claude plugin validate plugins/yay
```
