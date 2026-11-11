# yay: the YayCommerce harness

A Claude Code plugin that gives every Yay WordPress plugin the same harness and the same workflow. Once it's installed, each plugin repo gets a kit-managed CLAUDE.md block, rules, hooks and settings, plus knowledge docs written from its own code. Every developer then works through the same skills:

```
/yay:roadmap ─► /yay:brainstorm ─► /yay:plan ─► /yay:implement ─┐
               └──────── /yay:autopilot (all three, for a whole queue) ┤
/yay:debug ─► /yay:fix ──────────────────────────────────────────┼─► /yay:changelog ─► /yay:build ─► /yay:release
/yay:harness-init · /yay:harness-update · /yay:knowledge-init · /yay:knowledge-update
```

## What's inside

| Path | What |
|---|---|
| `skills/` | The `/yay:*` skills (built phase by phase, see `PLAN.md` at the repo root) |
| `workflows/` | `roadmap-portfolio.js`: the multi-agent roadmap run by `/yay:roadmap --multi-agent`. `autopilot.js`: prepare and build for `/yay:autopilot` |
| `agents/` | `yay:knowledge-scout` (area explorer for the knowledge skills), `yay:hypothesis-checker` (bug hypotheses for `/yay:debug`), `yay:code-reviewer` (reuse and comments review before PRs). All read-only. |
| `bin/yayh` | Helper CLI the skills call: config, IDs, slugs, front-matter, manifest, git. On PATH while the plugin is enabled. |
| `lib/` | Bash 3.2-compatible library behind `yayh` |
| `reference/` | Contracts the skills follow: `config.md`, `artifacts.md`, `ownership.md`, `git-conventions.md`, `e2e.md` |
| `templates/` | Files `harness-init` writes into a repo |
| `hooks/` | Guards (generated paths, commit and branch conventions, debug markers, tags), the code rules at session start, and non-blocking reuse and comment hints after edits |

## Install (local, for now)

```bash
claude plugin marketplace add ~/yayharness
claude plugin install yay@yayharness
```

Then open a plugin repo and run `/yay:harness-init`.

## Requirements

git, bash, and one of `jq`, `node`, `php` or `python3` for reading JSON. macOS ships `jq` and every Yay dev has `php`.
