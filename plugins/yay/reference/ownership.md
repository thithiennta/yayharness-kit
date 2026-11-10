# Who owns which file

Three owners write into a plugin repo. Each skill writes only to what its owner owns.

| Owner | Writes with | Files |
|---|---|---|
| **kit** | `/yay:harness-init`, `/yay:harness-update` | `.claude/rules/yay-*.md`, `.claude/settings.json`, `.github/pull_request_template.md`, `.yay/manifest.json`, the managed block of `CLAUDE.md` |
| **knowledge** | `/yay:knowledge-init`, `/yay:knowledge-update` | the project block of `CLAUDE.md`, `docs/knowledge/**` |
| **workflow** | brainstorm, plan, implement, debug, fix, roadmap, changelog, release | `docs/roadmap.md`, `docs/brainstorms/**`, `docs/plans/**`, `docs/bugs/**`, `docs/backlog/**`, `docs/releases/**`, the `readme.txt` changelog |
| **team** | humans | `.yay/config.json` (kit seeds it once), `.yay/settings.extra.json`, `.claude/rules/*.md` not prefixed `yay-`, `CLAUDE.local.md`, `.claude/settings.local.json` |

## Shared settings

`.claude/settings.json` is generated: the kit's template (the marketplace, `enabledPlugins`, base permissions) deep-merged with the team's `.yay/settings.extra.json`. Objects merge, arrays are combined without duplicates, and anything else takes the extra file's value. To change shared settings, edit the extra file and run `yayh harness sync --only=settings`. Personal settings go in `.claude/settings.local.json`. A hook blocks direct edits to `.claude/settings.json`.

## CLAUDE.md blocks

```markdown
<!-- yay:managed:start v=0.1.0 -->
…kit text: workflow, git rules, where things live…
<!-- yay:managed:end -->

<!-- yay:project:start -->
…knowledge text: what the plugin is, commands, hard rules, gotchas…
<!-- yay:project:end -->
```
Anything outside both blocks belongs to the team, and no skill touches it.

## The manifest: `.yay/manifest.json`

```json
{
  "kitVersion": "0.1.0",
  "updated": "2026-11-10",
  "files": {
    ".claude/rules/yay-git.md": { "sha256": "…", "template": "rules/yay-git.md" },
    "CLAUDE.md#managed":        { "sha256": "…", "template": "CLAUDE.managed.md" }
  }
}
```
Each entry records the hash of what the kit last wrote (`#managed` means only that block). `yayh manifest status` compares it with the file on disk:

| Status | Meaning | `harness-update` does |
|---|---|---|
| `clean` | Unchanged since the kit wrote it | Overwrites it with the new template |
| `modified` | Someone hand-edited it | Shows a diff and leaves it, unless `--force` |
| `missing` | Deleted | Restores it |

## What `/yay:harness-init` wipes

Wiped only after it shows the list and you confirm, and always on a branch:

- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursorrules`, `.cursor/`, `.windsurfrules`, `.github/copilot-instructions.md`
- `.claude/skills/`, `.claude/rules/`, `.claude/hooks/`, `.claude/agents/`, `.claude/commands/`, `.claude/agent-memory/`, `.claude/docs/`, `.claude/CLAUDE.md`, `.claude/settings.json`
- `docs/`, entirely

Never wiped: `.claude/settings.local.json`, `.claude/worktrees/`, `CLAUDE.local.md`, anything in `config.keep` or passed as `--keep=<path>`, and anything git doesn't track. Untracked files are listed so you can decide about them yourself.
