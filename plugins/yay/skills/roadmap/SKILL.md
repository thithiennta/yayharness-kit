---
name: roadmap
description: Plan, re-plan or report a Yay plugin roadmap (docs/roadmap.md). Use when the user says "roadmap", "plan the next sprints", "what should we build next", "sprint status", "where are we", "add to the roadmap". Schedules evidenced R-<n> items into dated sprints against capacity and freezes. --status reports read-only; --multi-agent co-plans several plugins; --publish shares a page; --trello (optional) mirrors the sprints and items to a Trello board.
argument-hint: "[--status] [--horizon=<YYYY-MM-DD|<n>sprints|eoq|eoy>] [--sprint-length=2w] [--start=YYYY-MM-DD] [--capacity=<dev-days/sprint>] [--freeze=YYYY-MM-DD..YYYY-MM-DD] [--focus=\"<theme>\"] [--web] [--add=\"<title>\" [--sprint=<n|later>] [--size=S|M|L]] [--move=R-<n>:<n|later>] [--drop=R-<n>] [--multi-agent] [--plugins=<a,b|all>] [--rounds=1|2] [--publish] [--trello] [--dry-run] [--no-pr] [--draft]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, WebSearch, WebFetch, Workflow, Skill, Artifact, mcp__trello__trelloReadBoard, mcp__trello__trelloReadList, mcp__trello__trelloReadCard, mcp__trello__trelloReadMember, mcp__trello__trelloWriteList, mcp__trello__trelloWriteCard
---

# /yay:roadmap

Arguments: `$ARGUMENTS`

The roadmap is `docs/roadmap.md`: `### R-<n> Title` items with `- key: value` bullets, under `## Sprint <n> (<start> → <end>)` and `## Later` headings. The shape is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Roadmap). Feature work flows **roadmap item → `/yay:brainstorm --from=R-<n>` → `/yay:plan` → `/yay:implement`**, and `/yay:release` marks items shipped.

Always edit through `yayh roadmap` where a command exists (`add`, `set`, `move`), so the format stays parseable, and finish every write with `yayh roadmap check` (no errors allowed).

## Options

| Option | Effect |
|---|---|
| `--status` | Read-only report. Writes nothing. See **Status**. |
| `--horizon=…` | Plan up to a date, `<n>sprints`, `eoq` (end of quarter) or `eoy` (Dec 31). Default: the front-matter `horizon` if it's still ahead, else 4 sprints (shown in the confirm round, where it can be changed). |
| `--sprint-length=2w` | `1w`, `2w`, `10d`… Default: the front-matter `sprint_length`, else `2w`. |
| `--start=YYYY-MM-DD` | First new sprint's start. Default: the day after the current sprint ends, or today when there's none. |
| `--capacity=<n>` | Dev-days per sprint (sizes: S = 1.5, M = 4, L = 8). Default: 8 per 2-week sprint (one developer), scaled to the sprint length; shown in the confirm round. |
| `--freeze=a..b` | A window with hotfix-class work only (fixes, compat, docs), e.g. around BFCM. Repeatable. |
| `--focus="…"` | A theme to favour (e.g. "conversion before BFCM"). |
| `--web` | Also research wordpress.org (reviews, support forum) and 3–5 competitors. |
| `--add="<title>"` (with `--sprint=<n\|later>`, `--size=S\|M\|L`), `--move=R-<n>:<n\|later>`, `--drop=R-<n>` | Quick edits. See **Quick edits**. |
| `--multi-agent` / `--plugins=a,b\|all` / `--rounds=1\|2` | Co-plan several plugins. See `reference/roadmap-extras.md`. |
| `--publish` | Publish the roadmap as a private page. See `reference/roadmap-extras.md`. |
| `--trello` | Optional. Also mirror the sprints and items to a Trello board. Off unless given. See `reference/roadmap-extras.md`. |
| `--dry-run` | Show the proposed roadmap and change nothing. |
| `--no-pr`, `--draft` | As in `/yay:implement`: the PR is opened by default; `--no-pr` finishes locally and prints the commands; draft PR. |

