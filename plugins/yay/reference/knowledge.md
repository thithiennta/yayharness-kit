# Project knowledge: what to write and how

Project knowledge is what a new developer, or a fresh Claude session, needs in order to change this plugin safely. It lives in two places:

1. **The `yay:project` block of `CLAUDE.md`.** Every session loads it, so keep it short: at most 90 non-empty lines (`yayh knowledge check` enforces this). It's an index, not a manual.
2. **`docs/knowledge/*.md`.** The detail, read on demand through "read when…" links from the block.

`/yay:knowledge-init` writes both. `/yay:knowledge-update` keeps them true. Nothing else writes them, except that a workflow skill may fix a doc it just made wrong, in the same PR.

## Ground rules

- **Only verified facts.** Every claim comes from code, config, git history or a command you ran. Cite the evidence (`includes/Foo.php`, `Foo::bar()`, the commit `abc1234`) where a reader would want to check it. Never write plans, wishes, or "should" without a source.
- **Explain what the code doesn't show.** Don't restate code that's easy to read. Write down the why, the traps, the cross-file contracts, and the "you'd never guess this" parts.
- **Exact names.** Use real paths, class names, hooks, option keys and commands, in backticks. `yayh knowledge check` fails on a path that doesn't exist.
- **Commands come from `.yay/config.json`.** The block lists them as the repo declares them. Run each one before you describe what it does, and if it fails on the base branch, say so in `known-issues.md`.
- **Short and scannable.** Use headings, tight bullets and tables. One fact lives in one place; elsewhere, link to it.
- **Each doc says when to update it.** Every doc starts with a one-line `> Update when: …` under its title.

## The `yay:project` block

Use these sections, in this order. Leave one out when it doesn't apply.

```markdown
<!-- yay:project:start ref=<sha> updated=<date> -->
## What this is
2–4 sentences: what the plugin does for a merchant, the editions and how they differ,
where it hooks into WordPress/WooCommerce.

## Layout
| Path | What |            ← top-level dirs that matter; 5–12 rows

## Commands
- `<command>`: what it does, and the trap (the Node version, it rewrites files, it needs a DB…)

## Hard rules
1. Numbered, short, each one about breaking things (data loss, the editions boundary, PHP floor, security…)

## Tests
When a test is warranted here, where tests live, how to run one. The default policy is in .claude/rules/yay-workflow.md.

## Read when…
- adding any function, hook or setting → [docs/knowledge/helpers.md](docs/knowledge/helpers.md) (reuse first)
- changing <area> → [docs/knowledge/architecture.md § <section>](docs/knowledge/architecture.md#section)
- …one line per knowledge doc or section
<!-- yay:project:end -->
```

## `docs/knowledge/` docs

Each doc has this front-matter (flat, see artifacts.md):

```
---
area: architecture
updated: 2026-11-10
updated_ref: 062f792
covers: [includes/, yaycheckout.php]
---
```

`covers` is a list of git pathspecs. When files under them change after `updated_ref`, the doc is **stale** (`yayh knowledge stale`). Make `covers` accurate: too wide and the doc is always flagged stale, too narrow and real drift goes unnoticed.

The core set: write each one that has content. If the repo is small, fewer docs is better.

| Doc | Contents |
|---|---|
| `architecture.md` | Boot sequence and entry points; layers and who writes what; storage (options, custom tables, post/order meta, transients) with key names; REST routes and AJAX actions; hooks the plugin exposes and consumes; how the editions are separated; frontend vs admin surfaces |
| `conventions.md` | House style beyond the linters; naming and prefixes; i18n; JS/React patterns; recipes like "how to add a setting / block / REST route / migration", each with a real example to copy |
| `integrations.md` | WooCommerce surfaces (HPOS, block vs classic checkout, emails…), themes, page builders, and other plugins it has compatibility code for, each with the file that handles it |
| `known-issues.md` | Gotchas with evidence: checks that fail on the base branch, environment traps, flaky areas, "looks wrong but is intentional" |
| `helpers.md` | The reuse map: helpers, services, settings getters and hooks that new code should call instead of re-implementing, grouped by job (Formatting, Settings, Eligibility, Escaping and capabilities, REST, Assets…). One line each: `Class::method()`, its file, and when to use it. Built from `yayh code index` plus reading the code, listing only what's meant to be reused, not every method. `covers` lists the helper directories |
| `decisions.md` | Decision log: `### <date> <decision>`, with why, what was rejected, and evidence (commit, PR or file). Built from git history and code comments |

Add an area doc (`admin.md`, `blocks.md`, `storefront.md`, …) only when an area is big enough that `architecture.md` would bloat. Each area doc gets its own narrow `covers`.

## Stamping

After writing or re-verifying a doc, run `yayh knowledge stamp <doc>` (or `yayh knowledge stamp CLAUDE.md`). That records HEAD as the ref the doc is true for. Stamp only what you actually verified.
