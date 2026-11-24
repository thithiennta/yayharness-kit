# Say the job back

Every `/yay:*` skill that starts from someone's words says the job back before the work, so a misunderstanding costs one correction instead of a branch. A plan or a bug report already is the restatement: a skill that starts from one skips this.

## The block

Show it in your reply, after you've read the code and the source and before you write any file:
```
Reading:   <what you understood, one line, in the user's terms>
Assumed:   <1-3 guesses the user can correct, or "nothing">
Not doing: <1-3 things a reader might expect that this leaves out>
Watch for: <1-3 blind spots in this repo for this change, or "nothing known">
Done when: <an exact check: `command` → expected, or UI path → what you see>
```
Each skill adds its own line:

| Skill | Extra line | Where the block lands |
|---|---|---|
| `/yay:implement`, `/yay:fix`, `/yay:plan` | `Model on: <path:line of existing code that does the same kind of thing>` (`none` when nothing similar exists; say so) | the plan's Goal, Non-goals and Approach, or the tiny lane's PR body |
| `/yay:brainstorm` | `Deciding: <the one decision the options settle>` | Problem and Constraints |
| `/yay:design` | `Who/Where: <who uses it, on which screen>` | Job and Where it lives |
| `/yay:debug` | `Seen:`, `Expected:` and `Since:` replace Reading; Done when is the repro check | Symptoms and Environment |
| `/yay:test`, `/yay:e2e` | one `Proving: <risk> → <layer> → <the check>` line per risk, instead of the block | the test's tag and the report |

Keep each line short. A thin request is normal: fill the gaps from the code, the item and the knowledge docs, and put your guesses under Assumed. **A gap is never a reason to stop.**

**Watch for** is the blind spot pass: what could catch this change out that the user may not have thought of. Pick at most 3 that the change really touches, plus any `docs/knowledge/known-issues.md` entry for its area:
- HPOS order storage (`wc_get_order`, never post meta on orders)
- block vs classic checkout and cart
- the Free vs Pro edition split
- page and object caching (a value shown per user or per cart)
- data and settings stored by older versions (upgrades, defaults, uninstall)
- multisite
- translations and RTL (new strings, the text domain)
- the minimum PHP, WordPress and WooCommerce versions

## Big work waits; small work doesn't

**Big work** stops once on the block before writing any file, when the user is there:
- `/yay:brainstorm` and `/yay:design`
- `/yay:debug` from a pasted thread or a description longer than a few lines
- `/yay:plan` and `/yay:implement` in the standard lane, from words or a roadmap item

Everything else shows the block and carries on: the tiny and small lanes, test and e2e, a run that starts from a plan or a bug report, `--no-ask`, autopilot's inner runs (its decision sheet is the stop), and any run with nobody to ask.

**The stop is the run's one question round** (`asking.md`), asked **with the AskUserQuestion tool**, never as text at the end of your reply: a reply that ends on a question ends the run, and the work never gets written. One AskUserQuestion:
1. "Is this the job?" with the block in the question. Options: "Yes, go on (Recommended)", "Adjust" (the user types the correction), and, when the request has a second plausible reading, that reading.
2. Then at most 2 of the skill's hard questions, moved up from where the skill would ask them.

`/yay:brainstorm` asks only question 1 at its stop: its hard questions belong with the pick of an option, which is its round (step 6).

A correction rewrites the block; carry on without asking again. **The stop is a question, never an exit.** With no answer (nobody there, the tool isn't available, an error), go on with your reading and list it under **Decided**. Never end a run at the stop, and never end your turn to wait for an answer typed in chat. When AskUserQuestion isn't in your tools, show the block and go on.

## `--interview`

On `/yay:brainstorm`, `/yay:plan` and `/yay:roadmap --brief`, when the user asks for it: after the block, ask **one question at a time** (AskUserQuestion, your leaning first, marked "(Recommended)"). Always ask the open question whose answer would change the most structure: what's stored, the user-facing flow, the scope. Write each answer into the block. Stop when nothing that's still open would change a task or a section, and say how many you asked. The user asked for it, so it doesn't count against the one round.

## The finish line

The final report opens with the block, each Done when followed by `passed`, `failed` or `not checked (why)`. Assumptions the user never confirmed go under **Decided**.
