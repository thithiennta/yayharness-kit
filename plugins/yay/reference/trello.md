# Trello sync (optional)

`/yay:roadmap --trello` and `/yay:plan --trello` copy their work to a Trello board, through the Trello MCP server (`mcp__trello__*`). It's opt-in: nothing touches Trello without the flag. The repo files stay the source of truth: Trello is a mirror, and a sync never reads changes back from it.

## Setup

- **Board:** `yayh config get trello.board` (a board URL or ARI). The team board goes in `.yay/config.json`; a personal board goes in `.yay/local.json`.
- **Plan list:** `yayh config get trello.list` (default `To Do`): where plan cards go when their roadmap item has no card.
- **No board set:** list the boards (`trelloReadBoard` `list`) and ask one question: which board. Write the answer to `.yay/local.json` as `{"trello": {"board": "<url>"}}`, merged into what's there (`jq`), and say it can move to `.yay/config.json` for the team.
- **No Trello tools in the session** (the MCP server isn't connected): say so, print what would have been synced, and finish the rest of the work. The flag never fails a run.

## What goes where

| Source | Trello |
|---|---|
| Roadmap sprint `## Sprint <n> (<start> → <end>)` | A list with that exact name, created if missing (`trelloWriteList` `create`, `pos` in sprint order) |
| `## Later` | A list named `Later` |
| Roadmap item `R-<n>` | A card `R-<n> <title>` in its sprint's list. Description: `why`, `size`, `editions`, `from`, `status`, and `docs/roadmap.md`. Due date: the sprint's end, 09:00 in the Trello user's timezone (`trelloReadMember` `get_me`), sent as UTC |
| Item `shipped:<version>` | Card marked done (`mark_done`), left in its list |
| Item `dropped` | Card archived (reversible in Trello) |
| Plan `P-<n>` | A checklist `P-<n> <title>` on its roadmap item's card; with no item card, a card `P-<n> <title>` in `trello.list`, with a `Tasks` checklist. One check item per task: `T<n> <what>` |
| Plan task ticked `[x]` | Its check item checked |

## Linking, so re-runs update instead of duplicating

- The card URL is saved in the repo: `yayh roadmap set R-<n> trello <url>` on the item, `yayh fm set <plan> trello <url>` on the plan. It's committed with the roadmap or plan.
- On the next sync, read the saved card (`trelloReadCard`, which gives the card id), then update its name, description and due date, and move it when the item moved sprint. Never create a second card for an id that has one.
- A saved card that's gone (deleted, or on another board) is created again, and the new URL replaces the old one. Say so.
- Re-syncing a plan replaces the checklist's items to match the `## Tasks` list: rename changed items, add new ones, keep the checked state of the rest. Don't delete items; a task removed from the plan gets its item renamed `(removed) T<n> …`.
- Only touch cards and lists the sync made or names. Other cards on the board are left alone.

## Report

End with one line per card (`created`, `updated`, `moved`, `done`, `archived`, with its URL) and anything skipped and why.
