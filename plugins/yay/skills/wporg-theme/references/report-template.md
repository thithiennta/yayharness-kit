# Report template: the Theme Directory review

Themes are reviewed on a Trac ticket (themes.trac.wordpress.org), not by email. A reviewer posts the required items the theme fails, grouped by the required-items sections, and the ticket stays open in *reviewing* while the author updates; no reply for 7 days may close it, and **three or more distinct required issues may close it as not-approved** [REQ]. Write the report as that ticket comment would read, so the author can fix it before anyone sees it.

Rules:
- **Only sections with findings**, in the order below. Skip a section with nothing to report.
- **Every issue:** the checklist ID, the tag (`[gate]`, `[required]`, `[recommended]`), what is wrong, why (one line, the rule's wording), the fix, and **every** occurrence as `file:line` with the line. More than about 10: show 8 and "… N in all", the rest in the appendix.
- Lead with the count of distinct required issues and what it means for the ticket (0: likely approvable; 1–2: one round of fixes; 3+: risk of a not-approved close).
- The pre-review header and appendix are the skill's, not the reviewer's. Keep them short.

---

```markdown
<!-- pre-review header -->
> **Pre-review of <Theme Name> <version>** · slug `<slug>` · <block | classic | child of <parent>> theme · Text Domain `<td>`
> Reviewed: <`brandy-1.4.0.zip` (built with the repo's package command) | `<zip>` (as given) | repo source, not built: <why>>
> Checks run: build check ✔ · precheck ✔ · site <✔ TC Theme Check, F5, C1 | static only (<reason>)> · themes page <✔ screenshots | not run> · manual pass ✔
> **Theme Check REQUIRED:** <N or "none">. **Distinct required issues:** <N> (<what it means for the ticket>).
> **Verdict:** <Fix before upload | One round of fixes | Likely approvable>

## Theme Check `[gate]`
- <each REQUIRED result, as Theme Check words it, with the file>

## Required

### <Section name, e.g. Plugins / plugin territory> · F7 `[required]`
<What is wrong, one line.> <Why: the rule.>
**Fix:** <the change, concretely>
- `inc/post-types.php:12` `register_post_type( 'brandy_portfolio', … )`
- …

### <next section> · <IDs> `[required]`
…

## Recommended `[recommended]`
- <ID or [REC] item>: <one line each>

## Before you upload
- [ ] Theme Check passes with no REQUIRED results (Appearance → Theme Check, or `wp theme-check run <slug>`)
- [ ] <one line per required ID>
- [ ] Only one of your themes is in the review queue (U1)

<!-- pre-review appendix -->
**Uncertain** (check by hand): <items with why>
**Not checked:** <what didn't run and why>
**Full occurrence lists:** <ID: file:line, …>
```
