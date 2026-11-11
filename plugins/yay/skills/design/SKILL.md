---
name: design
description: Design a simple UI/UX for a Yay plugin change that adds or changes something people see - an admin settings page or tab, a list table, a modal, a notice, a product/cart/checkout/My Account element, a block, an email. Use when the user says "design the UI", "how should this screen look", "wireframe", "UX for", "mock it up", or when a brainstorm or plan has UI work and no design. Grounds it in the plugin's existing screens and components, and writes docs/designs/ UX-<n> - the job, where it lives, the flow, ASCII wireframes, every state, the copy, accessibility and acceptance checks - plus an optional HTML mockup.
argument-hint: "<topic|BS-<n>|R-<n>|P-<n>|B-<n>> [--from=<id>] [--quick] [--mockup] [--check] [--commit]"
allowed-tools: Bash(yayh *), Bash(git *), Bash(open *), Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# /yay:design

Arguments: `$ARGUMENTS`

Turn a change that has a UI into a small, buildable design: a `UX-<n>` file that `/yay:plan` turns into tasks and `/yay:implement` builds to. The format is in `${CLAUDE_PLUGIN_ROOT}/reference/artifacts.md` (Design). This skill writes **only** the new design file, and, with `--mockup`, a local preview under `.yay/designs/`. It doesn't change code.

**Simple is the goal.** The best design here is the smallest one that does the job, looks like the rest of the plugin and of WordPress, and needs no explaining. A design that adds a screen, a field or a setting has to say why the job needs it.

## Options

| Option | Effect |
|---|---|
| `<topic\|id>` | What to design, or its source: `BS-<n>` (the usual case), `R-<n>`, `B-<n>` (a UX bug), or `P-<n>` (a plan with UI work and no design). |
| `--from=<id>` | The source, when the first argument is a topic. |
| `--quick` | One pass for a small change (one screen, a field, a notice): Job, Where, one wireframe, States, Copy, Acceptance. No mockup. `/yay:plan` uses this inline. |
| `--mockup` | Also write a self-contained HTML preview (`.yay/designs/<slug>.html`, gitignored) and open it. |
| `--check` | Review an existing design: `yayh design check`, then the simplicity and conventions review (step 5). Changes nothing unless the user agrees. |
| `--commit` | Commit the file when you're on a non-base branch (`docs(plan): add UX-<n> …`). |

## Steps

