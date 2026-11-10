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
| `commands.<name>` | string | Shell commands run from the repo root. Known names: `install`, `dev`, `build`, `lint`, `typecheck`, `test`, `package`. Placeholders: `{version}`, `{edition}`. A missing command means the step does not apply. |
| `package.output` | string | Glob for the built zip, e.g. `release/{slug}-{edition}-{version}.zip`. |
| `versionFiles[]` | object[] | `{ "file", "pattern" }`, where `pattern` is an extended regex whose first group is the version. Every match is bumped together. |
| `generatedPaths` | string[] | Paths never hand-edited (prefix match, trailing `/` for folders). The guard hook blocks edits to them. |
| `changelog.readme` | string | File holding `== Changelog ==`, usually `readme.txt`. |
| `changelog.notesDir` | string | Where customer-facing release notes go. Default `docs/releases`. |
| `checks[]` | string[] | Extra commands `/yay:build` runs on the packaged zip, with `{zip}` available. |
| `keep` | string[] | Paths `/yay:harness-init` must not wipe, e.g. user docs that live in `docs/`. |

## Reading it

- Skills: run `yayh config get <dotted.key> [default]` (the plugin `bin/` is on PATH). Arrays print one item per line, objects print as JSON.
- If the file is missing, run `/yay:harness-init` first. No skill except `harness-init` invents a config.
