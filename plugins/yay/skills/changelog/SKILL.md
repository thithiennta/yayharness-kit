---
name: changelog
description: Write a Yay plugin changelog and release notes from git history. Use when the user says "changelog", "release notes", "what changed since", "what's in the next release", or from /yay:release. Rewrites customer-visible conventional commits in merchant language, in the readme.txt style the repo already uses, plus docs/releases/<version>.md.
argument-hint: "[--version=x.y.z] [--since=<tag|ref>] [--date=YYYY-MM-DD] [--no-readme] [--no-notes] [--replace] [--dry-run]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(gh *), Read, Write, Edit, AskUserQuestion
---

# /yay:changelog

Arguments: `$ARGUMENTS`

Turn commits into words a merchant understands. Two outputs:
- the **readme entry** (`changelog.readme`, usually `readme.txt`), in the style the file already uses
- the **release notes** (`docs/releases/<version>.md`), a short customer-facing story

## Options

| Option | Effect |
|---|---|
| `--version=x.y.z` | Version to write. Default: `yayh git bump "$(yayh version current)" "$(yayh changelog suggest)"`. Don't ask; say which version you used (`/yay:release` confirms versions). |
| `--since=<tag\|ref>` | Start point. Default: `yayh changelog baseline`, which is the last release tag, or the commit that introduced the current version when the repo has no tags yet. |
| `--date=YYYY-MM-DD` | Entry date. Default: today. |
| `--no-readme` / `--no-notes` | Skip one of the two outputs. |
| `--replace` | Throw away an existing entry for this version, hand-written lines included, and write it fresh. Without it, an existing entry is kept and only what's missing is added (step 5). |
| `--dry-run` | Print both outputs and write nothing. |

## Steps

1. **Collect.** Run `yayh changelog collect --since=<since>`. Its TSV columns are: sha, type, scope, breaking, subject, PR, Fixes, Roadmap and Plan. If it's empty, there's nothing to release; say so and stop.
2. **Classify.** Sort each commit into one of three groups:
   - **Customer-visible:** `feat`, `fix` and `perf`, plus any type that's breaking. Also a `refactor` or `chore` whose plan or PR says it changes behavior.
   - **Internal:** `docs`, `test`, `ci`, `build`, `chore`, a plain `refactor`, `chore(release)`, `chore(harness)` and `docs(knowledge)`. Leave these out of both outputs.
   - **Unclear:** read the commit (`git show --stat <sha>`) or its PR (`gh pr view <n>`, if gh works) before deciding. A plan's or PR's "Notes for release" line wins: if it says "internal", leave the item out.
3. **Context for good wording.** For each customer-visible item, read what tells you the user-facing effect: the plan's Goal (`Plan:`), the bug's Symptoms (`Fixes:`), and the PR body.
   - Mark items that only touch Pro code (paths in `package.forbidden` for the free edition, or a plan with `editions: [pro]`) as "(Pro)".
   - Merge commits that describe the same change into one line.
4. **Write the lines in the repo's style.** Run `yayh changelog style` to get the heading template, the bullet marker (`*` or `-`) and the labels the file already uses (e.g. `New, Fix, Tweak`), then match them exactly. If no labels are used yet, use `New:`, `Improved:` and `Fixed:`. Each line:
   - starts with the label
   - says what the merchant or shopper gets or no longer suffers, in present tense, ending with a period
   - avoids class names, hooks and internal IDs, unless the audience is developers (a hook added for developers: "New: `yayreturns_extra_delivery_days` filter for …")
   - goes in this order: New, Improved, Fixed, then developer items
   - for a breaking change, starts with "Breaking:" and says what to do
5. **Readme entry** (unless `--no-readme`).
   - **Hand-written lines win.** First run `yayh changelog entry <version>`. Lines already there (a developer may have written some ahead of the release) are kept exactly as written. For each customer-visible item from step 2, decide whether one of those lines already covers it, even in other words; if so, drop your line for it. Keep only the lines for what's missing.
   - Write those to a temp file, then run `yayh changelog write <version> <file> [--date=…] --merge` (or `--replace` when asked). `--merge` keeps the existing lines in their order, puts each new line after the last one with the same label, skips exact duplicates, and dates an undated heading (a dated one keeps its date unless you pass `--date`); with no entry yet, it just writes yours. Check the result with `yayh changelog entry <version>`.
   - A hand-written line with no commit behind it stays: say so in the report, so the developer can check it.
   - If the readme has `== Upgrade Notice ==` and the release is breaking or needs action, add a `= <version> =` entry there too.
6. **Release notes** (unless `--no-notes`). When `docs/releases/<version>.md` already exists, keep what's written and add only the missing items to its sections. Otherwise create `docs/releases/<version>.md` with the front-matter from `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Release notes) and these sections:
   - a one-line headline
   - **New**, **Improved** and **Fixed**: short paragraphs or bullets, written for merchants, with no commit hashes or internal IDs
   - "Before you update", only when action is needed
7. **Report.** Show the readme entry, marking which lines were kept from the hand-written entry and which were added (from the `merged` line), and the notes' headline. List the commits left out as internal (one line each), so the user can disagree.

## Don'ts
- Don't paste commit subjects verbatim. Rewrite them for merchants, and drop the artifact id a summary leads with (`P-4`, `B-7`, `R-12`).
- Don't invent changes that aren't in the commits, and don't drop a customer-visible fix because it's small.
- Don't change the readme's existing style or entries, and never reword or drop a hand-written line in this version's entry (only `--replace` does that).
