# yay preview loop

`/yay:plan` (step 7) and `/yay:brainstorm` (step 5) show a draft as a plain summary before writing their file, and then **discuss it** with the person until they accept. Each skill defines its own summary and accept action. The loop works the same way in both.

## When it runs
**Always, unless one of these says to skip it:**
- `--yes`, or the request says so in words: "just write it", "no preview", "don't ask", "don't ask me anything", "use your judgment and write it".
- `--no-ask`, autopilot, or `/yay:plan --check`.
- Another skill runs these steps inside its own flow (`/yay:implement` from a requirement or with `--explore`).

**Don't decide from the environment.** A `claude -p` run, a missing terminal, a sandbox or a tool that isn't allowed doesn't mean nobody will answer. Only the list above skips the preview. Don't ask the person whether to preview, and don't add an Open item about it.

When it's skipped, write the file straight away, and ask the skill's hard questions under the normal asking rules (`asking.md`): one round, or none. With "don't ask", none.

## Each round
**Round 1 is always a preview, never questions first.** Even when the source is thin or the code holds a surprise (a missing field, a bug in the way), draft the most likely version with defaults and put each question in **Open**. Don't stop to ask "how should I proceed?" before showing a draft. The person answers inside the loop.

1. Show the summary in your reply. It talks about the change, not the code: no file names, class or function names, commands or test file paths in **Steps**, **How**, **Tests** or **Checked by** ("the unit tests pass", not `php tests/run.php`; "the saved order shows the same text", not `wp eval …`). Only **Surprises from the code** may cite `file:line`, and the **Data** lines name keys, tables and where the data lives, never the functions that write it. Its first line says **"preview, nothing written yet"**. From round 2, put `Changed:` lines under the title, one for each change since the last summary.
2. Put the hard questions in the summary's **Open** section, each with the default the draft follows. The person answers them in plain words whenever they like. Don't use AskUserQuestion for them.
3. End your turn with the skill's prompt line, for example `→ Reply "write it" when it's right, or ask or change anything.` Then wait. Don't write the file, create the artifact or run `yayh artifact new` before the person accepts.

## Handling a reply
| The person… | You… | Show the summary again? |
|---|---|---|
| asks a question ("why not X?", "what about HPOS?") | answer it. Read the code if you need to, and cite `file:line`. Change the draft only when the answer shows a real problem, and then say so as a proposed change. | Only if the draft changed. Otherwise end with one line: `Draft unchanged. Write it?` (or the skill's accept prompt). |
| asks for a change | apply it the way you'd have written it the first time: open any file it touches that you haven't read, and redo the affected parts (tasks, data, tests, checks; or options and the recommendation) | Yes, with `Changed:` lines |
| answers an Open item | record the answer in the draft, and take it out of Open | Yes, when it changes something the summary shows |
| accepts (the skill's accept words) | leave the loop and write the file | No |
| says "stop" or "cancel" | write nothing, and list what was still open | No |

- **Any change to the draft shows the summary again**, whatever caused it: the person's request, an answer that exposed a problem, an Open item settled, or new code read during the discussion (a new Surprise). Never change the draft without showing it.
- If a change breaks a hard rule, the brief's acceptance or the source's decision, propose the closest change that doesn't, and give the reason on its `Changed:` line.
- When the discussion runs long, show the whole current summary again every 3 rounds, even with no change, so the latest draft is always on screen.
- There's no limit on rounds. Accepting in round 1 costs one reply.

## While the preview is open
- "go", "ok", "yes", "looks good" and "write it" mean **accept the preview**. They don't mean "run the Next command" (`asking.md`, End with one next step). The skill's accept action decides what accepting means.
- A new, unrelated request ends the preview with nothing written. Say so in one line before handling the new request.
- Once the file is written, the preview is over. A fix that `yayh plan check` forces afterwards, or a later revision, is reported, not previewed. Running the skill again on the written artifact starts a new preview.
