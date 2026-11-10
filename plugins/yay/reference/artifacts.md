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

## Shapes

### Roadmap: `docs/roadmap.md`
```markdown
---
horizon: 2026-12-31
sprint_length: 2w
updated: 2026-11-10
---
# Roadmap

## Sprint 1 (2026-11-10 → 2026-11-23)

### R-12 Express checkout buttons
- status: planned | brainstorming | planned-in:P-4 | in-progress | shipped:1.4.0 | dropped
- size: S | M | L
- why: one line on the customer value
```
The `### R-<n>` items use `- key: value` bullets instead of front-matter, because many items share one file.

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
status: idea | promoted:R-15 | dropped
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
area: architecture | conventions | known-issues | decisions | <custom>
updated: 2026-11-10
updated_ref: 062f792            # HEAD when last verified
```
`/yay:knowledge-update` uses `updated_ref` to diff only what changed since.

## Commit trailers

- `Plan: P-4`: added by `/yay:implement` on every commit in a plan's branch.
- `Fixes: B-7`: added by `/yay:fix`. `/yay:changelog` turns it into a customer-facing "Fixed" line, and `/yay:release` sets the bug's `fixed_in`.
- `Roadmap: R-12`: optional. `/yay:release` marks the item `shipped:<version>`.