## Where the edit happens

`docs/roadmap.md` is tracked, so every write happens on a branch, never on the base:
- On a non-base branch already: edit there.
- On the base: `branch="$(yayh git branch-name docs "roadmap $(date +%Y-%m-%d)")"`, `wt="$(yayh git worktree "$branch")"`, and work in `$wt`. Reuse it if it exists today.

Commit by path with `docs(roadmap): <summary>` (the `roadmap` scope is always allowed): `git add -- docs/roadmap.md <promoted backlog files>`. Then push and `gh pr create --base <base> --assignee @me`, unless `--no-pr` (then print those commands). `--status` and `--dry-run` never push.

## Status (`--status`)

1. `yayh roadmap status` gives: horizon, current sprint, counts per section (open, in-progress, shipped, dropped), slipped items, open bugs by severity, and ready or in-progress plans.
2. `yayh roadmap check` for structure problems, and `yayh roadmap links` for items whose status lags behind their brainstorm or plan (current ≠ suggested).
3. Report, in this order:
   - the current sprint, its goal line, and each of its items with status
   - slipped items (sprint ended, not shipped)
   - critical and high bugs with no roadmap item or fix branch: they compete for this sprint's capacity
   - status drift from `links`, and check errors
   - the next actions, as commands, from `yayh status` (each row's `next` column), plus `/yay:roadmap` when the horizon has passed or a lot slipped
4. Never write in this mode.

## Quick edits

One small change, on a branch as above, then `yayh roadmap check`, commit and the PR question.
- `--add="<title>"`: `yayh roadmap add "<title>" sprint=<n|later> size=<S|M|L> "why=<one line>"`. When the why or size is missing, infer them from the title and the evidence, and say what you used. Default sprint: `later`. Warn if the sprint is now over capacity.
- `--move=R-<n>:<n|later>`: `yayh roadmap move R-<n> <n|later>`. Warn about capacity, or when moving work into a freeze sprint.
- `--drop=R-<n>`: `yayh roadmap set R-<n> status dropped`, then record the reason given in the request (or "dropped <date>") with `yayh roadmap set R-<n> note "<reason>"`. Don't ask for one. Never delete an item: ids aren't reused.

Commit: `docs(roadmap): add R-<n> <title>` / `move R-<n> to sprint <n>` / `drop R-<n>`.

With `--trello`, sync only the item that changed (`reference/roadmap-extras.md`, Trello).

## Plan (default)

1. **Where we are.**
   - With no `docs/roadmap.md` at all, the harness isn't set up: suggest `/yay:harness-init` and stop.
   - `yayh roadmap status`, `yayh roadmap check` and `yayh roadmap links`. Keep every existing item and its id.
   - **Legacy roadmap or backlog** (content without front-matter or `### R-<n>` items, or backlog files without `id:`): read **Legacy conversion** in `${CLAUDE_PLUGIN_ROOT}/reference/roadmap-extras.md` before going on.
   - Settle horizon, sprint length, start, capacity and freezes from the options and the front-matter, and use the defaults for the rest. Don't ask yet: the defaults are shown in step 5's single round. Then `yayh roadmap sprints start=… length=… until=…|count=… first=<next sprint number>` gives the new sprint dates. Past and current sprints keep their headings and dates.
2. **Evidence.** Read what's there; don't invent demand.
   - Unfinished roadmap items, and `links` drift.
   - `yayh artifact list backlog --status=idea`, and the parked work and decisions from plans and fixes: `yayh backlog open` (a `deferred` note whose plan is done is a candidate item; an open `decision` that affects a scheduled item is worth naming in its `note:`), open bugs (`yayh roadmap status` lists them by severity), ready and in-progress plans, open and decided brainstorms.
   - `docs/knowledge/known-issues.md` and `decisions.md`, and the `CLAUDE.md` project block.
   - `readme.txt`: features, recent changelog, and "Requires at least" / "Tested up to" / "WC tested up to". A newer WordPress or WooCommerce release than "tested up to" is a compat item.
   - `git log --since=90.days --oneline` and unmerged branches, for work already under way.
   - `gh issue list --state open --limit 100` and `gh pr list --state open`, if gh works.
   - With `--web`: the plugin's wordpress.org page (installs, rating, the latest support threads, 1–3★ reviews) and 3–5 competitors. Hand this to one `Agent` with a fixed report format (pain points with links, competitor gaps), so the page dumps stay out of this context. Give it the model and effort from `yayh model resolve web-research` (model routing: `${CLAUDE_PLUGIN_ROOT}/reference/models.md`).
3. **Candidates.** For each, write: title, why (the customer value and its evidence: `B-<n>`, `BL-<n>`, `#issue`, a review URL), size S/M/L, editions, value high/medium/low, and `from` when it came from a backlog idea, bug or issue. Prefer small, evidenced items. A bug only becomes an item when it's bigger than a `/yay:fix` (otherwise it's just fixed).
4. **Schedule.**
   - Unfinished items in past sprints have slipped. Each one moves to the current or a new sprint, or to Later. Say which.
   - Fill sprints in priority order (must-haves, high value per day) up to capacity. A sprint that overlaps a `--freeze` window is a freeze sprint: hotfix-class items only, with the spare capacity kept for fixes. Say so in its `Goal:` line. Dependencies go first. Overflow goes to Later.
   - Give each new sprint a one-line `Goal:` under its heading.
