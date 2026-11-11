# Working on a Yay plugin with Claude: onboarding

Every Yay plugin repo runs the same Claude Code harness, the **`yay`** plugin. It gives each repo the same rules, hooks and settings, project knowledge written from that repo's own code, and 16 `/yay:*` skills that take work from idea to tagged release in the same way for everyone.

This page is what a new developer needs. The kit internals are in [`plugins/yay/README.md`](plugins/yay/README.md).

## 1. Install once (5 minutes)

You need `git`, `bash`, `gh` (logged in) and one of `jq`, `node`, `php` or `python3`.

```bash
claude plugin marketplace add ~/yayharness       # for now; later: YayCommerce/yayharness on GitHub
claude plugin install yay@yayharness
```

To check it worked, open any harnessed plugin repo and run `claude`. Typing `/yay:` lists the skills, and `yayh version` prints the kit version.

A repo's `.claude/settings.json` enables the plugin, but that alone does **not** install it. Every teammate runs the install command once.

## 2. Your first session in a plugin repo

| The repo… | Do this |
|---|---|
| has `.yay/config.json` | Nothing. Start working. If the session starts with "harness is outdated", run `/yay:harness-update`. |
| has no `.yay/config.json` | One person runs `/yay:harness-init`, then `/yay:knowledge-init`, and merges the PR. Don't do it on several machines at once. |
| has knowledge older than the code | `/yay:knowledge-update`. Other skills suggest it when they notice drift. |

**Your personal settings** stay out of git:
- `.yay/local.json`: your own values, which override the shared config. Mostly `site.wpPath` and `site.url` for your local WordPress. When the repo sits in `wp-content/plugins/`, `site.wpPath` is worked out for you.
- `.claude/settings.local.json`: your own permissions.
- `CLAUDE.local.md`: your own notes for Claude.

## 3. The workflow

```
Feature   /yay:roadmap ─► /yay:brainstorm ─► /yay:plan ─► /yay:implement ─┐
Bug       /yay:debug ─► /yay:fix ─────────────────────────────────────────┼─► /yay:release ─► (merge) ─► /yay:release --tag-only
Hotfix    /yay:fix B-<n> --hotfix ─► /yay:release --hotfix ───────────────┘
```

**A feature, start to finish**
```text
/yay:roadmap --status                      # what's in this sprint, what slipped
/yay:brainstorm --from=R-12                # 2-4 options, a recommendation → BS-3
/yay:plan --from=BS-3                      # tasks, tests, verify checks → P-4
/yay:implement P-4                         # its own worktree + branch, a commit per task, PR assigned to you
```

**A whole sprint, unattended**
```text
/yay:autopilot --sprint=current            # brainstorm + plan every item, ONE decision sheet, then build each on its own branch
/yay:autopilot R-3 R-5 --parallel=2 --pr   # independent items two at a time; dependents stack on their dependency's branch
/yay:autopilot --sprint=3 --plan-only      # plans only: answer the sheet now, build later with /yay:autopilot --ready
```
Re-running the same command resumes: each item's stage comes from its brainstorm and plan. A blocked item stops only itself and what depends on it.

**A bug**
```text
/yay:debug "Coupon field disappears after changing shipping"   # root cause with file:line evidence → B-7
/yay:fix B-7                                                   # minimal fix + regression test, PR
```

**A release**
```text
/yay:release --dry-run          # preview the version, changelog and build plan
/yay:release                    # changelog, version bump, zips checked, release PR
/yay:release --tag-only         # after the PR merges: tag it and build the final zips from the tag
```

Each step leaves a markdown artifact in `docs/`, so the next step (or the next person) picks up where it stopped:

| ID | What | Where |
|---|---|---|
| `R-<n>` | Roadmap item | `docs/roadmap.md` |
| `BS-<n>` | Brainstorm | `docs/brainstorms/` |
| `P-<n>` | Plan | `docs/plans/` |
| `B-<n>` | Bug report | `docs/bugs/` |
| `BL-<n>` | Backlog idea | `docs/backlog/` |

