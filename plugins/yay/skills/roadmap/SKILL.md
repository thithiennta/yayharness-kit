---
name: roadmap
description: Plan, re-plan or report a Yay plugin's roadmap in docs/roadmap.md - gathers evidence (open bugs, backlog ideas, known issues, readme compat, git history, GitHub issues, optionally wp.org reviews and competitors), sizes items S/M/L, schedules them into dated sprints against team capacity and freeze windows, keeps R-<n> ids stable, syncs item status from brainstorms and plans, and commits on a docs branch. --status reports progress, slipped items and open bugs read-only; --multi-agent co-plans several plugins with one owner agent each; --publish shares it as a page. Use when the user says "roadmap", "plan the next sprints", "what should we build next", "re-plan", "sprint status", "where are we", "add to the roadmap".
argument-hint: "[--status] [--horizon=<YYYY-MM-DD|<n>sprints|eoq|eoy>] [--sprint-length=2w] [--start=YYYY-MM-DD] [--capacity=<dev-days/sprint>] [--freeze=YYYY-MM-DD..YYYY-MM-DD] [--focus=\"<theme>\"] [--web] [--add=\"<title>\" [--sprint=<n|later>] [--size=S|M|L]] [--move=R-<n>:<n|later>] [--drop=R-<n>] [--multi-agent] [--plugins=<a,b|all>] [--rounds=1|2] [--publish] [--dry-run] [--pr|--no-pr]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, WebSearch, WebFetch, Workflow, Skill, Artifact
---

# /yay:roadmap

Arguments: `$ARGUMENTS`

The roadmap is `docs/roadmap.md`: `### R-<n> Title` items with `- key: value` bullets, under `## Sprint <n> (<start> → <end>)` and `## Later` headings. The shape is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Roadmap). Feature work flows **roadmap item → `/yay:brainstorm --from=R-<n>` → `/yay:plan` → `/yay:implement`**, and `/yay:release` marks items shipped.

Always edit through `yayh roadmap` where a command exists (`add`, `set`, `move`), so the format stays parseable, and finish every write with `yayh roadmap check` (no errors allowed).

## Options

| Option | Effect |
|---|---|
| `--status` | Read-only report. Writes nothing. See **Status**. |
| `--horizon=…` | Plan up to a date, `<n>sprints`, `eoq` (end of quarter) or `eoy` (Dec 31). Default: the front-matter `horizon` if it's still ahead, else ask (suggest 4 sprints). |
| `--sprint-length=2w` | `1w`, `2w`, `10d`… Default: the front-matter `sprint_length`, else `2w`. |
| `--start=YYYY-MM-DD` | First new sprint's start. Default: the day after the current sprint ends, or today when there's none. |
| `--capacity=<n>` | Dev-days per sprint (sizes: S = 1.5, M = 4, L = 8). Default: ask once; suggest 8 for one developer on 2-week sprints. |
| `--freeze=a..b` | A window with hotfix-class work only (fixes, compat, docs), e.g. around BFCM. Repeatable. |
| `--focus="…"` | A theme to favour (e.g. "conversion before BFCM"). |
| `--web` | Also research wordpress.org (reviews, support forum) and 3–5 competitors. |
| `--add`, `--move`, `--drop` | Quick edits. See **Quick edits**. |
| `--multi-agent` / `--plugins=a,b\|all` / `--rounds=1\|2` | Co-plan several plugins. See **Multi-agent**. |
| `--publish` | Publish the roadmap as a private page. See **Publish**. |
| `--dry-run` | Show the proposed roadmap and change nothing. |
| `--pr` / `--no-pr` | Push and open the PR without asking / never. Default: ask. |

## Where the edit happens

`docs/roadmap.md` is tracked, so every write happens on a branch, never on the base:
- On a non-base branch already: edit there.
- On the base: `branch="$(yayh git branch-name docs "roadmap $(date +%Y-%m-%d)")"`, `wt="$(yayh git worktree "$branch")"`, and work in `$wt`. Reuse it if it exists today.

Commit by path with `docs(roadmap): <summary>` (the `roadmap` scope is always allowed): `git add -- docs/roadmap.md <promoted backlog files>`. Then push and `gh pr create --base <base> --assignee @me` per `--pr`/`--no-pr` (ask by default).

## Status (`--status`)

1. `yayh roadmap status` gives: horizon, current sprint, counts per section (open, in-progress, shipped, dropped), slipped items, open bugs by severity, and ready or in-progress plans.
2. `yayh roadmap check` for structure problems, and `yayh roadmap links` for items whose status lags behind their brainstorm or plan (current ≠ suggested).
3. Report, in this order:
   - the current sprint, its goal line, and each of its items with status
   - slipped items (sprint ended, not shipped)
   - critical and high bugs with no roadmap item or fix branch: they compete for this sprint's capacity
   - status drift from `links`, and check errors
   - the next actions, as commands: `/yay:brainstorm --from=R-<n>` for planned items without one, `/yay:plan --from=BS-<n>` for decided brainstorms, `/yay:implement P-<n>` for ready plans, `/yay:fix B-<n>` for root-caused bugs, and `/yay:roadmap` when the horizon has passed or a lot slipped
