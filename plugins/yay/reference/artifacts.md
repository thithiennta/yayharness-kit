# Workflow artifacts

Every step of the workflow leaves a markdown file in the repo. Its front-matter is how the next step finds it. Skills must write front-matter exactly in this shape, because the kit's bash tools parse it.

## Front-matter rules (the parser depends on them)

- The file starts with a line `---` and the front-matter ends at the next `---`.
- One `key: value` per line, flat with no nesting. Keys are lowercase `snake_case`.
- Lists are inline: `tags: [checkout, blocks]`. Empty values are written `key:`, never `null` or `~`.
- No multi-line values. Prose goes in the body.
- Dates are `YYYY-MM-DD`. Refs are full or short git SHAs or tags.

## IDs

| Prefix | Artifact | Where |
|---|---|---|
| `R-<n>` | Roadmap item | `docs/roadmap.md`, one `### R-<n> Title` heading per item |
| `BS-<n>` | Brainstorm | `docs/brainstorms/YYYY-MM-DD-<slug>.md` |
| `P-<n>` | Plan | `docs/plans/<slug>.md` |
| `B-<n>` | Bug report | `docs/bugs/YYYY-MM-DD-<slug>.md` |
| `BL-<n>` | Backlog idea | `docs/backlog/<slug>.md` |

Get the next free ID with `yayh id next <PREFIX>`. It scans `docs/` and returns one more than the highest ID found. IDs never get reused, so when deleting an artifact, set its `status` to `dropped` instead. Two branches can claim the same ID. `/yay:implement` and `/yay:fix` check this before opening a PR, and the later branch renumbers.

Slugs are lowercase words joined by `-`, at most 50 characters (`yayh slug "<text>"`).

## Where artifacts live before they have a branch

`/yay:brainstorm`, `/yay:plan` and `/yay:debug` run before any branch exists, so they only **create new files** (`yayh artifact new …`) in the current checkout, uncommitted. They never edit tracked files there. `/yay:implement` and `/yay:fix` create the worktree, then move those files into it (`yayh artifact carry <worktree> <files>`). Status changes to existing tracked files (the roadmap item, an older brainstorm) happen inside the branch. That way every artifact is committed with the work it describes.

When you're already on a non-base branch, a skill may commit its new artifact there, if asked (`--commit`).

## Shapes

### Roadmap: `docs/roadmap.md`
```markdown
---
horizon: 2026-12-31
sprint_length: 2w
updated: 2026-11-10
published:                      # page URL, set by /yay:roadmap --publish (hub: for a portfolio)
---
# Roadmap: YayCheckout

## Sprint 1 (2026-11-10 → 2026-11-23)

Goal: checkout speed before BFCM.

### R-12 Express checkout buttons
- status: planned
- size: M
- why: one line on the customer value, with its evidence (B-3, #241, a review URL)
- editions: free, pro
- from: BL-9

## Later

### R-15 Import layouts from a URL
- status: planned
- size: L
```
- Sections are `## Sprint <n> (<start> → <end>)` (dates are `YYYY-MM-DD`, sprints in order and not overlapping), then `## Later`.
- Items are `### R-<n> Title` with `- key: value` bullets (no front-matter, because many items share one file). `status` and `size` are required. Optional: `why`, `editions`, `from`, `note` (e.g. why it was dropped), `shared` and `depends` (cross-plugin work).
- `status` is one of `planned`, `brainstorming[:BS-<n>]`, `planned-in:P-<n>`, `in-progress`, `shipped:<version>`, `dropped`. `/yay:roadmap` syncs it from brainstorms and plans (`yayh roadmap links`), `/yay:implement` sets `in-progress`, and `/yay:release` sets `shipped:<version>`.
- `size`: S (≤ 2 days), M (≤ 1 week), L (more).
- Edit with `yayh roadmap add|set|move`, and validate with `yayh roadmap check`.

### Brainstorm: `docs/brainstorms/YYYY-MM-DD-<slug>.md`
```
id: BS-3
title: Express checkout buttons
status: open | decided | dropped
from: R-12                      # roadmap item, bug id or empty
decision:                       # chosen option name once status is decided
created: 2026-11-10
```
Body: Problem, Constraints, Options (2 to 4, with tradeoffs), Recommendation, Open questions.

### Plan: `docs/plans/<slug>.md`
```
id: P-4
title: Express checkout buttons
status: draft | ready | in-progress | done | dropped
from: BS-3                      # brainstorm, roadmap item or bug id
roadmap: R-12
type: feat                      # branch type for /yay:implement (feat fix chore refactor perf docs test)
branch: feat/express-checkout   # set by /yay:implement
pr:                             # PR number, set by /yay:implement
editions: [free, pro]
created: 2026-11-10
```
Body: Goal, Non-goals, Approach, `## Tasks` as `- [ ] T1 …` checkboxes, each naming the files it touches, then a `**Tests:**` line (tests the user accepted, or `none`) and a `## Verify` section with exact manual checks. `/yay:implement` ticks the boxes as it goes.

### Bug report: `docs/bugs/YYYY-MM-DD-<slug>.md`
```
id: B-7
title: Coupon field disappears after shipping change
status: open | root-caused | fixed | wontfix | duplicate
severity: critical | high | medium | low
editions: [pro]
found_in: 1.3.2                 # version, tag or ref
fixed_in:                       # version, set on release
branch:
pr:
created: 2026-11-10
```
Body: Symptoms, Environment (PHP/WP/WC/edition/theme), Repro steps, Root cause (`file:line` evidence and confidence high/medium/low), Fix options (1 to 3, with a recommendation), Regression test proposal.

### Backlog idea: `docs/backlog/<slug>.md`
```
id: BL-9
title: Import layouts from a URL
status: idea | promoted:R-15 | dropped   # promoted by /yay:roadmap
created: 2026-11-10
```

### Release notes: `docs/releases/<version>.md`
```
version: 1.4.0
date: 2026-11-24
editions: [free, pro]
tag: v1.4.0
```
Body: customer-facing notes (headline, New, Improved, Fixed). No commit hashes or internal IDs.

### Knowledge docs: `docs/knowledge/*.md`
```
area: architecture | conventions | integrations | known-issues | decisions | <custom>
updated: 2026-11-10
updated_ref: 062f792            # HEAD when last verified (yayh knowledge stamp)
covers: [includes/, yaycheckout.php]   # git pathspecs this doc describes
```
`yayh knowledge stale` lists files under `covers` that changed since `updated_ref`. The CLAUDE.md project block keeps the same two values on its start marker: `<!-- yay:project:start ref=062f792 updated=2026-11-10 -->`. What to write is in knowledge.md.

## Commit trailers

- `Plan: P-4`: added by `/yay:implement` on every commit in a plan's branch.
- `Fixes: B-7`: added by `/yay:fix`. `/yay:changelog` turns it into a customer-facing "Fixed" line, and `/yay:release` sets the bug's `fixed_in`.
- `Roadmap: R-12`: optional. `/yay:release` marks the item `shipped:<version>`.
