---
name: debug
description: Find the root cause of a Yay plugin bug without fixing it. Use when the user says "debug", "why does", "investigate", "find the cause", or reports an error, ticket or failing test. Tests hypotheses with parallel read-only agents (optionally WP-CLI repro or bisect) and writes docs/bugs/ B-<n> with file:line evidence, confidence, fix options and a regression test idea.
argument-hint: "<symptom|ticket text|log-path|B-<n>> [--area=<path>] [--since=<ref|version>] [--bisect=<good-ref>] [--logs] [--repro] [--agents=N] [--severity=critical|high|medium|low] [--quick] [--report-only]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion
---

# /yay:debug

Arguments: `$ARGUMENTS`

Find **why**, with evidence, and write it down. This skill doesn't fix product code. `/yay:fix` does that from the report. The report format is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Bug report).

## Options

| Option | Effect |
|---|---|
| `<input>` | A symptom in words, pasted ticket text, a log file path, or `B-<n>` to continue an existing report. |
| `--area=<path>` | Limit the search to this subtree. |
| `--since=<ref\|version>` | It worked at this ref or tag. Diff and log from there first. |
| `--bisect=<good-ref>` | Run `git bisect` between `<good-ref>` and HEAD. This needs a scriptable check (step 5). |
| `--logs` | Read the site's logs first: `debug.log` (`yayh config get site.debugLog`), WooCommerce logs (`<wpPath>/wp-content/uploads/wc-logs/`), and the PHP error log. |
| `--repro` | Try to reproduce on the local site with WP-CLI (`wp --path="$(yayh config get site.wpPath)"`), reading only, unless the user approves a write. |
| `--agents=N` | Maximum parallel hypothesis checkers (default 3). |
| `--severity=<s>` | Set the severity, instead of inferring it. |
| `--quick` | No agents and no repro. Read code, history and logs, then write the report with honest confidence. |
| `--report-only` | No instrumentation and nothing run against the site. Read-only investigation. |

## Steps

### 1. Intake
- For `B-<n>`, resolve it, read it, and continue from its current status.
- Otherwise, before writing anything, pull the facts out of the input: the exact error text, where it shows (storefront, checkout, admin, email, REST), the edition and version, WP/WC/PHP versions, the theme, block vs classic checkout, HPOS, and other plugins involved. Ask with **one** AskUserQuestion only for what blocks the investigation and can't be found out.
- `yayh artifact new bug "<short symptom>" severity=<s> editions="<e>"`. Fill in Symptoms and Environment now, and set `found_in` (`yayh fm set <file> found_in <version>`).

### 2. Ground
- Read the project block, `docs/knowledge/known-issues.md` (it may already be known), and the knowledge doc for the area.
- Find the code path from the symptom: grep for the error text, hook names, REST routes, or template names, then follow the call chain.
- History: `git log --oneline -20 -- <files>`, plus `--since` if given, and `git log -S'<symbol>'` for when a behavior appeared.

### 3. Hypotheses
Write 2–5 hypotheses, each specific and falsifiable. For example: "`OrderSync::apply()` reads `_billing_country` with `get_post_meta`, which is empty under HPOS". "Something with orders" is not a hypothesis.

### 4. Check them in parallel (skip with `--quick`)
Spawn one `yay:hypothesis-checker` agent per hypothesis, **in one message**, up to `--agents`. Each brief gets the hypothesis, the symptom and environment, the files to start from, and the read-only WP-CLI permission if `--repro`. Weigh the verdicts. Re-check any "supported" verdict yourself, against the cited lines, before relying on it.

### 5. Confirm (as far as the options allow)
- **Logs** (`--logs`): look for the matching lines and timestamps.
- **Repro** (`--repro`): read state with WP-CLI (`wp option get`, `wp wc …`, `wp eval` for reads). For anything that writes (creating an order, changing a setting), ask first.
- **Instrumentation** (not with `--report-only`): you may add temporary logging to product code. Every added line must carry a `yay:debug` comment marker, for example `error_log( '…' ); // yay:debug`. Hooks block commits that contain markers. **Remove all of them before finishing:** `yayh debug markers` must print nothing.
- **Bisect** (`--bisect`): write a check script that exits 0 when the code is good and 1 when it's bad (e.g. a grep, a `php -r`, or a unit test). Then run `git bisect start HEAD <good>`, `git bisect run <script>`, and `git bisect reset`. Record the first bad commit.

### 6. Write the report
Fill in every section:
- **Repro steps**
- **Root cause:** what happens, why, `file:line` evidence, the introducing commit or version if known, and **Confidence: high/medium/low** with the reason
- **Fix options:** 1–3, smallest first, with the files and the edition impact. Mark the recommended one.
- **Regression test proposal:** the name, file and suite, and the risk it guards. Or "none", with the exact manual check that proves the fix.

Set the status:
- `root-caused` when confidence is high or medium
- leave it `open` when low, and say what would settle it
- `duplicate` or `wontfix` with the reason (link the duplicate)

### 7. Wrap up
- Run `yayh debug markers`. It must print nothing. Run `git status` to confirm no product files changed: `git diff --stat` must be empty apart from the new report.
- If this is a trap others will hit, say so. `/yay:fix` or `/yay:knowledge-update` adds it to `known-issues.md` in the fix branch.
- Report the bug ID, the one-paragraph root cause, the confidence, the recommended fix, and the next step: `/yay:fix B-<n>` (or `--hotfix` when severity is critical or high and a release is affected).

## Don'ts
- Don't fix the bug here, not even a one-liner. The fix gets its own branch through `/yay:fix`.
- Don't write a root cause without `file:line` evidence. "Probably" goes under Confidence, not in the cause.
- Don't change site data without asking. Don't leave instrumentation behind.
