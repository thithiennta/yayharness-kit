# Brainstorm preview summary

The summary `/yay:brainstorm` shows in step 5. The loop rules are in `reference/preview.md`.

**The summary** goes in your reply, about 15-30 lines of plain words. Name screens, settings and flows the way a merchant or the team would, not file, class or function names, commands or test file paths ("check the saved order", not `wp eval …`). `file:line` only when a Must keep needs it. Each option's **Data** line is the exception: it names the exact option, meta key, table or column the option adds or changes, never the functions that write it, because where data lives is often what separates the options and what's hardest to undo. Full shapes, upgrades and uninstall belong in the plan.

```
Brainstorm preview, nothing written yet: <title> (from <id>)
Changed: <one line per change since the last summary>   (round 2 on)
Problem: <1-2 lines>
Must keep: <the constraints that bind: editions, block/classic checkout, existing data, the brief's rules>

A. <name> (<S|M|L>)
   How: <1-2 lines>
   ✅ <main pros>  ⚠️ <main cons and risks>
   Data: <`key`/table and where it lives, or none>
B. …

Recommend: <letter>, because <why>. I'd switch to <letter> if <what would change your mind>.
Open: <questions only a human can answer, each with the default, or none>
```

**Prompt:** end the summary with `→ Reply with a letter to pick it, "ok" for <recommended letter>, "leave it open", or ask or change anything.`
