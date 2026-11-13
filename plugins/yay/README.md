# yay: the YayCommerce harness

A Claude Code plugin that gives every Yay WordPress plugin the same harness and the same workflow. Once it's installed, each plugin repo gets a kit-managed CLAUDE.md block, rules, hooks and settings, plus knowledge docs written from its own code. Every developer then works through the same skills:

```
/yay:go: what's next, or plain words → the right skill below
/yay:roadmap ─► /yay:brainstorm ─► (/yay:design) ─► /yay:plan ─► /yay:implement ─┐
               └──────── /yay:autopilot (all of them, for a whole queue) ──────────┤
/yay:debug ─► /yay:fix ──────────────────────────────────────────┼─► /yay:release --bundle (QA) ─► (/yay:wporg) ─► /yay:release
/yay:harness-init · /yay:harness-update · /yay:knowledge-init · /yay:knowledge-update
```

## What's inside

| Path | What |
|---|---|
| `skills/` | The `/yay:*` skills (built phase by phase, see `PLAN.md` at the repo root) |
| `workflows/` | `roadmap-portfolio.js`: the multi-agent roadmap run by `/yay:roadmap --multi-agent`. `autopilot.js`: prepare and build for `/yay:autopilot` |
| `agents/` | `yay:knowledge-scout` (area explorer for the knowledge skills), `yay:hypothesis-checker` (bug hypotheses for `/yay:debug`), `yay:code-reviewer` (reuse and comments review before PRs), `yay:bug-reviewer` (correctness, security, compatibility, editions and data review before PRs). All read-only. |
| `bin/yayh` | Helper CLI the skills call: config, IDs, slugs, front-matter, manifest, git. On PATH while the plugin is enabled. |
| `lib/` | Bash 3.2-compatible library behind `yayh` |
| `reference/` | Contracts the skills follow: `config.md`, `artifacts.md`, `ownership.md`, `git-conventions.md`, `testing.md`, `e2e.md`, `trello.md` |
| `templates/` | Files `harness-init` writes into a repo |
| `hooks/` | Guards (generated paths, commit and branch conventions, debug markers, tags), the code rules at session start, and non-blocking reuse and comment hints after edits |

## Install

```bash
claude plugin marketplace add thithiennta/yayharness-kit   # published kit: https://github.com/thithiennta/yayharness-kit
claude plugin install yay@yayharness
```

To work on the kit itself, add your clone instead (`claude plugin marketplace add ~/yayharness`): Claude Code then reads the plugin straight from it. The settings `/yay:harness-init` writes into a repo always name the published kit (or another GitHub/git source this machine uses), never a local folder.

Then open a plugin repo and run `/yay:harness-init`.

## Requirements

git, bash, and one of `jq`, `node`, `php` or `python3` for reading JSON. macOS ships `jq` and every Yay dev has `php`.

`/yay:wporg` (the WordPress.org pre-review) also needs `python3` for its precheck; `yayh doctor` checks it in repos that set `plugin.wporgSlug`. Its site stage uses the same wp-env setup as the e2e tests (`/yay:e2e-init`).
