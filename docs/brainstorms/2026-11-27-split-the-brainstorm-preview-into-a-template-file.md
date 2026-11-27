---
id: BS-4
title: Split the brainstorm preview into a template file
status: decided
from:
decision: "A: preview template in the skill folder"
created: 2026-11-27
---
# BS-4 Split the brainstorm preview into a template file

## Problem
`/yay:brainstorm` makes three outputs: the preview summary, the brainstorm file and the final report. Only the file has a template (`templates/artifacts/brainstorm.md`). The preview's shape and its prompt line are written into step 5 of `skills/brainstorm/SKILL.md`, mixed in with the loop and accept rules. The report is one sentence in step 7. That makes the preview format hard to find and change on its own, and `/yay:plan` has the same kind of block written its own way (`skills/plan/SKILL.md:89-108`).

## Constraints
- The loop rules (when it runs, how replies are handled) stay in `reference/preview.md`. Only the summary's shape moves.
- `templates/artifacts/brainstorm.md` is still what `yayh artifact new brainstorm` fills in, and its headings stay the same.
- `evals/brainstorm-previews-first` grades the preview's shape (`graders/preview-shape.md`). The move must keep that shape exactly, and the eval gets run again.
- Lesson from the 0.18–0.19 rollback (PR #52): no new step and no new layer.
- BS-2 (open) is about what goes inside the output files. This change only moves where the preview format lives, so the two don't clash.

## Options
### A. Preview template in the skill folder
- How: move the summary block and its prompt line from step 5 into `skills/brainstorm/preview.md`. Step 5 keeps the loop and accept rules, plus one clear pointer: read `preview.md` and show the summary in exactly that format. The file template stays in `templates/artifacts/`.
- Pros: step 5 gets shorter. The format lives in one file you can edit. `/yay:plan` can copy the pattern later.
- Cons: files bundled with a skill aren't loaded automatically, so if the pointer is weak the model may improvise. The formats live in two places (the skill folder and `templates/artifacts/`).
- Size: S

### B. One kit-wide output-templates folder, printed by a helper command
- How: `templates/output/` holds the file, preview and report templates for each skill, and a new `yayh` command prints one with the id and title filled in. Plan, debug and design move there later.
- Pros: every skill's outputs live in one place, and a script could check the shape later.
- Cons: a new command and its tests. Filling in a template does little for a preview the model writes freely. It's bigger than what was asked, and close to the layer PR #52 removed.
- Size: M

### C. Move the summary shapes into the shared preview reference
- How: add a "Brainstorm summary" section to `reference/preview.md` (later a "Plan summary" one), and point the skill to it.
- Pros: no new files. The loop rules and the shapes are read together.
- Cons: `preview.md` grows and mixes rules with formats. It isn't the template split that was asked for.
- Size: S

## Recommendation
**A.** It's the split that was asked for: the skill points to one template for its preview, step 5 gets shorter, and no script changes. Conditions agreed in the preview:
- **Only the preview gets a template file.** It's long, it changes often and an eval grades it. The report stays one line in step 7, because a separate file for it would be indirection with no gain. Add a report template only if the report grows beyond one line.
- **The pointer is explicit:** "Read `preview.md` and show the summary in exactly that format." Run `brainstorm-previews-first` again once before merging to prove the model opens the file.
- **Brainstorm only for now.** `/yay:plan` follows with the same pattern once this works.

I'd switch to B if every skill (plan, debug, design) should move to one shared templates folder at once.

## Open questions
- None.