5. **Confirm.** Show a table per sprint (id or "new", title, size, why) with the dev-days used against capacity, plus what goes to Later and what slipped. Don't ask for approval: the roadmap is written on a local branch, so it's cheap to change. With `--dry-run`, stop here. Ask (one AskUserQuestion, at most 3 questions, `${CLAUDE_PLUGIN_ROOT}/reference/asking.md`) only about the hardest calls: work you had to cut or push past the horizon that someone may consider a must, or a priority conflict the evidence can't settle. The calendar defaults and where a legacy roadmap's lasting sections go are decisions you make; list them under **Decided**.
6. **Write**, on a branch (above):
   - Front-matter: `horizon`, `sprint_length`, `updated` (today). Keep any other keys (`published`, `hub`).
   - Add the new sprint headings from `yayh roadmap sprints … --md`, each followed by its `Goal:` line. Never rewrite past sprints' headings.
   - Existing items: `yayh roadmap move R-<n> <sprint|later>`, and for each `links` drift, `yayh roadmap set R-<n> status <suggested>`.
   - New items: `yayh roadmap add "<title>" sprint=<n|later> size=… "why=…" ["editions=free, pro"] [from=…]`. It prints the id. Write `editions` with the config's edition names, comma and space separated.
   - Backlog ideas that became items: `yayh fm set docs/backlog/<file> status promoted:R-<n>`. A deferred note that became an item: `yayh fm set <file> affects "[R-<n>]"`, so the item's plan picks it up (it stays `open` until a plan takes it).
   - `yayh roadmap check` must have no errors.
7. **Trello** (only with `--trello`): sync before committing, so the saved card URLs go in the same commit. See `reference/roadmap-extras.md`.
8. **Commit and PR**: `docs(roadmap): plan to <horizon>`, as above.
9. **Report** the sprint table with the new ids, what slipped and where it went, what was promoted, the Trello cards (with `--trello`), the PR link, and end with the **Next** line (`reference/asking.md`), usually the top row of `yayh status` (`/yay:brainstorm --from=R-<n>` for the first item of the current sprint).

## Multi-agent, publish and Trello

`--multi-agent`, `--publish` and `--trello` are described in `${CLAUDE_PLUGIN_ROOT}/reference/roadmap-extras.md`. Read it only when one of them is given.

## Don'ts
- Never renumber, reuse or delete an `R-<n>`. Dropped items stay with `status: dropped`.
- Never edit `docs/roadmap.md` on the base branch, and never stage with `git add -A`.
- Don't rewrite past sprints' dates or move shipped items.
- Don't schedule past capacity or put feature work in a freeze sprint without the user agreeing.
- Don't invent evidence: every new item's `why` points at something real.
