<!-- yay:managed:start v={{kit.version}} -->
<!-- Kit-managed by the yay plugin {{kit.version}}. Don't edit this block; run /yay:harness-update. Project knowledge goes in the yay:project block below. -->
## How we work here

This repo uses the **yay** harness. Work through its skills so every developer and every Claude session follows the same flow:

| Step | Skill | Writes |
|---|---|---|
| Plan the horizon | `/yay:roadmap` | `docs/roadmap.md` (`R-<n>`) |
| Explore an idea | `/yay:brainstorm` | `docs/brainstorms/` (`BS-<n>`) |
| Decide the work | `/yay:plan` | `docs/plans/` (`P-<n>`) |
| Build it | `/yay:implement` | worktree, branch, commits, PR |
| Find a bug's cause | `/yay:debug` | `docs/bugs/` (`B-<n>`) |
| Fix a bug | `/yay:fix` | worktree, branch, commits, PR |
| Ship | `/yay:changelog` → `/yay:build` → `/yay:release` | readme.txt changelog, `docs/releases/`, zip, tag |
| Keep docs true | `/yay:knowledge-update` | this file's project block, `docs/knowledge/` |

- Each skill checks for the previous step's output and says when it's missing. You can still run any skill on its own.
- The repo's commands, editions, branches and generated paths are in `.yay/config.json`. Read them with `yayh config get <key>`; never guess a command.
- Get IDs and slugs from `yayh id next <R|BS|P|B|BL>` and `yayh slug "<text>"`.
- Git: branches are `<type>/<slug>`, commits are `type(scope): summary`, and you never commit to `{{git.baseBranch}}` directly. The full rules are in `.claude/rules/yay-git.md`.
- Never hand-edit generated paths: {{generatedPaths}}. A hook blocks it.
- Product PHP runs on PHP {{requires.php}}+. `.claude/rules/yay-wordpress.md` lists what that rules out.
<!-- yay:managed:end -->
