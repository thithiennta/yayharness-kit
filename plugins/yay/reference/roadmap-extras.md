# /yay:roadmap: vision, unclear items, legacy conversion, multi-agent, publish and Trello

Read by `/yay:roadmap` only when the run needs one of these. The main flow is in `skills/roadmap/SKILL.md`.

## Vision

A **vision** request names a direction or an outcome, not items ("make Giftly the go-to gift plugin for B2B stores", "this quarter is about retention"). Items derived from it shape the whole plan, so the questions come before the candidates, not in the step-5 round.

1. **Ask first, once.** Before Plan step 3, one AskUserQuestion (`asking.md`), at most 3 questions, each with your proposal first marked "(Recommended)". Skip any the request, the README's existing **Vision** paragraph or the evidence already answers. Ask nothing when all three are answered.
   - **Who and which edition:** the merchants it's for, and whether it's Free, Pro or both (`yayh config get editions`).
   - **Must-have and by when:** the one outcome that makes the vision true, and the horizon or target version it's due by.
   - **Out of scope:** what people might expect that this vision doesn't cover.
   Then stop and wait for the answers. The question message holds only where things stand (Plan step 1) and the questions: no candidate items, no schedule and no **Decided** list yet, since all of those depend on the answers. With nobody to ask, take your proposals, list them under **Decided**, and go on. This round replaces step 5's question round, unless scheduling raises a new hard call.
2. **Record it** in `docs/roadmap/README.md` (`docs/roadmap.md` in a single-file roadmap), between the title and the generated index, as plain lines (no `##` heading, no `- key:` bullets, which `yayh roadmap` would read as a section or an item):
   ```markdown
   **Vision** (<YYYY-MM-DD>): <one sentence>.
   For: <merchants>, <editions>. Must-have: <outcome> by <horizon|x.y.z>. Out of scope: <list>.
   ```
   A new vision replaces the old paragraph; git keeps the history. Later runs read it as evidence, and `/yay:brainstorm --from=R-<n>` can cite it.
3. **Vision as evidence.** An item derived from the vision is evidenced by it: its why is `vision <date>: <the part it serves>`, plus any other evidence. Say which items came from the vision under **Decided**, so they're easy to overrule. Size and schedule them like any other item; the must-have goes first, and nothing marked out of scope is added.

## Unclear items

A named item is **unclear** when its title, read with the evidence (bugs, backlog, issues, `readme.txt`, the code), allows two readings that would be built differently: a different user (merchant or shopper), screen, edition, or size (S against L). "Reminders" in a gift plugin could be a shopper's reminder before a scheduled delivery, or a merchant's for unsent gifts. A title is **clear** when only one reasonable reading remains: "Character counter under the gift message field at checkout". When a reading is clear, don't ask; the acceptance column in the report is the check.

1. **Restate, then ask once.** For each unclear item, write the acceptance you would use (what a user can see or do when it's done). Ask about all of them in one AskUserQuestion (`asking.md`), one question per item, at most 3:
   - Question: "I read '<title>' as: <acceptance>. Is that it?"
   - Options: that reading, marked "(Recommended)"; 1–2 other readings that would be built differently, each one line; the user can always type their own.
   Pick the recommended reading from the evidence (a matching bug, issue or backlog idea wins), and say what it rests on.
2. **More than 3 unclear items:** ask about the 3 whose readings differ the most in size or user. Write the rest with your reading, and add `yayh roadmap set R-<n> note "reading unconfirmed: <the alternative>"` to each, so `/yay:brainstorm --from=R-<n>` raises it again.
3. **Wait** for the answers before writing those items. Clear items in the same request don't wait: write them in the same commit once the answers are in, so there's still one commit. With nobody to ask, use the recommended readings, list them under **Decided**, and add the `reading unconfirmed` note to each.
4. **Write the answer in.** The chosen reading becomes the item's `acceptance`. When the answer changes the scope, adjust the title (keep the user's words where you can) and the size.

## Legacy conversion

- **Legacy roadmap.** If the roadmap (`docs/roadmap.md` in a repo from the old harness) has content but no front-matter or no `### R-<n>` items (milestones, checklists, prose from the old harness), this run converts it:
  - Read it as evidence. Unfinished milestones and unticked "done when" boxes become candidates (Plan step 3); finished ones are history and are dropped.
  - Lasting content that isn't a plan (scope rules, business rules, settled decisions) belongs in knowledge, not the roadmap. List those sections. By default, append them to `docs/knowledge/decisions.md` under `## From the old roadmap` in the same commit; the confirm round can change that. Never silently lose them. Old text often links docs the harness wipe removed: run `yayh knowledge check docs/knowledge/decisions.md` and repoint each dead path at its `docs/knowledge/` successor (or drop the link) before committing.
  - The new file replaces the old one entirely (the old version stays in git history). Say so in the confirm step.
- **Legacy backlog files** (no `id:` front-matter) are still evidence. Read `docs/backlog/*.md` directly, not only `yayh artifact list backlog`. When one is promoted, give it front-matter first: `yayh fm set <file> id "$(yayh id next BL)"`, then `title`, `status promoted:R-<n>` and `created`.

## Multi-agent (`--multi-agent`)

One read-only owner agent per plugin researches its repo; the owners then read each other's briefs, answer each other's integration asks and propose joint work; one synthesis agent schedules every plugin into the same sprints. The workflow script is `${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js`.

1. **Plugins.** `yayh roadmap peers` lists the sibling plugin folders (dir, name, slug, harnessed, path). `--plugins=all` means every harnessed peer plus this repo. Otherwise match each name against the dir, slug or name, case-insensitively, and stop on anything unmatched. Plugins without a harness can join the research, but get no roadmap file written (say so).
2. **Calendar.** Settle the horizon, sprint length, start, capacity and freezes once, for everyone (the skill's Plan step 1), then build the sprint list with `yayh roadmap sprints`.
3. **Cost.** The run uses 2N + 1 agents (N + 1 with `--rounds=1`). Only when N > 3, ask one question: start with this many agents? (Calendar defaults are decisions, listed under **Decided**, not questions.)
4. **Run** the Workflow tool with the whole text of `${CLAUDE_PLUGIN_ROOT}/workflows/roadmap-portfolio.js` (read it first) as `script`. Don't pass the plugin path as `scriptPath`: the Workflow tool only accepts a `scriptPath` it returned itself or one inside the session's working directory, so a plugin path is refused. Pass these `args`:
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
2. If the roadmap's front-matter (`yayh roadmap file`) has `published: <url>` (or `hub:` for a portfolio), republish to that URL with the Artifact tool. Otherwise publish a new private page and save its URL with `yayh fm set "$(yayh roadmap file)" published <url>` (`hub` in every plugin of a portfolio), committed with the roadmap.
3. If the Artifact tool isn't available, say so and leave the HTML file's path.

## Trello (`--trello`)

Optional, and only when the flag is given. The contract (board setup, list and card mapping, re-runs) is `${CLAUDE_PLUGIN_ROOT}/reference/trello.md`.
1. Find the board (`trello.board`), or ask for it once.
2. For every sprint heading in the horizon and `Later`: find or create its list.
3. For every item in those sections: create its card, or update and move the one in its `trello:` bullet. Shipped cards are marked done, dropped ones archived. Save new card URLs with `yayh roadmap set R-<n> trello <url>`, then `yayh roadmap check`.
4. `--status` and `--dry-run` never sync. With `--multi-agent`, each plugin uses its own `trello.board`; a plugin with none is skipped (say so).
5. Trello not connected: say so and carry on (the roadmap is still written and committed).