4. Never write in this mode.

## Quick edits

One small change, on a branch as above, then `yayh roadmap check`, commit and the PR question.
- `--add="<title>"`: `yayh roadmap add "<title>" sprint=<n|later> size=<S|M|L> "why=<one line>"`. Ask for the why and size when missing. Default sprint: `later`. Warn if the sprint is now over capacity.
- `--move=R-<n>:<n|later>`: `yayh roadmap move R-<n> <n|later>`. Warn about capacity, or when moving work into a freeze sprint.
- `--drop=R-<n>`: `yayh roadmap set R-<n> status dropped`, then ask for a reason and set it with `yayh roadmap set R-<n> note "<reason>"`. Never delete an item: ids aren't reused.

Commit: `docs(roadmap): add R-<n> <title>` / `move R-<n> to sprint <n>` / `drop R-<n>`.

## Plan (default)

1. **Where we are.**
   - With no `docs/roadmap.md` at all, the harness isn't set up: suggest `/yay:harness-init` and stop.
   - `yayh roadmap status`, `yayh roadmap check` and `yayh roadmap links`. Keep every existing item and its id.
   - **Legacy roadmap.** If `docs/roadmap.md` has content but no front-matter or no `### R-<n>` items (milestones, checklists, prose from the old harness), this run converts it:
     - Read it as evidence. Unfinished milestones and unticked "done when" boxes become candidates (step 3); finished ones are history and are dropped.
     - Lasting content that isn't a plan (scope rules, business rules, settled decisions) belongs in knowledge, not the roadmap. List those sections and ask (AskUserQuestion) whether to append them to `docs/knowledge/decisions.md` in the same commit, or leave them for `/yay:knowledge-update`. Non-interactive runs append them under `## From the old roadmap`. Never silently lose them. Old text often links docs the harness wipe removed: run `yayh knowledge check docs/knowledge/decisions.md` and repoint each dead path at its `docs/knowledge/` successor (or drop the link) before committing.
     - The new file replaces the old one entirely (the old version stays in git history). Say so in the confirm step.
   - **Legacy backlog files** (no `id:` front-matter) are still evidence. Read `docs/backlog/*.md` directly, not only `yayh artifact list backlog`. When one is promoted, give it front-matter first: `yayh fm set <file> id "$(yayh id next BL)"`, then `title`, `status promoted:R-<n>` and `created`.
   - Settle horizon, sprint length, start, capacity and freezes (from options, front-matter, or one AskUserQuestion with all the missing ones). Then `yayh roadmap sprints start=… length=… until=…|count=… first=<next sprint number>` gives the new sprint dates. Past and current sprints keep their headings and dates.
2. **Evidence.** Read what's there; don't invent demand.
   - Unfinished roadmap items, and `links` drift.
   - `yayh artifact list backlog --status=idea`, open bugs (`yayh roadmap status` lists them by severity), ready and in-progress plans, open and decided brainstorms.
   - `docs/knowledge/known-issues.md` and `decisions.md`, and the `CLAUDE.md` project block.
   - `readme.txt`: features, recent changelog, and "Requires at least" / "Tested up to" / "WC tested up to". A newer WordPress or WooCommerce release than "tested up to" is a compat item.
   - `git log --since=90.days --oneline` and unmerged branches, for work already under way.
   - `gh issue list --state open --limit 100` and `gh pr list --state open`, if gh works.
   - With `--web`: the plugin's wordpress.org page (installs, rating, the latest support threads, 1–3★ reviews) and 3–5 competitors. Hand this to one `Agent` with a fixed report format (pain points with links, competitor gaps), so the page dumps stay out of this context.
3. **Candidates.** For each, write: title, why (the customer value and its evidence: `B-<n>`, `BL-<n>`, `#issue`, a review URL), size S/M/L, editions, value high/medium/low, and `from` when it came from a backlog idea, bug or issue. Prefer small, evidenced items. A bug only becomes an item when it's bigger than a `/yay:fix` (otherwise it's just fixed).
4. **Schedule.**
   - Unfinished items in past sprints have slipped. Each one moves to the current or a new sprint, or to Later. Say which.
   - Fill sprints in priority order (must-haves, high value per day) up to capacity. A sprint that overlaps a `--freeze` window is a freeze sprint: hotfix-class items only, with the spare capacity kept for fixes. Say so in its `Goal:` line. Dependencies go first. Overflow goes to Later.
   - Give each new sprint a one-line `Goal:` under its heading.
