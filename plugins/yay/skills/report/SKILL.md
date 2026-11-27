---
name: report
description: Write a short, plain report a developer shares with the lead or team - an idea, a summary of what they've done, a feature pitch, or a how-to guide - readable in a minute. Use when the user says "report", "write this up for the lead", "share my idea", "summarise what I did", "status for the boss", "pitch this feature", "write a guide for", "how do I explain to the team how to…", or wants to turn notes, a branch or a plan into something to send.
argument-hint: "<idea|done|feature|guide|check> [topic or notes] [--for=team|devs] [--from=<P-n|R-n|branch|check folder>] [--lang=en|vi] [--text] [--max-words=N]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Bash(open *), Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, Artifact
---

# /yay:report

Arguments: `$ARGUMENTS`

Turn what a developer knows into something the lead reads in a minute and can answer. The reader is busy and isn't in the code: they want **what this is**, **why it matters to users**, and **what you want from them**. Everything else is noise.

The kit does the hard part of keeping reports clean: the agent writes **text only**, into a fixed template. `yayh report render` makes the page with the kit's one plain look, and `yayh report check` rejects what makes reports hard to read. Never work around either one.

## Options

| Option | Effect |
|---|---|
| `idea` | Share an idea: the problem, the idea, what you need. |
| `done` | Summarise what you've done: results, what users notice, what's next. |
| `feature` | Pitch a feature: who it's for, what they'd see, why, size, questions. |
| `guide` | Show someone how to do something: before you start, numbered steps, how to check it worked, what to do if it goes wrong. |
| `check` | Share the result of a check (`/yay:woo-check`, and any check that writes a report folder): the verdict, what blocks the release, what else to fix, what's next. |
| `--for=team\|devs` | Guides only: who follows it. `team` (default) is support, a lead or a store owner, with every plain-language rule. `devs` is developers: commands, paths and setting names are allowed in backticks or a code block under their step, and the jargon warnings are off. |
| `[topic or notes]` | What it's about, or the user's raw notes. Without a kind, pick it from the words ("I finished…" is `done`, "customers want…" is `feature`, "how to…" or "steps to…" is `guide`, with `devs` when it runs commands or touches the code, "check results" or "kết quả kiểm tra" is `check`, anything else is `idea`). |
| `--from=<id\|branch\|folder>` | Ground it in a plan, roadmap item, brainstorm, bug or branch: read it, and for `done` read the branch's commits and PR. For `check`, a check's report folder: read its `report.md`, `areas.tsv` and `findings.tsv`. |
| `--lang=en\|vi` | The language the **reader** reads. Default: `language` from `.yay/config.json` or `.yay/local.json` (`yayh config get language en`), then English. The developer's notes can be in either language; the report is written in this one. |
| `--text` | Paste-ready text only, no page. |
| `--max-words=N` | Raise or lower the word limit: 300 in English, 450 in Vietnamese (each syllable counts as a word); a guide gets 400 and 600. The developers section and code blocks never count. |

## Steps

1. **Gather the facts.** Start from the user's words. With `--from`, read the source (`yayh artifact resolve <id>`). For `done`, also read `git log <base>..HEAD` and the PR (`gh pr view`), if there is one. Collect results, user impact and evidence (numbers, tickets, reviews). **Never invent a number, a date, a quote or a fact.** That includes things that sound safe: who is reviewing it, when it ships, that tests run automatically, that two items depend on each other, what a vague note "really" means. If the report needs something you don't have, ask once with AskUserQuestion. If the user isn't around, leave it out, or say plainly that it isn't known yet ("not reviewed yet", "release date not set"). A line you would have to flag as a guess doesn't go in the report.
2. **Create the file.** Run `yayh report new <kind> "<title>" [--lang=vi] [--for=devs]`. It prints `.yay/reports/<date>-<slug>.md`, which is gitignored and never committed. The title is the outcome in plain words, under 8 words: "Faster checkout for returning customers", not "AddressRepository refactor".
   - **Language:** write the whole report (title, body, For developers) in the file's `lang`, and keep the template's headings exactly as they are. A Vietnamese report uses **Tóm tắt** for In one line and **Dành cho lập trình viên** for For developers. When the notes are in another language, translate the meaning, don't copy sentences. In Vietnamese, use natural everyday words, not English tech words mixed in ("đã sửa", not "đã fix"; "đưa lên", not "deploy"; "dọn lại code" goes to the developers section).
