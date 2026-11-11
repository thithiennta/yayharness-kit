# /yay:roadmap: legacy conversion, multi-agent, publish and Trello

Read by `/yay:roadmap` only when the run needs one of these. The main flow is in `skills/roadmap/SKILL.md`.

## Legacy conversion

- **Legacy roadmap.** If `docs/roadmap.md` has content but no front-matter or no `### R-<n>` items (milestones, checklists, prose from the old harness), this run converts it:
  - Read it as evidence. Unfinished milestones and unticked "done when" boxes become candidates (Plan step 3); finished ones are history and are dropped.
  - Lasting content that isn't a plan (scope rules, business rules, settled decisions) belongs in knowledge, not the roadmap. List those sections. By default, append them to `docs/knowledge/decisions.md` under `## From the old roadmap` in the same commit; the confirm round can change that. Never silently lose them. Old text often links docs the harness wipe removed: run `yayh knowledge check docs/knowledge/decisions.md` and repoint each dead path at its `docs/knowledge/` successor (or drop the link) before committing.
  - The new file replaces the old one entirely (the old version stays in git history). Say so in the confirm step.
- **Legacy backlog files** (no `id:` front-matter) are still evidence. Read `docs/backlog/*.md` directly, not only `yayh artifact list backlog`. When one is promoted, give it front-matter first: `yayh fm set <file> id "$(yayh id next BL)"`, then `title`, `status promoted:R-<n>` and `created`.

## Multi-agent (`--multi-agent`)

One read-only owner agent per plugin researches its repo; the owners then read each other's briefs, answer each other's integration asks and propose joint work; one synthesis agent schedules every plugin into the same sprints. The workflow script is `${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js`.

1. **Plugins.** `yayh roadmap peers` lists the sibling plugin folders (dir, name, slug, harnessed, path). `--plugins=all` means every harnessed peer plus this repo. Otherwise match each name against the dir, slug or name, case-insensitively, and stop on anything unmatched. Plugins without a harness can join the research, but get no roadmap file written (say so).
2. **Calendar.** Settle the horizon, sprint length, start, capacity and freezes once, for everyone (the skill's Plan step 1), then build the sprint list with `yayh roadmap sprints`.
3. **Cost.** The run uses 2N + 1 agents (N + 1 with `--rounds=1`). Only when N > 3, ask one question: start with this many agents? (Calendar defaults are decisions, listed under **Decided**, not questions.)
4. **Run** the Workflow tool with `scriptPath: ${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js` and `args`:
   ```json
   { "today": "YYYY-MM-DD", "horizon": "YYYY-MM-DD", "sprintLength": "2w", "capacity": 8,
     "focus": "", "web": false, "rounds": 2, "models": { /* yayh model table --json */ },
     "sprints": [{ "n": 1, "start": "…", "end": "…", "freeze": false }],
     "plugins": [{ "name": "YayReturns", "slug": "yayreturns", "path": "/abs/path", "repo": "owner/name or empty", "version": "1.1.0", "harnessed": true }] }
   ```
   Take `models` from `yayh model table --json` in this repo (`${CLAUDE_PLUGIN_ROOT}/reference/models.md`). Get `repo` from `gh repo view --json nameWithOwner -q .nameWithOwner` in each repo (empty if gh fails), and `version` from `YAY_REPO=<path> yayh version current`.
   The workflow runs in the background: don't end your turn until its completion notification arrives. In a non-interactive run, ending the turn kills it.
5. **Show, don't ask again.** Show the portfolio summary, the shared initiatives (owner, sprint, per-plugin work), the conventions, and a sprint table per plugin. Then go on to write: every repo's change is its own branch and PR, easy to change or drop; with `--no-pr`, keep them local and print the commands.
6. **Write each harnessed plugin's roadmap**, in its own repo (`YAY_REPO=<path>` for every `yayh` call, `git -C <path>`), following Plan steps 6–7: on its own branch, `existing_id` items moved, new items added. A shared initiative's part gets `- shared: <initiative title> (owner <plugin>)` and `- depends: <plugin>:R-<n>` where the dependency is known. Skip `cut` items.
7. **Report** one line per plugin (items per sprint, PR link) and the shared initiatives. With `--publish`, publish a hub (**Publish**, below).

## Publish (`--publish`)

1. Load the `artifact-design` skill, then build one HTML page from the committed roadmap(s): the current sprint first, then a timeline of sprints with item cards (id, title, size, status colour), Later, open critical and high bugs, and for multi-agent runs the shared initiatives and one tab per plugin. Write it to the session scratchpad, not the repo.
2. If `docs/roadmap.md` has `published: <url>` (or `hub:` for a portfolio), republish to that URL with the Artifact tool. Otherwise publish a new private page and save its URL with `yayh fm set docs/roadmap.md published <url>` (`hub` in every plugin of a portfolio), committed with the roadmap.
3. If the Artifact tool isn't available, say so and leave the HTML file's path.

## Trello (`--trello`)

Optional, and only when the flag is given. The contract (board setup, list and card mapping, re-runs) is `${CLAUDE_PLUGIN_ROOT}/reference/trello.md`.
1. Find the board (`trello.board`), or ask for it once.
2. For every sprint heading in the horizon and `Later`: find or create its list.
3. For every item in those sections: create its card, or update and move the one in its `trello:` bullet. Shipped cards are marked done, dropped ones archived. Save new card URLs with `yayh roadmap set R-<n> trello <url>`, then `yayh roadmap check`.
4. `--status` and `--dry-run` never sync. With `--multi-agent`, each plugin uses its own `trello.board`; a plugin with none is skipped (say so).
5. Trello not connected: say so and carry on (the roadmap is still written and committed).
