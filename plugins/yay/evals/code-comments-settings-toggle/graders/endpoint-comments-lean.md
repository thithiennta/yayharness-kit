---
type: llm
focus: { source: file, path: includes/MyAccountEndpoints.php }
---

Compare this file with the original, where every method had only a short WPCS docblock (summary line plus @param/@return tags) and there were no inline comments. Pass if the existing docblocks are unchanged, and any new comments are either a short WPCS docblock for a new method or at most one or two short inline lines explaining a non-obvious reason right where the code is. Fail if comments narrate what the code plainly does, explain behaviour that lives in another file, or reword existing docblocks.
