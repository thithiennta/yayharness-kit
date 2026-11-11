# yayharness

The marketplace for **`yay`**, the shared Claude Code harness for YayCommerce WordPress plugins. The plugin lives in [`plugins/yay/`](plugins/yay/README.md), and the build plan and its progress are in [`PLAN.md`](PLAN.md).

**New to the team? Start with [`ONBOARDING.md`](ONBOARDING.md)**: install, the daily workflow, git rules and troubleshooting.

```bash
./tests/run.sh                 # all tests, once per available JSON engine
./tests/run.sh git             # only tests/unit/*git*
claude plugin validate .       # marketplace manifest
claude plugin validate plugins/yay
```
