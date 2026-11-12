# `.yay/config.json`: the repo's declaration

Every `/yay:*` skill reads this file. It is the only place a repo says how it builds, tests and ships. `/yay:harness-init` writes it, and the team edits it by hand afterwards. The kit never overwrites it, though `/yay:harness-update` may add new keys with their defaults. Schema: `config.schema.json`.

JSON, not YAML, so hooks can read it with `jq`, `node` or `php` and nothing to install.

## Keys

| Key | Type | Meaning |
|---|---|---|
| `schemaVersion` | int | Config format version. Currently `1`. |
| `plugin.name` | string | Display name, e.g. `YayCheckout`. |
| `plugin.slug` | string | Folder and zip slug, e.g. `yaycheckout`. |
| `plugin.mainFile` | string | The PHP file with the plugin header. |
| `plugin.textDomain` | string | i18n text domain. |
| `plugin.wporgSlug` | string \| null | WordPress.org slug when a Free build ships there. |
| `editions` | string[] | Builds from this branch, e.g. `["free","pro"]` or `["free"]`. The first is the default. |
| `requires.php` | string | Minimum PHP for product code, e.g. `7.4`. Rules and review enforce it. |
| `requires.wp` / `requires.wc` | string | Minimum WP / WooCommerce (`wc` null when not a Woo extension). |
| `tested.wp` / `tested.wc` | string | Current "tested up to" values. `/yay:release` updates them. |
| `git.baseBranch` | string | Branch features merge into, e.g. `dev` or `main`. |
| `git.tagFormat` | string | Tag template. `{version}` is replaced, e.g. `v{version}`. |
| `git.branchTypes` | string[] | Allowed branch prefixes. Default `["feat","fix","chore","hotfix","docs","refactor","test"]`. |
| `git.scopes` | string[] | Optional allowed commit scopes. Empty means any scope is allowed. |
| `git.mergeMethod` | string | How PRs merge: `merge` (a merge commit, the default), `squash` or `rebase`. It's the flag for `gh pr merge --<method>`. |
| `commands.<name>` | string | Shell commands run from the repo root. Known names: `install`, `dev`, `build`, `lint`, `typecheck`, `test`, `package`, and the e2e set `e2e` (runs Playwright; `yayh e2e run` appends its arguments), `e2e-install`, `e2e-start`, `e2e-stop`, `e2e-reset`, and the test layers `test-unit`, `test-integration` (runs in wp-env's `tests-cli`), `test-js` (`yayh test run <layer>` appends its arguments; `test` stays the fast default: unit + js). Placeholders: `{version}`, `{edition}`. A missing command means the step does not apply. |
| `package.output` | string \| object | Glob for the built zip, e.g. `release/{slug}-{edition}-{version}.zip`. When editions name their zips differently, use a map: `{"pro": "release/{slug}-{version}.zip", "lite": "release/{slug}-lite-{version}.zip"}`. |
| `package.forbidden` | object | Map from edition to paths that must not appear in that edition's zip, e.g. `{"free": ["includes/Pro/"]}`. `yayh build check` (run by `/yay:release`) fails the zip when they do. |
| `package.allow` | string[] | Globs, relative to the zip's top folder, that are exempt from the "usually not shipped" warnings (e.g. `composer.json` when it's needed at runtime). |
| `versionFiles[]` | object[] | `{ "file", "pattern" }`, where `pattern` is an extended regex whose first group is the version. Every match is bumped together. |
| `generatedPaths` | string[] | Paths never hand-edited (prefix match, trailing `/` for folders). The guard hook blocks edits to them. |
| `changelog.readme` | string | File holding `== Changelog ==`, usually `readme.txt`. |
| `changelog.notesDir` | string | Where customer-facing release notes go. Default `docs/releases`. |
| `checks[]` | string[] | Extra commands `yayh build check` runs on the packaged zip, with `{zip}` available. |
| `release.bundleDir` | string | Where `/yay:release` puts bundles. Default `release/bundles` (keep it gitignored). |
| `release.stableTag` | `version` \| `trunk` | `version` (default): the readme's Stable tag must equal the release. `trunk`: it stays `trunk`. |
| `release.sizeChangePct` / `release.sizeChangeKb` / `release.largeFileKb` | number | When `yayh release size` calls a zip UNUSUAL, so a release asks: the size or file count moved more than 25% or 1024 KB against the last release, or a file is over 2048 KB. |
| `release.uiPort` | int | Port of the UI check's own wp-env site. Default: the e2e base port + 4. |
| `site.wpPath` | string | Per developer, so put it in `.yay/local.json`, never in the shared config. It's the WordPress root of the local site; `/yay:debug` uses it for WP-CLI and logs. When the repo sits in `<wp>/wp-content/plugins/` it's derived automatically, and worktrees work too. |
| `site.url` | string | Per developer. The local site's URL, for repro steps. |
| `site.debugLog` | string | Per developer. Defaults to `<wpPath>/wp-content/debug.log`. |
| `e2e.dir` | string | The e2e package folder. Default `tests/e2e`. See `e2e.md`. |
| `e2e.port` | int | The main checkout's wp-env port. Default: 8900–9890, derived from `plugin.slug`. Worktrees always get their own port. |
| `e2e.baseUrl` | string | Per developer (`.yay/local.json`). Run specs against an external site instead of wp-env; yayh then manages nothing. |
| `tests.php` | string | PHP tests folder (`unit/`, `integration/`, their `*.xml.dist`). Default `tests/php`. See `testing.md`. |
| `tests.js` | string | JS tests folder. Default `tests/js`. |
| `tests.jsRunner` | string | `vitest`, `jest`, `wp-scripts` or `none`. Default: what `package.json` uses. |
| `e2e.wpEnvArgs` | string | Extra wp-env arguments for `yayh e2e cli`, e.g. `--config=.wp-env.single.json` in adopted setups. |
| `workflow.strictness` | string | Optional. `relaxed`, `standard` (default) or `strict`. **relaxed:** `plan check` skips the Reuse, Tests and E2E checks for every plan. **strict:** every plan is held to the standard checks (no small plans), `/yay:implement` has no tiny lane and asks before any change to the plan, and commit-style problems (length, period, scope, branch name) block again. Safety blocks are the same in every mode. A developer may set it in `.yay/local.json` for themselves. |
| `trello.board` | string | Optional. The Trello board (URL or ARI) that `/yay:roadmap --trello` and `/yay:plan --trello` sync to. Shared in this file, or per developer in `.yay/local.json`. See `trello.md`. |
| `trello.list` | string | Optional. The list for plan cards whose roadmap item has no card. Default `To Do`. |
| `models.steps.<step>` | string or object | Optional. The tier (`veryfast`, `fast`, `balanced`, `deep`), `inherit` (the session's model), or `{ "model", "effort" }` for one agent step. Unset steps use the defaults in `models.md`; anything unknown runs on `balanced` (Opus medium). |
| `models.tiers.<tier>` | object | Optional. Override or add a tier: `{ "model": "sonnet"|"opus", "effort": "low"…"max" }`. |
| `models.sizeBump` | object | Optional. Tier shift per roadmap size for sized steps. Default `{ "S": -1, "M": 0, "L": 1 }`. |
| `keep` | string[] | Paths `/yay:harness-init` must not wipe, e.g. user docs that live in `docs/`. |

## Per-developer overrides: `.yay/local.json`

It's gitignored, has the same shape as the shared config, and any key in it wins. Use it for machine-specific values (`site.*`), never for team conventions.

## Reading it

- Skills: run `yayh config get <dotted.key> [default]` (the plugin `bin/` is on PATH). Arrays print one item per line, objects print as JSON.
- If the file is missing, run `/yay:harness-init` first. No skill except `harness-init` invents a config.
