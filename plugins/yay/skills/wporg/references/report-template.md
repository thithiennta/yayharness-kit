# Report template: the WordPress.org review email

Write the report as the email the Plugins Team would send for this plugin today, so the author sees it exactly as it will arrive. Match their section titles, their order, their wording style, and their "Example(s) from your plugin" blocks. The two real 2026 emails this follows are summarized in `wporg-rules.md` §2.5.

Rules:
- **Include only sections that have findings.** The real emails leave out any section with nothing to report. The "Your next steps" checklist lists only the sections included.
- **Skip the boilerplate** ("Who are we?", "The review process", "Before you reply", "Response times", "Disclaimers"). The author has seen it, and it hides the findings.
- Use the team's emoji conventions: `🔴` before each issue heading, `✨` before a one-line, AI-style explanation of a specific example, and `ℹ️`, `🔍`, `🛠`, `✅` and `❌` where the team uses them.
- **Every issue gives the reason, the fix, and the examples.** List *all* occurrences you found, not 2–3 like the team does. If there are more than about 10, show the first 8 and add "… out of a total of N incidences." Then put the full list in the appendix.
- Each example is a `file:line`, the code line, and then `----->` lines pointing to the exact expression. Add `# ↳ Detected origin: …` when you traced where a variable comes from.
- Tag each issue heading with where it gets caught: `[blocks upload]` for Plugin Check `plugin_repo` errors (the zip is refused), and `[review]` for issues that only appear in the email.
- **Put the checklist ID on every issue** (`checklist.md`): after the heading, before the tag, e.g. `### 🔴 Proper escaping of outputs · S4 `[review]``. One heading can carry several IDs (`S4, S12`). The fix commits use the same IDs, so round 2 can be checked ID by ID.
- The two blocks marked "pre-review" (header and appendix) belong to the skill, not to the email. Keep them short.

---