1. **Does it need a design?** Read the source (`yayh artifact resolve <id>`). A change needs one only when people will see something new or different. Backend-only work, a copy tweak to one string, or a screen that only gets an extra option in an existing, obvious place needs no design file: say so, give the one-line UI note for the plan (where it goes, the label, the default), and stop. Look for an existing design on the same topic (`yayh artifact list design`) and continue it rather than writing a second one. Also run `yayh backlog open --for=<source id>`: an open decision about this UI is yours to settle now if you can (`/yay:plan`'s "Picking up notes").
2. **Ground it in what exists.** Read the project block and `docs/knowledge/` (architecture's frontend/admin surfaces, conventions' JS/React patterns, and `e2e.md`'s Flows table when it exists). Then find:
   - **Where users already reach the plugin:** `yayh e2e surfaces` lists admin pages, settings tabs, shortcodes, blocks, My Account endpoints, cart and checkout hooks and emails, with `file:line`.
   - **The UI stack:** `package.json` (React with `@wordpress/components`, `@woocommerce/components`, Vue, a CSS framework), the admin page markup (WP `form-table`, the WooCommerce settings API, a React app root), and the plugin's own CSS classes or variables.
   - **The nearest existing screen** that does a similar job. Open it and its components. The new UI copies its layout, components, spacing, notices and save pattern. `yayh code find <noun> <component>` finds reusable components.
   - **Constraints:** editions (what Free shows when the feature is Pro), classic and block cart/checkout, themes on the storefront, RTL, small screens on the storefront.
3. **Design it**, filling the template top to bottom:
   - **Job:** one or two sentences: who, when, and done means what.
   - **Where it lives:** an existing menu, tab or section first. A new top-level admin menu, a new settings page or a new checkout step is a decision that must be justified under **Decisions**.
   - **Flow:** the main path as numbered steps, then the paths that matter (first use, an error, Free without Pro).
   - **Screens:** one `###` per screen or state that looks different, each with an ASCII wireframe in a ``` block (boxes, labels, buttons, sample data), then one line per element: what it is, the existing component or pattern it reuses with its file, and its behaviour (default, validation, what saving does).
   - **States:** empty, saving or loading, success, validation error, failure, no permission, and the Pro feature in Free. Say what the user sees, or `n/a` with the reason.
   - **Copy:** every visible string, sentence case, plain words, consistent with the plugin's existing labels.
   - **Accessibility:** a label on every field, keyboard order, focus after save and after an error, notices announced, contrast, RTL.
   - **Decisions:** what you chose and the alternative you didn't take.
   - **Acceptance:** 3–8 checks a reviewer or test can run: the action and the visible result.
4. **Mockup** (with `--mockup`, or when the layout is hard to judge from ASCII and the user is around): one self-contained HTML file at `.yay/designs/<slug>.html`. Use inline CSS that imitates the real surface (wp-admin's grey canvas, white panels, blue primary buttons, the form-table layout, or a plain storefront page), real copy from **Copy**, and every state from **States** stacked down the page under small headings. No external scripts, fonts or images. Record it with `yayh fm set <design> mockup .yay/designs/<slug>.html`, and `open` it when the user is present. It's a preview for discussion. The markdown stays the source of truth.
5. **Simplify, then check.** Review the design as a skeptical product designer:
   - Can a field, setting, screen or step go? Can a sensible default replace a choice? Can an advanced option hide behind a toggle or a link?
   - Is there exactly one primary action per screen, and is it obvious?
   - Does it look like the plugin's existing screens and like WordPress and WooCommerce (notices, buttons, list tables, settings layout), not like a new app?
   - Is every state covered, and does every error say how to fix it?
   - Free vs Pro: does Free show a locked feature honestly and only where the plugin already does upsells?
   - Storefront: does it work in classic and block checkout, on a narrow screen, and without breaking checkout when it fails?

   Apply what you find. Then `yayh artifact new design "<title>" from=<id>` (if not already written), fill every section, set `surfaces` (`yayh fm set <design> surfaces "[admin, checkout]"`), and run `yayh design check <UX-n>`. Fix every `error`, and the `warn`s unless there's a reason.
6. **Hard questions only** (`${CLAUDE_PLUGIN_ROOT}/reference/asking.md`). If the user is around and a choice is expensive to get wrong or is theirs to make (where it lives when that changes navigation, customer-visible behaviour at checkout, what Free shows), ask **one** AskUserQuestion with at most 3 questions, your pick first, marked "(Recommended)". A mockup or wireframe in the option's `preview` helps them compare. Everything else you decide. A call you can't make and that isn't worth asking becomes a backlog decision note (`yayh artifact new backlog "<question>" kind=decision from=UX-<n> default="<what the design shows>"`), noted under **Decisions**. When `yayh design check` has no errors and nothing hard is open, mark it ready: `yayh fm set <design> status ready`.
7. **Link it.** When a plan exists for this work (the source is `P-<n>`, or `yayh artifact list plan` finds one from the same source), set its `design:` (`yayh fm set <plan> design UX-<n>`) if the plan is still `draft` or `ready` and untracked, and say its UI tasks and Verify should follow the design (`/yay:plan P-<n>` revises it). A tracked plan is updated on its branch by `/yay:implement`.
8. **Report.** Give the file, the screens (one line each), the key decisions, the mockup path, the notes parked, and end with the **Next** line (`reference/asking.md`), usually `/yay:plan --from=UX-<n>`, or `/yay:plan P-<n>` to revise an existing plan.

### `--check` mode
Run `yayh design check <design>`, then step 5's review against the code as it is now: do the components and screens it reuses still exist, and does the plugin's UI still look that way? Report blocking issues and suggestions separately. Offer to apply them.

## Don'ts
- Don't write code, CSS or components here, and don't change other docs.
- Don't invent a new visual style, component library or navigation when the plugin or WordPress already has one.
- Don't add a setting to avoid making a decision: pick the default and record it.
- Don't design screens the source doesn't need. Extra ideas go into a deferred backlog note (`kind=deferred from=UX-<n>`).
