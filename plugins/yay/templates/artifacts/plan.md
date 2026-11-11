---
id: {{id}}
title: {{title}}
status: draft
from: {{from}}
roadmap: {{roadmap}}
design:
trello:
type: {{ptype}}
branch:
pr:
editions: [{{artifact_editions}}]
created: {{today}}
---
# {{id}} {{title}}

## Goal
<!-- One paragraph: the user-visible outcome and how we'll know it's done. -->

## Non-goals

## Approach
<!-- The design in a few bullets: where it hooks in, data/storage changes, edition split, compatibility. Cite files. -->

## Tasks
- [ ] T1 <what> — `path/to/file.php`
  - Reuse: <existing function/hook/setting and its file>, or `none, new <name>() because …`

**Tests:** none
<!-- One per risk, at the cheapest layer that proves it (reference/testing.md), separated by ";": [unit] test_name (tests/php/unit/X/YTest.php) — the risk; [integration] …; [js] …. Or none. -->

**E2E:** none
<!-- Browser-only acceptance criteria that get a Playwright spec tagged with this plan's id (reference/e2e.md). Usually none, at most 2. -->

## Verify
<!-- Exact checks: the command or UI path, and the result that means it passed. -->
-

## Risks
<!-- What could break, for whom, and how to roll back. -->
