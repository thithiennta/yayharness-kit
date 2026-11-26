# Item briefs

A brief says what one roadmap item **is**, so developers, and Claude in brainstorm, design, plan and autopilot, don't have to guess. The product manager owns it. How to build it stays with the developers. The shape is in `artifacts.md` (Item brief). It's not the release brief (`docs/roadmap/release-<v>.md`, one per version).

`/yay:roadmap` writes briefs two ways: **on request** (`--brief`) and **offered after planning** (below). Either way, every brief goes through the same steps.

## Write a brief (`--brief[=R-<n>] "<notes>"`)

1. **The item.** With `--brief=R-<n>`, the item must exist (`yayh roadmap list`). With `--brief "<idea>"` and no id, add the item first, as in **Quick edits** `--add` (title, size, why and acceptance inferred from the idea; sprint `later` unless the user names one), then brief it. An item that already has a brief (`yayh brief path R-<n>`) is updated, not replaced: read it, change what the notes change, and keep the rest.
2. **Gather.** Start from the user's words. Then read the item (`why`, `acceptance`, `from`, screenshots), its evidence (the bug, backlog note or issue it came from), and enough of the plugin to name real screens and settings: the knowledge docs, `yayh e2e surfaces`, and the admin and checkout screens the item touches. **Never invent** a number, a quote, a customer or a rule. What you don't know is an open question.
3. **Create and draft.** `yayh brief new R-<n> [--lang=…]` prints the path and links the item. The language is the config's `language` (`yayh config get language en`), unless the user asks for another; the notes can be in either language. Fill every section, in screen words, not code:
   - **In one line:** what it is and why, under 40 words (60 in Vietnamese).
   - **Problem:** who has it, when, and the evidence.
   - **What the user sees:** the main flow, numbered, with the exact labels a user reads ("WooCommerce › Settings › Gift wrap", "Add gift wrap (+$3)"). Then the one or two other paths that matter: first use, Free without Pro, a guest.
   - **Rules and edge cases:** one rule per bullet: limits, conflicts with other features, empty and error cases, Free vs Pro, existing data and settings.
   - **Out of scope:** at least one real thing it won't do.
   - **Done when:** 3 to 7 `- [ ]` checks, each something a tester can see or do. The item's one-line `acceptance` must be one of them, or covered by them. When the brief changes what done means, update the acceptance to match (`yayh roadmap set R-<n> acceptance "…"`).
   - **Open questions:** what developers must not decide alone, each with the leaning so far ("Leaning: …"). Write "None" when nothing is open.
   - **For developers** (optional, last): known constraints only, such as an API limit or data that must keep working. No approach.
4. **Ask once.** Find the gaps that would make a developer guess: an edge case the flow implies but no rule covers, scope a reader would assume, a check that can't be tested. If the user is there, ask **one** AskUserQuestion round (at most 3 questions, your leaning first, marked "(Recommended)", `asking.md`) on the gaps that change what gets built. Write the answers in. A gap you didn't ask about goes under Open questions with your leaning. With nobody to ask, everything goes there.
5. **Check.** Run `yayh brief check R-<n>` and fix every error. Fix each warning too, or keep it with a reason. Repeat until there are no errors.
6. **Cold reader.** Give **only** the text of `yayh brief render R-<n> --text` to one Agent (general-purpose), with `model` and `effort` from `yayh model resolve reader`, in the brief's language:
   > You are a developer new to this plugin. You'll build this item from this brief alone. Answer in one line each: 1) What will you build? 2) What would you have to guess? List each guess. 3) Which "Done when" check couldn't you test, and why? 4) Which words did you have to read twice?

   Answer 1 must match In one line. Each guess in 2 and 3 becomes a rule, a check or an open question. Words from 4 get rewritten. Check again, and test again, at most 2 rounds. Tell the user what the reader still guesses.
7. **Status.** Set `ready` (`yayh fm set <brief> status ready`) when check passes and Open questions says "None". Otherwise it stays `draft`. Developers can still use a draft brief: nothing waits on the status.
8. **Commit** with the roadmap: on the roadmap branch (as in **Where the edit happens**), `git add -- <brief> docs/roadmap` (the item's `- brief:` and `acceptance` bullets), `docs(roadmap): brief R-<n>`, then push and the PR as usual. With `--publish`, or when the user wants to send it: `yayh brief render R-<n>`, then publish that file as it is with the Artifact tool (`icon: "note"`). Never restyle it.
9. **Report:** the brief's path, its status, the questions you asked with their answers, the open questions left, what the cold reader still guesses, and `Next: /yay:brainstorm --from=R-<n>` (or `/yay:implement R-<n>` for a small, clear item).

## Offer after planning

Once `/yay:roadmap` has **written and committed** a plan, a version plan or `--add` items, briefs are offered for what it just scheduled. It never happens before then: the schedule is settled first.

1. **Candidates:** every item this run added or scheduled with no brief yet (`yayh brief path R-<n>` exits 3), of any size. No candidates: no offer.
2. **When not to offer:** with nobody to ask (`--no-ask`, autopilot, `--multi-agent`, a non-interactive run), in `--status`, `--close` and `--dry-run`. There, the report's Next line names `/yay:roadmap --brief=R-<n>` for the candidates instead.
3. **The offer**, one AskUserQuestion, after the report of what was written: "The roadmap is written. Write briefs for these items now?" Options: all candidates (Recommended, naming them), only the first sprint's (when the candidates span sprints), "Pick in chat", "Not now". With "Not now", the run ends with the `--brief` commands as Next.
4. **Draft all, then ask once.** For the chosen items, do steps 1–3 above for every brief first. Then ask **one** round for all of them together: at most 4 questions, on the gaps that would change the most work (usually in the bigger items), each question naming its item ("R-5 Gift wrap: …"). Every other gap goes under that brief's Open questions.
5. Then steps 5–7 for each brief. Run the cold readers in parallel, one Agent per brief. Commit them all in one commit (`docs(roadmap): brief R-3, R-5, R-6`) on the same branch, and push it to the open roadmap PR.

This is the one exception to "at most one round" (`asking.md`): an optional second round that starts a new job only after the first job is written. A run that needed no planning question asks only this one.

## For developers' skills

When an item has a brief (`yayh brief path R-<n>`), read it before the code. It's the product source of truth:
- the Goal starts from In one line
- What the user sees and Rules and edge cases bind every option and every task
- Out of scope is a Non-goal
- every Done when check becomes a Verify check (`yayh brief checks R-<n>` says how many; `yayh plan check` warns when Verify has fewer)
- an open question that changes the work goes to the run's question round, or becomes a backlog decision note with the brief's leaning as its default

No brief is the usual case: work from the item's title, `why` and `acceptance` as before. A missing brief never blocks or stops the work, and is no reason to ask.

Don't edit the brief from a developer's skill. When the code shows the brief is wrong or can't be done, say so in the report and leave a decision note (`from=R-<n>`) for the product manager.
