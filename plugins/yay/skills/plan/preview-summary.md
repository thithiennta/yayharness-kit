# Plan preview summary

The summary `/yay:plan` shows in step 7. The loop rules are in `reference/preview.md`, and what goes in **Open** is in step 7.

**The summary** goes in your reply, about 15-30 lines of plain words. Name screens, settings and data the way a merchant or the team would ("the Gift message setting", "the cart page"), not file, class, function or test-file names, and no commands, even in Steps, How it's built, Tests and Checked by ("the unit tests pass", not `php tests/run.php`; "the saved order shows the same text", not `wp eval …`). `file:line` only under Surprises. The one exception is **Data changes**: developers need the exact storage, so it gives every option, meta key, table or column the plan adds, changes or removes, with its shape, its default, and what happens to existing sites and on uninstall, never the functions that write it. It lists every one, not just the main one. No `Reuse:` or `Callers:` lines:

```
Plan preview, nothing written yet: <title> (<small|standard>, <n> tasks)
Changed: <one line per change since the last summary>   (round 2 on)
What it does: <the user-visible outcome, 1-2 lines>
Done when: <what someone sees or checks to call it finished>
How it's built: <2-3 lines: the approach, and the existing feature it copies>
Steps:
  1. <what changes>: <one line on how, or why it's first>  ⚠️ <why it's risky, if risk 3>
  2. …            (one line per task)
Surprises from the code: <1-3 findings that changed the approach, or none>
Data changes:   (or "Data changes: none")
  - <new|changed|removed> <where: option / post meta / order meta (HPOS-safe) / user meta / table / transient / cart item>
    `<key or table>`: <shape, e.g. string ≤200 chars | array {enabled:bool, max:int}>, default <value>
    Written when: <the event>. Read by: <the screens or flows>.
  - Existing data: <how sites upgrading from the last release are handled (migration, fallback default), or "nothing stored before">
  - Uninstall: <removed or kept, and which keys>
Tests: <each test in plain words: what it proves>
Checked by: <the 2-4 key Verify checks in plain words>
Not doing: <1-3 things>
Open: <decisions left, with what the plan does for now, or none>
```

**Prompt:** end the summary with `→ Reply "write it" when it's right, or ask or change anything.`
