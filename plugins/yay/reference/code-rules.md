# yay code rules

The yay plugin's SessionStart hook loads these into every session in a yay repo, so they're always current with the installed kit. They apply to every code change: plans, implementation, fixes and quick edits alike.

## Reuse before you write
- **Search before creating.** Before adding a function, method, class, hook or constant, search for one that already does the job. Search by the verb and the noun (`format price`, `get setting`, `is eligible`), with `yayh code find <words>` or Grep. Also read how neighbouring code solves the same problem.
- **Call what exists.** Use the existing helper, service, setting getter or filter, even if you'd have written it differently. Extend it (a parameter, a filter) rather than writing a near-copy.
- **Say why when you add.** If you still add a new function, say in one line why the existing one doesn't fit, in your reply or in the plan's `Reuse:` line.
- **Never re-implement plugin or WooCommerce helpers inline.** That covers price formatting, settings reads (no `get_option` where a settings class exists), capability checks, escaping and date maths.

## Write only what's used
- **Nothing "for later".** Add only what this change calls. That means no helper, parameter, option, setting, filter, action or REST field for a future need. A filter or action for other plugins counts as used only when the plan names it as an extension point.
- **Check every symbol you added has a caller.** Before you finish, run `yayh code unused` and deal with each line: delete the symbol, or call it where the change needs it. A test alone is not a caller. When WordPress or WooCommerce calls the method by name (a parent class's method you override, a callback named in a string), keep it and say so.
- **Unused code outside the task:** don't delete it in the same change. Write it down as a `kind=deferred` backlog note, or mention it in your report.

## Keep the diff small
- Touch only what the task needs: no drive-by renames, reformatting or refactors. Mention those as follow-ups instead.
- Match the file's existing style and structure.

## Comments
WPCS requires docblocks. It doesn't require inline comments, so add one only where the rule below allows it.
- **Docblocks** on new files, classes, functions and hooks, as WPCS requires: a one-line summary plus the `@param`, `@return` and `@since` tags the repo uses. No prose paragraphs. A filter or action gets the usual hook docblock.
- **Inline comments** only for a non-obvious *why* about the line right below them. Never say what the code plainly does, and never add a comment to a self-describing key or setting.
- **Never edit, extend or reword an existing comment** unless the code it describes changed in this task. Don't append lines to an existing comment block.
- **Don't explain behaviour that lives in another file.** It goes stale. Put design reasoning in the commit body, the PR description, or `docs/knowledge/decisions.md`.
- No change-log comments ("added for X", "fixed bug Y", "new:"), and no commented-out code.
- **Required by WordPress, so always keep them:** `/* translators: … */` before a string with placeholders, `phpcs:ignore` with its reason, and markers the build uses (e.g. `@premium-start` / `@premium-end`).