Brainstorms, plans and bug reports start as untracked files in your checkout. `/yay:implement` and `/yay:fix` carry them into the work's branch, so they're committed with the code they describe.

The gates are soft. You can skip a brainstorm for an obvious change, or fix a tiny bug without `/yay:debug`, and the skills say so when they think you shouldn't.

### Browser tests (e2e)
```text
/yay:e2e-setup                             # once per repo: Playwright + wp-env in tests/e2e, seed data, smoke spec, CI workflow
/yay:e2e "customer redeems points at checkout"   # a spec for one flow, run against this checkout's own site
/yay:e2e --run=@P-4                        # run the specs that prove P-4 (and triage failures)
```
It's targeted. `/yay:plan` writes an `**E2E:**` line with only the flows a browser alone can prove, usually 0–2. `/yay:implement` writes and runs those specs, tagged `@P-<n>`. `/yay:fix` adds an `@B-<n>` regression spec only when the bug is a click path a unit test can't catch. `/yay:release` runs the full suite. Every checkout and worktree gets its own wp-env site and port (`yayh e2e status`), and specs never touch your real local site. Docker must be running; without it, specs are written and marked *not run*.

## 4. Code rules (loaded into every session)

The plugin loads [`plugins/yay/reference/code-rules.md`](plugins/yay/reference/code-rules.md) into every session in a yay repo:
- **Reuse before you write.** `yayh code find <verb> <noun>` and `docs/knowledge/helpers.md` show what already exists.
- **Keep diffs small.**
- **Comments:** WPCS docblocks yes. No new, grown or reworded comments unless the code they describe changed, and nothing explaining other files.

Three things check this, and none of them block:
- after each edit, a hint when a new function looks like an existing one, or an edit only touches comments
- `yayh review diff`, at any time
- the `yay:code-reviewer` agent, before every PR from `/yay:implement` and `/yay:fix`

Findings are fixed, or answered in the PR's "Reuse and comments review" section.

### Asking less, blocking less

Skills ask at most **one round of 1–3 questions**, and only the hardest ones: decisions that are expensive to undo, or that only you can make. Claude decides the rest and lists it under **Decided** in the report or PR, so you can overrule anything afterwards. Skills never stop to confirm a default, a version, a draft or the next step. Work is committed locally, and the report ends with the push and PR commands (pass `--pr` to push straight away). Deleting, overwriting and pushing are the only things that always wait for a yes. The rules are in [`plugins/yay/reference/asking.md`](plugins/yay/reference/asking.md).

## 5. Git rules (hooks enforce these)

- **Branches:** `<type>/<slug>`, e.g. `feat/express-checkout` or `fix/coupon-field-vanishes`. There's no owner prefix; the PR is assigned to you instead (`gh pr create --assignee @me`). Release branches are `chore/release-1-4-0`.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org), `type(scope): summary`, at most 72 characters, no final period. Trailers link the work: `Plan: P-4`, `Fixes: B-7`, `Roadmap: R-12`.
- **Blocked by the hooks:** commits on the base branch, `--no-verify`, leftover `yay:debug` markers in staged code, tags made outside `/yay:release`, and hand edits to kit-owned or generated files.
- **Worktrees:** each task gets one under `.claude/worktrees/<slug>`. `/yay:release --tag-only` offers to remove the merged ones.
- **Pushing:** skills push only when you say so, or when you pass `--pr`.

When a hook blocks something, its message says why and what to do instead. Claude reads it and corrects course. Don't work around it.

## 6. What you can and can't edit

