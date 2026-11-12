# Git conventions

The kit's hooks enforce these, and `/yay:implement`, `/yay:fix` and `/yay:release` follow them.

## Branches

`<type>/<slug>`. `type` is one of `git.branchTypes` (default `feat fix chore hotfix docs refactor test`), and `slug` comes from `yayh slug`.

Work that has an artifact leads with its id, right after the type, so the branch, every commit and the PR line up: `yayh git branch-name feat "<title>" --id=P-4` gives `feat/p-4-<slug>`. The id is the most specific one: the plan (`P-<n>`) for planned work, the bug (`B-<n>`) for a fix. A roadmap item (`R-<n>`) leads only when there's no plan (the tiny lane). The roadmap link stays in the `Roadmap:` trailer and the PR body. Releases and kit chores carry no id.

| Started by | Branch | From |
|---|---|---|
| `/yay:implement <plan>` | `feat/p-<n>-<plan-slug>` (or the type the plan names) | `git.baseBranch` |
| `/yay:implement` tiny lane | `<type>/r-<n>-<slug>` or `<type>/b-<n>-<slug>` when it came from one, else `<type>/<slug>` | `git.baseBranch` |
| `/yay:fix <bug>` | `fix/b-<n>-<bug-slug>` | `git.baseBranch` |
| `/yay:fix --hotfix` | `hotfix/b-<n>-<bug-slug>` | the latest release tag |
| `/yay:release` | `chore/release-<x-y-z>` (from `yayh git branch-name chore "release x.y.z"`; dots aren't allowed in slugs) | `git.baseBranch`. A hotfix releases from its own `hotfix/<slug>` branch. |

Worktrees live at `<repo>/.claude/worktrees/<slug>/`, one per branch.

## Commits

[Conventional Commits](https://www.conventionalcommits.org): `type(scope): summary`. On a branch that leads with an id, the summary leads with it too: `feat(refunds): P-4 add refund window setting`. The post-commit hook hints when it's missing (`yayh git branch-id <branch>` prints the id). It's still a valid conventional header, so the changelog reads it as usual.

- `type` is one of `feat fix perf refactor docs test build ci chore revert`. Add `!` for a breaking change.
- `scope` is optional, lowercase, and from `git.scopes` when that list is non-empty. The kit's own scopes (`harness`, `knowledge`, `roadmap`, `changelog`, `release`) are always allowed.
- The summary is imperative, lowercase first word, no trailing period, at most 72 characters for the whole header.
- Trailers go at the end (`Plan: P-4`, `Fixes: B-7`, `Roadmap: R-12`). See artifacts.md.
- Never commit `// yay:debug` or `# yay:debug` markers. They're temporary instrumentation from `/yay:debug`.

## Pull requests

- Title = the conventional header of the change, id included: `feat(refunds): P-4 add refund window setting`.
- Assign the PR to its owner, the developer who asked for the work: `gh pr create --assignee @me …`. Ownership is recorded on the PR, never in the branch name, so there are no `<owner>/…` prefixes.
- Body comes from `.github/pull_request_template.md`: what and why, the linked artifact (`P-4`, `B-7`), what's worth a closer look, how it was verified and what wasn't, how to test it, and the editions affected.
- Release PRs are titled `chore(release): x.y.z`.
- **Merge with a merge commit** by default: `gh pr merge <n> --merge`, or the method `git.mergeMethod` names (`merge`, `squash` or `rebase`). A merge commit keeps each task's commit, with its `Plan:`, `Fixes:` and `Roadmap:` trailers, on the base branch. A squash merge folds them into one commit.

## Tags

`git.tagFormat` with `{version}` (default `v{version}`). They're annotated and made only by `/yay:release`, after the release PR merges (`--tag-only`), or on the hotfix branch for a hotfix. The hook allows a tag only when the command carries `YAY_RELEASE=1`.
