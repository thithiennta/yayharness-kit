---
name: harness-init
description: Install the yay harness in a Yay WordPress plugin repo. Use when a repo has no .yay/config.json, or the user says "init harness", "set up yay", "install the harness", "replace our CLAUDE.md". Detects the stack, hard-wipes the old harness (CLAUDE.md, AGENTS.md, .claude, docs/) on a branch after confirmation, writes .yay/config.json and the kit files, and commits.
argument-hint: "[--dry-run] [--yes] [--keep=<path>]... [--no-wipe] [--branch=<name>] [--editions=free,pro] [--wporg-slug=<slug>|--no-wporg] [--base=<branch>] [--no-commit] [--reinit]"
disable-model-invocation: true
allowed-tools: Bash(yayh *), Bash(git *), Read, Write, Edit, AskUserQuestion
---

# /yay:harness-init

Arguments: `$ARGUMENTS`

Install the yay harness in the current plugin repo. This **deletes the old harness**, so follow the steps in order and never skip the confirmation in step 4.

Reference material, read when you need it:
- What gets wiped, what's kept, and who owns what: `${CLAUDE_PLUGIN_ROOT}/reference/ownership.md`
- Every config key: `${CLAUDE_PLUGIN_ROOT}/reference/config.md`

## Options

| Option | Effect |
|---|---|
| `--dry-run` | Run steps 1–4 (detect, inventory, show the plan), then stop. Change nothing. |
| `--yes` | Skip the confirmation question in step 4. Still print the full inventory first. |
| `--keep=<path>` | Don't wipe this path (repeatable). Also saved to `keep` in the config. |
| `--no-wipe` | Install the kit without deleting the old harness. Old files that collide with kit files are reported as conflicts. |
| `--branch=<name>` | Branch to work on. Default `chore/yay-harness`. |
| `--editions=free,pro` | Override the detected editions. The first one listed is the default. |
| `--wporg-slug=<slug>` / `--no-wporg` | Override the detected WordPress.org slug. |
| `--base=<branch>` | Override the detected base branch. |
| `--no-commit` | Leave the changes staged instead of committing. |
| `--reinit` | Allowed when `.yay/config.json` already exists: keep that config and wipe and reinstall everything else. |

## Steps

### 1. Preflight
Run these and stop with a clear message on any problem:
- `git rev-parse --show-toplevel`. The repo root is where you work from now on.
- `git status --porcelain`. Tracked changes must be committed or stashed first. Untracked files are fine.
- `yayh harness status`. If it reports anything other than `not-initialized` and `--reinit` wasn't passed, stop and point the user to `/yay:harness-update`.
- Check that the repo looks like a WordPress plugin: some root `*.php` file has a `Plugin Name:` header. If not, stop and say so (rerun with `--yes` to go ahead anyway).

### 2. Detect
Run `yayh harness detect > "$(mktemp)"` (remember the path) (on `--reinit`, use the existing config instead). Read the draft, then apply the overrides from the options. Then list the guesses that detection can't be sure of. Don't ask yet: they go into the single question round in step 4. Only these can be worth asking, and only when they're uncertain:
- **Editions:** whether the repo builds Free and Pro from one branch, what the repo calls them (`free`, `lite`, …, matching its build scripts), and which is the default. If you rename an edition, rename it in `package.forbidden` (and in a per-edition `package.output`) too, because `yayh config validate` rejects keys that aren't editions.
- **wp.org slug:** whether the Free build ships to WordPress.org.
- **Base branch:** the detected one, plus any other long-lived branches you see in `git branch -a` (e.g. `dev`, `main`, `main-lite`).
- **Package command:** how a release zip is built. Look at `scripts/`, `bin/`, `vendor/bin/yaycommerce-*`, the `package.json` and `composer.json` scripts, and `.github/workflows/`. Offer the commands you found, using the `{version}` and `{edition}` placeholders.

Don't ask about values that are clearly right (slug, main file, PHP floor). The answer to one question often settles another (a Free/Pro split implies the wp.org question and the per-edition package command), so derive those. Anything still uncertain gets the best guess and is listed under **Decided** in the report, to fix later in `.yay/config.json`.

