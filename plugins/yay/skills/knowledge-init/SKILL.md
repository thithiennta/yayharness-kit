---
name: knowledge-init
description: Write a Yay plugin's project knowledge from its code and history. Use right after /yay:harness-init, when the CLAUDE.md project block is a placeholder or docs/knowledge/ is empty, or when the user says "document this plugin", "init knowledge", "onboard Claude to this repo". Writes the yay:project block and docs/knowledge/ (architecture, conventions, integrations, known issues, decisions), every fact cited.
argument-hint: "[--depth=quick|full] [--agents=N] [--area=<path>] [--run-commands] [--mine-history] [--force] [--no-commit]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(ls *), Bash(wc *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:knowledge-init

Arguments: `$ARGUMENTS`

Write this repo's project knowledge. Follow `${CLAUDE_PLUGIN_ROOT}/reference/knowledge.md` exactly: what goes where, the block's sections, doc front-matter, and the ground rules. Read it before writing anything.

## Options

| Option | Effect |
|---|---|
| `--depth=quick` | No scouts. Write the CLAUDE.md block, `architecture.md`, `helpers.md` and `known-issues.md` from your own exploration. Good for small plugins. |
| `--depth=full` (default) | Run scouts in parallel per area, then write the full doc set. |
| `--agents=N` | Maximum number of parallel scouts (default 4, maximum 6). |
| `--area=<path>` | Only (re)write the knowledge for this subtree: an area doc and its "read when" link. The rest stays as it is. |
| `--run-commands` | Actually run the configured `lint`, `typecheck`, `test` and `build` commands to verify them. Without it, read their definitions only. Passing it is the consent: no further question. Afterwards, restore any tracked files a command rewrote (`git checkout -- <files>`), and report tests that need a database you don't have as not run. |
| `--mine-history` | Also read the old harness docs from git history (the commit before `chore(harness): install yay harness`) as **leads only**. Re-verify every lead against the current code before using it, and never copy text over. Off by default, because the harness install wiped them on purpose. |
| `--force` | Overwrite knowledge that already exists. Otherwise, if the project block or `docs/knowledge/` already has content, stop and suggest `/yay:knowledge-update`. |
| `--no-commit` | Leave the changes uncommitted. |

## Steps

### 1. Preflight
- `yayh harness status` must not say `not-initialized`. If it does, suggest `/yay:harness-init` and stop.
- `yayh knowledge docs` and `yayh knowledge block`: if knowledge exists and neither `--force` nor `--area` was passed, stop and suggest `/yay:knowledge-update`.
- `yayh config get commands` and `yayh config get editions`: these are the facts the block must reflect.

### 2. Map the repo (always, yourself)
Work out the shape before splitting the work:
- `git ls-files | cut -d/ -f1-2 | sort | uniq -c | sort -rn | head -40`
- the main plugin file's header and boot code
- `composer.json` and `package.json` (autoload, scripts)
- `.github/workflows/`
- `git log --oneline -30`, and `git shortlog -sn --since=1.year | head`

Choose **2–6 areas**, for example PHP core/services, admin SPA, blocks/storefront, integrations/compat, build/release/tooling, and Pro (if it has its own tree). With `--area`, the one area is that path. With `--depth=quick`, explore the areas yourself, one after another, and skip step 3.

### 3. Scout in parallel (`--depth=full`)
Spawn one `yay:knowledge-scout` agent per area, **all in a single message** so they run in parallel, up to `--agents`. Each brief contains:
- the area name and its exact paths
- the repo facts from step 2 the scout needs: editions, base branch, PHP floor, generated paths (never explore those)
- the questions to answer for that area, taken from the doc table in knowledge.md
- for the build/tooling scout only: whether it may run commands (`--run-commands`), and which ones
- with `--mine-history`: the commit to read old docs from, and the instruction that they're leads to re-verify, not sources

Wait for every report. Treat scout output as **claims to check**: spot-check every `[known-issue]` and `[decision]` yourself, and any finding that surprises you, before writing it down.

### 4. Ask what code can't tell (at most one AskUserQuestion, up to 3 questions)
Pick the 1–3 open questions whose answers matter most for the docs, or settle the others. Write every other open question into `known-issues.md` under **Open questions**, to answer later. For example: which odd behavior is intentional, which compatibility targets are supported, or whether a failing check is known. Skip this step if nothing important is open.

### 5. Write the docs
- **`docs/knowledge/helpers.md`:** always, unless the plugin has almost no PHP or JS. Start from `yayh code index` (every class, function and method, with its docblock summary), then keep only what's meant to be reused: shared helpers, services, settings getters, and the hooks the plugin exposes. Group them by job, one line each with when to use it. This is the first place Claude looks before writing new code.
- **`docs/knowledge/*.md`:** one per core doc that has real content (see knowledge.md), plus area docs only where `architecture.md` would bloat. Each gets accurate `covers` and `> Update when: …`. Use `Write` for new files.
- **`CLAUDE.md`:** replace only the content between `<!-- yay:project:start … -->` and `<!-- yay:project:end -->` (use `Edit` on that range). Never touch the managed block or text outside the blocks; a hook blocks edits to the managed block. Follow the block's section order, and give each knowledge doc or section a "Read when…" line.

### 6. Verify, fix, stamp
- Run `yayh knowledge check` and fix every issue: wrong paths, dead links, over budget, missing front-matter. Repeat until it passes.
- Re-read the project block as a newcomer would. Is every command real, does every hard rule have a reason, and does it fit the budget?
- Stamp each doc you wrote with `yayh knowledge stamp <doc>`, then `yayh knowledge stamp CLAUDE.md`.
- Run `yayh knowledge stale`. Everything should be `fresh`, and any `uncovered` lines mean an area has no doc's `covers`. Either widen a `covers` or note why it's out of scope.

### 7. Commit
Unless `--no-commit` was passed:
- If you're on the base branch, `git switch -c "$(yayh git branch-name docs "project knowledge")"`. Otherwise stay on the current branch, e.g. the unmerged harness branch.
- `git add -- CLAUDE.md docs/knowledge`. Stage nothing else.
- `git commit -m "docs(knowledge): write project knowledge" -m "<one line per doc written>"`

### 8. Report
List the docs written, each with one line on what it covers. Then list:
- the open questions you couldn't resolve, which are now in `known-issues.md` or noted in the docs
- commands that failed when you verified them
- the next step: open a PR, or run `/yay:roadmap` and `/yay:brainstorm`

## Don'ts
- Don't write anything you haven't verified. Leave a gap rather than guess, and list the gap in the report.
- Don't copy old harness text, even with `--mine-history`. Re-derive it from code.
- Don't put detail in the project block that belongs in a doc. The block is an index.