| Owner | Files | How to change them |
|---|---|---|
| kit | The `yay:managed` block of `CLAUDE.md`, `.claude/rules/yay-*.md`, `.claude/settings.json`, `.github/pull_request_template.md` | Not by hand. Extra settings go in `.yay/settings.extra.json`; then run `/yay:harness-update`. Changes for every repo go into this kit. |
| team | `.yay/config.json`: commands, editions, version files, package checks | Edit it in a PR, then run `/yay:harness-update`. |
| knowledge | The `yay:project` block of `CLAUDE.md`, `docs/knowledge/` | `/yay:knowledge-update`, or by hand. Keep the facts verifiable. |
| workflow | `docs/roadmap.md`, brainstorms, plans, bugs, backlog, releases | Through the skills. |

## 7. All 16 skills

| Skill | Most-used options |
|---|---|
| `/yay:harness-init` | `--dry-run`, `--keep=<path>`, `--editions=free,pro` |
| `/yay:harness-update` | `--check`, `--diff`, `--only=rules,settings` |
| `/yay:knowledge-init` | `--depth=quick\|full`, `--agents=N` |
| `/yay:knowledge-update` | `--since=<tag>`, `--check`, `--doc=<file>` |
| `/yay:roadmap` | `--status`, `--horizon=eoy`, `--capacity=8`, `--freeze=a..b`, `--add="…"`, `--multi-agent --plugins=a,b`, `--publish` |
| `/yay:brainstorm` | `--from=R-<n>\|BL-<n>\|B-<n>`, `--quick`, `--research` |
| `/yay:plan` | `--from=BS-<n>`, `--check`, `--tests=ask\|none` |
| `/yay:implement` | `P-<n>`, `--task=T3`, `--continue`, `--pr`, `--draft` |
| `/yay:autopilot` | `--sprint=current`, `R-<n>…`, `--ready`, `--parallel=N`, `--plan-only`, `--no-ask`, `--pr` |
| `/yay:debug` | `--area=<path>`, `--bisect=<good-ref>`, `--repro`, `--report-only` |
| `/yay:fix` | `B-<n>`, `--hotfix`, `--test`, `--pr` |
| `/yay:changelog` | `--dry-run`, `--since=<tag>` |
| `/yay:build` | `--edition=pro`, `--zip=<path>` |
| `/yay:release` | `minor`, `--dry-run`, `--wc-tested=X.Y`, `--tag-only`, `--hotfix` |
| `/yay:e2e-setup` | `--adopt`, `--no-ci`, `--no-run`, `--dir=tests/e2e` |
| `/yay:e2e` | `P-<n>`, `B-<n>`, `"<flow>"`, `--run=@P-4`, `--all`, `--triage` |

Every skill shows its full option list as you type it, and explains each option at the top of its `SKILL.md`.

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `/yay:` shows nothing | The plugin isn't installed: `claude plugin install yay@yayharness`, then restart `claude`. |
| "harness is outdated" at session start | `/yay:harness-update`. It only touches kit-owned files. |
| A commit is rejected | Read the hook's message. Usually the header is too long, the scope isn't in `git.scopes`, you're on the base branch, or a `yay:debug` marker is left in the code. |
| Two branches created the same ID | `/yay:implement` and `/yay:fix` check this before the PR (`yayh id conflicts`), and the later branch renumbers. |
| "version files disagree" | Run `yayh version list`, then fix them through `/yay:release`, or correct `versionFiles` in `.yay/config.json`. |
| The build fails a check | `/yay:build` says which file and why. Fix the package script or `package.forbidden`, never the zip. |
| Wrong Node version for builds | Add `.nvmrc`. `yayh run` uses it through nvm. |
| JSON errors from `yayh` | Install `jq`, or force an engine with `YAY_JSON_ENGINE=php`. |

## 9. Updating the kit

Kit changes go through a PR on this repo, with tests (`./tests/run.sh`) and `claude plugin validate plugins/yay`. Bump the version in `plugins/yay/.claude-plugin/plugin.json` and add a `plugins/yay/CHANGELOG.md` entry. After that, `/yay:harness-update` in each repo shows what changed. Teammates update with `claude plugin marketplace update yayharness && claude plugin update yay@yayharness`.