```markdown
<!-- pre-review header (not part of the email) -->
> **Pre-review of <Plugin Name> <version>** · slug `<slug>` · main file `<file>` · Text Domain `<td>`
> Reviewed: <`yay-bulk-order-1.0.0.zip` (edition free, built with the repo's package command) | `<zip>` (as given with --zip) | repo source, not built: <why> — results may differ from the uploaded zip>
> Checks run: build check ✔ · precheck ✔ · site <✔ T1 Plugin Check, Q11, Q7, Q10, Q6 | static only (no site: <reason>)> · manual pass ✔
> **Upload blockers:** <N, listed by heading, or "none">. **Review-email issues:** <N groups>.
> **Verdict:** <Blocked at upload | Will get this email | Likely approvable after minor fixes>

**<account or "yourname">** — Let's improve your plugin!

Thank you for submitting your plugin, "<Plugin Name>".

Our volunteer reviewers, tools, and/or AI aids identified issues in your plugin that require your attention.

---

## Have you read the guidelines and this plugin complies with them?

Our automated tools have detected patterns that may require a closer look regarding compliance with certain guidelines. In particular, please pay attention to the following:

- <one bullet per suspected guideline, in the team's wording, e.g.>
- Plugins must not restrict or lock functionality. (Guidelines 1, 5, & 9 — see clarification on SaaS in Guideline 6)
- Developers must provide public, maintained access to their source code and any build tools … (Guidelines 1, 4)
- Plugins should not hijack the admin dashboard. … (Guideline 11)

<Each bullet must match a concrete finding further down.>

## Is the name of this plugin descriptive and distinctive, and does it respect the trademarks and project names of others?

This plugin display name(s) is/are "<name>" and the slug is "<slug>". The AI has detected ✨ "<term>" as potential trademark(s).

✨ <One sentence: why it implies affiliation or is too generic or similar.>

For example, for your plugin:
An alternative name may be: ✨ <Own brand> <function> for <Project>
An alternative slug may be: ✨ <own-brand-function-for-project>

☑️ Steps to resolve this issue
- Update the display name in both readme.txt and the plugin headers.
- Update the slug in your plugin files (text domain, i18n functions, main file and folder name).
- Reply to the email **explicitly requesting the new slug**.
- Also check the username, display name, contributors, URLs (<Plugin URI>), icons and banners.

## Are you the rightful owner of this plugin?

This is what we know about this plugin:
- Plugin name: "<name>" in the readme.txt file
- Plugin name: "<name>" in the <main file> file
- Slug: <slug>
- Author: <Author> · Author URI: <Author URI> · Plugin URI: <Plugin URI>
- Contributors: <list>

This is what we know about you:
- Username: <WordPress.org account, if the user told you; otherwise "(the submitting account)">
- Email domain: <if known>

✨ <Why ownership is in question, e.g. "Plugin URI is on wpshadcn.com while the author is yaycommerce.com.">

☑️ You can demonstrate or clarify ownership in one of the following ways:
- 🌐 Add a DNS TXT record at the root of <domain>: `wordpressorg-<username>-verification`
- 📩 Change the WordPress.org account email to one on <domain>
- 👤 Ask for the submission to be transferred to the owner's account (do not resubmit)
- 🛠 Rename so that no affiliation is implied
- Reply explaining the relationship (same company, existing plugins on the account)

## Have you checked for common technical issues?

Please ensure that your plugin adheres to the guidelines and best practices, including the following:

### 🔴 <Team heading, e.g. "Proper escaping of outputs"> · <ID, e.g. S4> `[review]`

ℹ️ **Why it matters:** <1–2 sentences in the team's words.>

🔍 **Spot it:** <What pattern to look for.>

🛠 **Fix it:** <The wanted fix; a small table or code sample like the team's, e.g.>

```php
echo '<a href="' . esc_url( $profile_link ) . '">' . esc_html( $display_name ) . '</a>';
```

Example(s) from your plugin:

`includes/Engines/Shortcodes/templates/parts/product-table.php:132`
```php
<!-- wp:yay-bulk-order/product-table-column-<?php echo ( $ybo_slug ); ?> /-->
```
```text
-----> echo $ybo_slug;
# ↳ Detected origin: $ybo_column['slug'] ?? ''
```
> ✨ The shortcode-provided column slug is output unescaped into block-comment markup and is not sanitized during normalization.

… out of a total of <N> incidences.

> ✔️ You can check this using Plugin Check.

### 🔴 <Next issue> · <ID> `[blocks upload]`
…

## Other details

We've detected some other details that you may want to check.

### 🔴 <Lower-priority or judgment-call issue, e.g. "Check permission_callback in REST API Route", "Unclosed ob_start()", "load_plugin_textdomain() is not needed"> · <ID, e.g. S2> `[review]`
<Same shape: why, fix, examples. For judgment calls, add a "✅ When this is fine" paragraph like the team does for public REST routes, and say what the author should write in the reply to justify it.>

---

## 👉 Your next steps

This is your checklist:
- <one line per section included above, using the same titles, with the IDs it covers>

If there is something that needs to be fixed, please:
1. Take your time and fix it. Make sure that everything was addressed and the plugin works.
2. Update your plugin files at the "Add your plugin" page, while logged in with your account.
3. Reply to this email. Keep your reply short, direct and clear. Do not list the changes made; share only context or clarifications that help the review.

---

<!-- pre-review appendix (not part of the email) -->
## Pre-review notes

**Checked and clean:** <one line by ID, e.g. "S8: all 14 queries prepared · S1: all 9 AJAX handlers verified · Q11, Q7: clean on the site"; list only what you checked fully.>

**Site checks:** <each `site.tsv` line that isn't already an issue above: PASS lines in one line, SKIP lines with their reason (a skipped T1 means the upload gate didn't run: run Tools → Plugin Check by hand).>

**Uncertain:** <items you could not settle, and what would settle them.>

**Before you upload:**
- [ ] Build the zip without dev files: <what to exclude for this plugin>
- [ ] Zip under 10 MB; folder name = slug
- [ ] 2FA on the submitting account, which should be the company account for a company plugin; plugins@wordpress.org whitelisted, no auto-replies
- [ ] Re-run Plugin Check: zero errors in `plugin_repo`

**All occurrences:** <the full file:line list for any issue truncated above.>
```

## Which section an issue goes in

Follow the real emails:
- **Common technical issues:** trialware and locked features, nonces and permissions, escaping, sanitizing, SQL, header problems such as `Tested up to` in the plugin header, Text Domain and Stable tag, external services and tracking.
- **Other details:** REST `permission_callback` cases, direct file access (ABSPATH), public source for built files, update checkers, callback return escaping, unclosed `ob_start()`, `load_plugin_textdomain()`, prefixing, unneeded folders, and anything else lower in severity.
- Inside each section, order by risk: security first, then guidelines 5/6/7/8, then compatibility, then readme.
- Use the Common Issues heading from `wporg-rules.md` §2 when one exists. Otherwise use the heading the emails used (§2.5).