3. **Write it for a reader outside the code.** Fill every section and delete each `<!-- hint -->` as you go.
   - **In one line (Tóm tắt) first:** what this is and what you want from the reader, in under 40 words. If the reader stops there, they still know what to do. The ask is what the notes ask for. When they ask for nothing, say "Nothing needed from you" and stop: don't add a softer ask of your own.
   - **Users, not code:** say what store owners or customers will notice. "Customers don't retype their address", not "cached the address in the session".
   - **Short:** 2–5 bullets per section, one idea per bullet, sentences under 20 words. No paragraph over 3 lines.
   - **Plain words:** no file names, class or function names, hooks, internal ids (`P-4`, `#231`) or jargon (endpoint, payload, refactor, cron…). If an id matters, say what it is.
   - **No decoration:** no emoji, symbols, colors, tables, images or HTML. Use bold at most once or twice, for the one thing the reader must not miss.
   - **For developers** is the only place for technical detail: files, code, ids, the PR link. It's optional, always last, under 200 words, and the page folds it away. Leave it out when nobody needs it.
   - **A check** turns a technical report into what it means for the store. Each finding becomes what it lets someone do or what customers would notice ("a shop manager could read other customers' orders"), never the rule name. Blockers come first; baselined problems are a count. Check IDs, `file:line`, tool names and the report's path go only under For developers. A run where everything passed is one line and "Nothing needed from you".
   - **A guide** is steps the reader follows, so it lives or dies on being followable:
     - One action per numbered step, in the order they do it, up to 12 steps. Name what they click or type exactly as it appears on screen ("Settings › Gift wrap › Enable").
     - After a step where something should happen, say what they see. End with **Check it worked**, and keep **If it goes wrong** to the 1–3 problems people really hit.
     - **For devs:** put each command in a code block under its step, indented under the number, exactly as typed. Paths and setting names go in backticks. The summary stays code-free. Only write commands that work in this repo: check them against `.yay/config.json` (`yayh config get commands`), the README and `yayh --help`, and run the harmless ones (status, list, `--help`) to confirm. Never guess a flag.
4. **Check.** Run `yayh report check <file>` and fix every `error`. Fix each `warn` too, or keep it only when it's really right (a product name that looks like camelCase). Repeat until there are no errors.
5. **Cold reader.** Run `yayh report render <file> --text` and give **only that text** to one Agent (general-purpose), with `model` and `effort` from `yayh model resolve reader`. Pass no file path, no conversation and no code. Prompt:
   > You are a team lead who doesn't read code. Read this report once. Answer in one line each: 1) What is this about? 2) What does the writer want from you? 3) Which words or sentences did you have to read twice, or not understand? 4) What's missing that you'd need to decide?

   For a guide, the reader is the person who follows it. For `team`, that's someone on the support team who has never done this; for `devs`, a developer new to this repo. Ask: 1) What will you be able to do at the end? 2) Walk through the steps in your head: at which step would you get stuck, and why? 3) Which words did you have to read twice? 4) How would you know it worked?

   Write the prompt in the report's language, and ask for answers in it too.

   Compare answers 1 and 2 with what the report means to say. If either is wrong or vague, or 3 lists anything (for a guide: any step it would get stuck on), rewrite those parts, then check and test again. Stop after 2 rounds, and tell the user what the reader still found unclear.
6. **Share.**
   - **Page** (the default): run `yayh report render <file>`. It writes `<file>.html` next to the markdown and prints the path. If the `Artifact` tool is available, publish that file as it is, with `icon: "note"` and a one-sentence `description`. Never edit, restyle or add to the rendered HTML: the plain look is the point. The page is already complete (title, light and dark mode, phone width). Without the Artifact tool, `open` the file locally.
   - **Text** (always, and the only output with `--text`): paste `yayh report render <file> --text` into your reply, inside a plain code block, so the user can copy it into Slack or chat.
   - Rewriting later updates the same file. Render and publish it again with the same `file_path` to keep the link.
7. **Report back** in a few lines: the link (or the local path), the paste-ready text, what the cold reader said about the final version, and any warning you kept, with the reason.

## Don'ts
- Don't write HTML, CSS or markdown outside the template's sections. The kit owns the look.
- Don't commit the report or put it in `docs/`. It's a message, not project history.
- Don't paste commit subjects, plan tasks or diffs into the body. Translate them into what changed for people.
- Don't pad it. A short report that passes the check beats a complete one nobody reads.
