# Git conventions

The kit's hooks enforce these, and `/yay:implement`, `/yay:fix` and `/yay:release` follow them.

## Branches

`<type>/<slug>`. `type` is one of `git.branchTypes` (default `feat fix chore hotfix docs refactor test`), and `slug` comes from `yayh slug`.

| Started by | Branch | From |
|---|---|---|
| `/yay:implement <plan>` | `feat/<plan-slug>` (or the type the plan names) | `git.baseBranch` |
| `/yay:fix <bug>` | `fix/<bug-slug>` | `git.baseBranch` |
| `/yay:fix --hotfix` | `hotfix/<bug-slug>` | the latest release tag |
| `/yay:release` | `chore/release-<x-y-z>` (from `yayh git branch-name chore "release x.y.z"`; dots aren't allowed in slugs) | `git.baseBranch`. A hotfix releases from its own `hotfix/<slug>` branch. |

Worktrees live at `<repo>/.claude/worktrees/<slug>/`, one per branch.

## Commits

[Conventional Commits](https://www.conventionalcommits.org): `type(scope): summary`

- `type` is one of `feat fix perf refactor docs test build ci chore revert`. Add `!` for a breaking change.
- `scope` is optional, lowercase, and from `git.scopes` when that list is non-empty. The kit's own scopes (`harness`, `knowledge`, `roadmap`, `changelog`, `release`) are always allowed.
- The summary is imperative, lowercase first word, no trailing period, at most 72 characters for the whole header.
- Trailers go at the end (`Plan: P-4`, `Fixes: B-7`, `Roadmap: R-12`). See artifacts.md.
- Never commit `// yay:debug` or `# yay:debug` markers. They're temporary instrumentation from `/yay:debug`.

## Pull requests

- Title = the conventional header of the change.
- Assign the PR to its owner, the developer who asked for the work: `gh pr create --assignee @me …`. Ownership is recorded on the PR, never in the branch name, so there are no `<owner>/…` prefixes.
- Body comes from `.github/pull_request_template.md`: what and why, the linked artifact (`P-4`, `B-7`), what's worth a closer look, how it was verified and what wasn't, how to test it, and the editions affected.
- Release PRs are titled `chore(release): x.y.z`.

## Tags

`git.tagFormat` with `{version}` (default `v{version}`). They're annotated and made only by `/yay:release`, after the release PR merges (`--tag-only`), or on the hotfix branch for a hotfix. The hook allows a tag only when the command carries `YAY_RELEASE=1`.