### 3. Inventory
Run `yayh harness inventory --keep=<path>` (one `--keep=` per `--keep` option). Group the output for the user:
- **Will be deleted:** each `wipe` target, with its count of tracked files. Expand `docs/` by listing its top-level entries (`git ls-files docs | cut -d/ -f1-2 | sort -u`), so nobody loses user docs by surprise.
- **Kept:** the `keep` lines.
- **Untracked (not touched):** the `untracked` lines. Say that the user decides about these.

If anything under `docs/` looks like **user-facing documentation** rather than harness or Claude material (guides, API docs, images used by `readme.txt`), call it out and suggest `--keep`.

### 4. Confirm
Show the plan in one short block: the branch, the config summary (name, slug, editions, base, tag format, commands, generated paths), the delete list, and the kit files that will be written. Then ask **one** AskUserQuestion with at most 3 questions:
- always first: "Wipe and install the yay harness on branch <branch>?" (**Install**, **Keep more paths**, **Cancel**). On **Keep more paths**, its free-text answer names the paths; add them and re-show the delete list, without asking again unless it changed a lot.
- then the 1–2 most important detection doubts from step 2, each with your guess first as "(Recommended)".

With `--yes`, ask nothing: use the guesses, still print the plan, and list the guesses under **Decided**. With `--dry-run`, stop here.

### 5. Branch
If you're not already on the target branch, create it from the base: `git switch -c <branch> <base>`. If it already exists, `git switch <branch>`.

### 6. Wipe
Unless `--no-wipe` was passed: `yayh harness wipe --yes --keep=<path> …` (the same `--keep=` options). It refuses on the base branch or with a dirty tree. If it refuses, fix the cause and don't force it.

### 7. Write the config
Write the confirmed config to `.yay/config.json`, pretty-printed with 2-space indents and the `--keep` paths in `keep`. Run `yayh config validate` and fix anything it reports.

### 8. Install the kit files
Run `yayh harness sync`. On `--no-wipe`, `conflict` lines mean an old file is in a kit file's place. Keep them (no `--force`), list them in the report, and say that `/yay:harness-update --force` replaces them.

### 9. Commit
Unless `--no-commit` was passed:
```
git add -u                              # the wipe's deletions (the tree was clean, so nothing else)
git add -- $(yayh harness files)        # exactly the kit's files; never `git add -A`
git commit -m "chore(harness): install yay harness v$(yayh version)" -m "Removes the previous harness and installs the kit-managed CLAUDE.md block, rules, settings and PR template. Config: .yay/config.json."
```

### 10. Hand off
Report in a few lines:
- what was removed (counts) and what was installed
- the config's notable choices
- the branch, and that it needs a PR into the base branch

Then the next steps:
1. **`/yay:knowledge-init`** writes the project block of `CLAUDE.md` and `docs/knowledge/`. Without it, Claude knows the workflow but not the plugin.
2. Teammates install the plugin once with `claude plugin install yay@yayharness`. The repo's settings only register the marketplace.
3. **`/yay:test-init`** sets up PHP unit (PHPUnit + Brain Monkey), PHP integration (the WordPress test suite in wp-env) and JS tests, and writes baseline tests for the riskiest code. Optional; plan, implement and fix then pick a layer for each risk.
4. **`/yay:e2e-init`** scouts the plugin's flows and adds browser tests for the critical ones (Playwright + wp-env), or adopts the repo's existing setup when `yayh e2e detect` finds one. Optional; plan, implement and fix use it once it's there.

## Hard wipe means hard wipe
The team chose to delete the whole old harness, `docs/` included, and rebuild from code. Everything stays reachable in git history on the base branch. So:
- The delete list is the inventory minus `--keep`, `config.keep` and the always-kept personal files. Nothing else. Never decide on your own to keep, restore or re-add old files, even ones that look valuable or sit at a path the kit reuses (such as `docs/roadmap.md` or `docs/backlog/`).
- If something looks worth keeping, say so in step 4 and offer **Keep more paths**. With `--yes`, don't ask. Name it in the report instead, with the command that brings it back: `git checkout <base> -- <path>`.

## Don'ts
- Never wipe without showing the inventory first, never wipe on the base branch, and never use `git rm` by hand for paths the inventory didn't list.
- Never stage with `git add -A` or `git add .`: the user's untracked files must stay untracked.
- Never invent commands for the config. Leave a command out when it doesn't apply or you're unsure, and say so under **Decided**.
- Don't write project knowledge here. That's `/yay:knowledge-init`'s job.
