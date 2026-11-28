---
id: {{id}}
title: {{title}}
status: draft
from: {{from}}
roadmap: {{roadmap}}
design:
type: {{ptype}}
branch:
pr:
editions: [{{artifact_editions}}]
created: {{today}}
---
# {{id}} {{title}}

## Goal
<!-- What changes for the user, the decision it builds (from the brainstorm), and "done means…". -->

## Tasks
<!-- In build order. Each: what changes, the files it touches, [size: S|M|L], [after: T<n>] when it needs a task that isn't the one before, [risk: 3] when it's hard to undo. -->
- [ ] T1 <what> — `path/to/file.php` [size: S]

## Verify
<!-- The acceptance criteria. A command check: - `<command>` → exit 0 | <text the output contains> (yayh verify runs it). A check a test proves ends with its layer: (unit), (integration), (js) or (e2e). Otherwise the UI path and the result that means it passed. -->
-

## Risks
<!-- What could break, for whom, and how to roll back. -->
