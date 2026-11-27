---
id: BL-1
title: Drop --commit from /yay:plan and /yay:design
kind: deferred
status: open
from: P-7
affects: []
default:
decision:
created: 2026-11-27
---
# BL-1 Drop --commit from /yay:plan and /yay:design

P-7 removes `--commit` from `/yay:brainstorm`, because the file is written before a branch exists and `/yay:implement` carries it into the branch (`reference/artifacts.md:30`). The same reasoning applies to `/yay:plan` and `/yay:design`, which also have `--commit` ("commit when on a non-base branch"). It waited so P-7 stays small. Leaving them makes the three skills inconsistent until this is done.
