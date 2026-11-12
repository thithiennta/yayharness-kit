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

## Findings
<!-- Read this first. What reading the code changed about the source (brainstorm, roadmap item, bug), one numbered item each, with its file:line evidence and what the plan does about it. Then any docs the plan differs from: "differs: docs/knowledge/x.md says … → T4 updates it". Write "none" when the code held no surprises. -->

## Approach
<!-- The design in a few bullets: where it hooks in, data/storage changes, edition split, compatibility. Cite files. -->

## Tasks
- [ ] T1 <what> — `path/to/file.php`
  - Reuse: <existing function/hook/setting and its file>, or `none, new <name>() because …`
  - Callers: <each new symbol → what calls it (T<n> when a later task wires it)>. Leave this line out when the task adds no symbols.

**Tests:** none
<!-- One per risk, at the cheapest layer that proves it (reference/testing.md), separated by ";": [unit] test_name (tests/php/unit/X/YTest.php) — the risk; [integration] …; [js] …. Or none. -->

**E2E:** none
<!-- Browser-only acceptance criteria that get a Playwright spec tagged with this plan's id (reference/e2e.md). Usually none, at most 2. -->

## Verify
<!-- Exact checks. A command check: - `<command>` → exit 0 | <text the output contains> (yayh verify runs it). Otherwise the UI path and the result that means it passed. -->
-

## Risks
<!-- What could break, for whom, and how to roll back. -->