5. **Confirm.** Show a table per sprint (id or "new", title, size, why) with the dev-days used against capacity, plus what goes to Later and what slipped. Ask once (AskUserQuestion: accept / adjust / cancel). With `--dry-run`, stop here. Non-interactive runs go on with the proposal and say so in the report.
6. **Write**, on a branch (above):
   - Front-matter: `horizon`, `sprint_length`, `updated` (today). Keep any other keys (`published`, `hub`).
   - Add the new sprint headings from `yayh roadmap sprints … --md`, each followed by its `Goal:` line. Never rewrite past sprints' headings.
   - Existing items: `yayh roadmap move R-<n> <sprint|later>`, and for each `links` drift, `yayh roadmap set R-<n> status <suggested>`.
   - New items: `yayh roadmap add "<title>" sprint=<n|later> size=… "why=…" ["editions=free, pro"] [from=…]`. It prints the id. Write `editions` with the config's edition names, comma and space separated.
   - Backlog ideas that became items: `yayh fm set docs/backlog/<file> status promoted:R-<n>`.
   - `yayh roadmap check` must have no errors.
7. **Commit and PR**: `docs(roadmap): plan to <horizon>`, as above.
8. **Report** the sprint table with the new ids, what slipped and where it went, what was promoted, the PR link, and the next step: `/yay:brainstorm --from=R-<n>` for the first item of the current sprint.

## Multi-agent (`--multi-agent`)

One read-only owner agent per plugin researches its repo; the owners then read each other's briefs, answer each other's integration asks and propose joint work; one synthesis agent schedules every plugin into the same sprints. The workflow script is `${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js`.

1. **Plugins.** `yayh roadmap peers` lists the sibling plugin folders (dir, name, slug, harnessed, path). `--plugins=all` means every harnessed peer plus this repo. Otherwise match each name against the dir, slug or name, case-insensitively, and stop on anything unmatched. Plugins without a harness can join the research, but get no roadmap file written (say so).
2. **Calendar.** Settle the horizon, sprint length, start, capacity and freezes once, for everyone (Plan step 1), then build the sprint list with `yayh roadmap sprints`.
3. **Cost.** The run uses 2N + 1 agents (N + 1 with `--rounds=1`). Say the count and confirm before starting when N > 3.
4. **Run** the Workflow tool with `scriptPath: ${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js` and `args`:
   ```json
   { "today": "YYYY-MM-DD", "horizon": "YYYY-MM-DD", "sprintLength": "2w", "capacity": 8,
     "focus": "", "web": false, "rounds": 2,
     "sprints": [{ "n": 1, "start": "…", "end": "…", "freeze": false }],
     "plugins": [{ "name": "YayReturns", "slug": "yayreturns", "path": "/abs/path", "repo": "owner/name or empty", "version": "1.1.0", "harnessed": true }] }
   ```
   Get `repo` from `gh repo view --json nameWithOwner -q .nameWithOwner` in each repo (empty if gh fails), and `version` from `YAY_REPO=<path> yayh version current`.
5. **Confirm.** Show the portfolio summary, the shared initiatives (owner, sprint, per-plugin work), the conventions, and a sprint table per plugin. Ask once.
6. **Write each harnessed plugin's roadmap**, in its own repo (`YAY_REPO=<path>` for every `yayh` call, `git -C <path>`), following Plan steps 6–7: on its own branch, `existing_id` items moved, new items added. A shared initiative's part gets `- shared: <initiative title> (owner <plugin>)` and `- depends: <plugin>:R-<n>` where the dependency is known. Skip `cut` items.
7. **Report** one line per plugin (items per sprint, PR link) and the shared initiatives. With `--publish`, publish a hub (below).

## Publish (`--publish`)

1. Load the `artifact-design` skill, then build one HTML page from the committed roadmap(s): the current sprint first, then a timeline of sprints with item cards (id, title, size, status colour), Later, open critical and high bugs, and for multi-agent runs the shared initiatives and one tab per plugin. Write it to the session scratchpad, not the repo.
2. If `docs/roadmap.md` has `published: <url>` (or `hub:` for a portfolio), republish to that URL with the Artifact tool. Otherwise publish a new private page and save its URL with `yayh fm set docs/roadmap.md published <url>` (`hub` in every plugin of a portfolio), committed with the roadmap.
3. If the Artifact tool isn't available, say so and leave the HTML file's path.

## Don'ts
- Never renumber, reuse or delete an `R-<n>`. Dropped items stay with `status: dropped`.
- Never edit `docs/roadmap.md` on the base branch, and never stage with `git add -A`.
- Don't rewrite past sprints' dates or move shipped items.
- Don't schedule past capacity or put feature work in a freeze sprint without the user agreeing.
- Don't invent evidence: every new item's `why` points at something real.
