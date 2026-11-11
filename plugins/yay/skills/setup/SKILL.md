---
name: setup
description: Get a Yay plugin repo and this machine ready for the yay workflow in one go. Use when the user says "set up", "get started", "onboard me", "is my machine ready", "doctor", or a skill failed because a tool, a dependency, Docker or the harness is missing. Runs yayh doctor, fixes what it safely can, and chains the setup skills this repo still needs (knowledge, tests, e2e) with one question round.
argument-hint: "[--check] [--with=knowledge,tests,e2e] [--no-install]"
allowed-tools: Bash(yayh *), Bash(git *), Read, Grep, Glob, Skill, AskUserQuestion
---

# /yay:setup

Arguments: `$ARGUMENTS`

One command instead of a checklist. It checks, installs what's safe, and runs the setup skills in order. It does no setup work itself: each step is the normal skill.

## Options

| Option | Effect |
|---|---|
| `--check` | Run `yayh doctor` and report. Change nothing. |
| `--with=knowledge,tests,e2e` | Which optional setup steps to run, without asking. |
| `--no-install` | Don't run `yayh run install`. |

## Steps

1. **Check.** Run `yayh doctor` (status, check, detail, fix). With `--check`, show it grouped as **fail**, **warn** and **ok**, with each fix, and stop.
2. **No harness yet** (the `harness` check says "not set up"): `/yay:harness-init` wipes the old harness, so it's never started for the user. Show the doctor result and tell them to run `/yay:harness-init` themselves (one person per repo, then merge its PR), and to run `/yay:setup` again afterwards. Stop here.
3. **Fix what's safe:**
   - `vendor/` or `node_modules` missing: `yayh run install` (not with `--no-install`).
   - `harness` outdated: `/yay:harness-update` (it only touches kit-owned files).
   - Everything else on the list (installing PHP, Node, Docker or gh, logging in, adding a remote) is the user's to do. List those fixes; don't attempt them.
4. **What's still missing in the repo:**
   - **knowledge:** the `knowledge` check warns: `/yay:knowledge-init`. This is the one step every repo needs, so it isn't a question.
   - **tests:** `yayh test status` shows no unit layer configured: `/yay:test-init`. Optional.
   - **e2e:** no `commands.e2e` in the config, and the plugin has storefront or admin flows (`yayh e2e surfaces` lists some): `/yay:e2e-init`. Optional. It needs Docker.
5. **One question round** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`), only for the optional steps that apply and weren't given with `--with`: one multiSelect AskUserQuestion, "Also set up…", with tests and e2e as options, and their cost in its description (a few minutes, a PR each). With nobody to ask, run none of the optional steps, and list them as next steps.
6. **Run** the chosen skills in order with the Skill tool: knowledge-init, then test-init, then e2e-init. Each one opens its own PR, as usual. Before each, say in one line what's starting. A failed step doesn't stop the next one: report it and go on.
7. **Report:** the doctor result again (`yayh doctor`), now with what changed; each skill's PR or result; the fixes left for the user, as exact commands; and end with the **Next** line (`yayh next`, or `/yay:roadmap` when nothing is in flight yet).

## Don'ts
- Never start `/yay:harness-init` for the user, and never install system software or log in for them.
- Don't redo a step that's already done: doctor and the skills' own checks say what exists.
