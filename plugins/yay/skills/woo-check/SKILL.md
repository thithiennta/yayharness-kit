---
name: woo-check
description: Run WooCommerce's QIT-style quality checks locally on a Yay plugin's built zip - security (PHPCS security sniffs, composer and npm audit, gitleaks), PHPStan with the WooCommerce stubs, PHP compatibility, malware patterns and the WooCommerce headers and HPOS / block-checkout declarations - with no WooCommerce.com account. Writes a technical report with an ID, file:line and fix on every finding, a plain summary to share through /yay:report, and fixes on a branch. Use when the user says "QIT", "woo check", "Woo compatibility", "security scan", "PHPStan", "is it ready for the Woo release", "kiểm tra Woo".
argument-hint: "[--zip=<path>] [--edition=<e>] [--only=sec,stan,cmp,mal,val] [--report-only] [--update-baseline]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent, AskUserQuestion, Artifact
---

# /yay:woo-check

Arguments: `$ARGUMENTS`

Run what WooCommerce's QIT runs before a Marketplace release, on this machine, on **the zip the repo really builds**. No Yay plugin is on the Woo Marketplace, so QIT itself isn't available; the checks are the same open tools, pinned by the kit. Five areas, each Success, Warning, Failed or Skipped:
- **SEC** security: PHPCS `WordPress.Security` and `WordPress.DB`, `composer audit`, `npm audit` or `pnpm audit`, gitleaks
- **MAL** malware: dangerous functions, obfuscation, hidden or disguised files, non-printable characters
- **STAN** PHPStan with the WordPress and WooCommerce stubs (`wooCheck.phpstanLevel`, default 2)
- **CMP** PHP compatibility from `Requires PHP` up
- **VAL** `WC requires at least` / `WC tested up to`, HPOS and block-checkout declarations

Only a Failed **SEC** or **MAL** blocks `/yay:release --woo-check`. Every ID, its severity and its fix: `references/checklist.md`. The report's shape: `references/report-template.md`. Questions: `${CLAUDE_PLUGIN_ROOT}/reference/asking.md`. Git rules: `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Options

| Option | Effect |
|---|---|
| `--zip=<path>` | Check this zip instead of building one (one edition). |
| `--edition=<e>` | Only this edition. Default: every edition in `editions`, one report each. |
| `--only=<areas>` | Some areas only, e.g. `--only=sec,mal`. |
| `--report-only` | Stop after the reports: no fix offer. `/yay:release --woo-check` passes it. |
| `--update-baseline` | Accept today's findings as the baseline, on a branch (see **Baseline**). |

## 1. What ships

- `yayh config get requires.wc` fails or is empty: stop. This isn't a WooCommerce extension (`requires.wc` is null); `/yay:wporg` is the WordPress.org review.
- `v="$(yayh version current)"`, or with `--zip` the `Version:` in the zip's main file. Note `git status --porcelain`: the check leaves the working tree as it found it.
- Per edition, the folder for what this run writes: `dir="$(yayh config get release.bundleDir release/bundles)/$(yayh config get plugin.slug)-woo-check-$v"`, plus `/<edition>` when there is more than one edition. `mkdir -p "$dir"`. It's gitignored and outside the zip.
- **The zip**, exactly as `/yay:wporg` step 1: `--zip=<path>`, or `yayh run build edition=<e>` (when `commands.build` is set), `yayh run package version=$v edition=<e>`, then `zip="$(yayh build zip edition=<e> version=$v)"`. Then `yayh build check "$zip" edition=<e> version=$v`. A FAIL stops the check: the zip isn't what ships, so say what to fix in the build. No `commands.package`: check the repo folder itself and say "Checked: repo source, not built" in the report.

## 2. Run the checks

1. **Tools.** `yayh woo-check tools`. Any `missing`: say "Installing the pinned PHPCS, PHPStan and gitleaks into the kit cache (first run only)" and run `yayh woo-check tools --install`. If it fails (offline, no `php` or `composer`), carry on: those areas come back SKIP and the report says so. Never call an area clean that didn't run.
2. **Baseline first?** With `/yay:release --woo-check` and no `.yay/woo-check-baseline.tsv`: stop before running and say to run `/yay:woo-check --update-baseline` on a branch first, so a release is never the first look at years of findings.
3. **Static run.** `yayh woo-check static "$zip" out="$dir" [--only=<areas>]` (run from the repo root, so the audits read its lock files). Exit 1 means SEC or MAL is Failed, 3 means nothing ran: neither stops the skill. It writes `findings.tsv` (`result id file line code message`), `areas.tsv`, `gone.tsv` (baseline rows no longer found) and `raw/` (each tool's own output).

## 3. Read before you report

Every `FAIL` and `WARN` row (not `BASE`) gets read at its line in `$dir/src/…` before it goes in the report:
- Confirm it. Heuristic rows (MAL, VAL) can be wrong: drop a false one, and count it under Not checked. A SEC5 row is never dropped without opening the line; never print the secret itself.
- Trace it to the source file the author edits: a built or minified file maps to its source, a vendor file to its package. The report gives the source path.
- STAN1 rows about classes, traits or functions of other plugins the code integrates with (YayMail, Elementor, Divi…) are expected without their code: group them in the report as one line per plugin, and suggest the baseline.
- Order a large run: SEC, then MAL, then the rest. More than 50 rows of one ID and code: read 10, sample the others, and say so.

## 4. Report

- Write `$dir/report.md` exactly as `references/report-template.md` says: the verdict, the area table, then every non-baseline finding with ID, `file:line`, what's wrong and the fix (the code fix itself for SEC), Not checked, Baseline (counts, and the `gone.tsv` rows).
- **Plain summary.** Run `/yay:report check --from="$dir"` in the repo's `language` (`yayh config get language en`). It goes through `/yay:report`'s own check, cold reader, page and Artifact, so it reads like every other Yay report: what each problem lets someone do to the store, blockers first, IDs and paths only under For developers. With several editions, one summary covers them all. Keep its link and its paste-ready text for the wrap-up.
- In the reply: the area table per edition, the blockers with their fix, the count of other findings by area, then the summary's link and the path to `report.md`.
- Check `git status --porcelain` against step 1. If the build rewrote tracked files, restore them (`git checkout -- <files>`) and say so.

## 5. Fixes

Skip with `--report-only`. Otherwise ask once (AskUserQuestion): fix everything, only SEC and MAL, or chosen IDs. In the same round, ask the decisions that change behaviour instead of choosing them:
- a SEC3/SEC4 dependency with no patched version: replace it, or accept the risk
- declaring HPOS or block-checkout compatibility (VAL3, VAL4): only after it has been tested with them on
- raising `Requires PHP` instead of rewriting code for CMP1

Fix on a branch, never in the zip: `branch="fix/woo-check-<n>"` (`<n>` one past the highest existing `fix/woo-check-*`), `wt="$(yayh git worktree "$branch" <base>)"`, and work only there.
- **One commit per ID**, every occurrence fixed: `fix(<scope>): <ID> <what>`, e.g. `fix(security): SEC2 prepare the rate delete query`. Follow the codebase's style. Don't edit vendor code: update or replace the package.
- Rebuild, re-run `build check` and `yayh woo-check static` on the new zip; nothing you fixed may come back.
- Push and open the PR as `/yay:fix` does (assigned to you), listing each ID fixed and each decision taken.

## Baseline (`--update-baseline`)

`.yay/woo-check-baseline.tsv` is committed, so the whole team sees the same "new findings". Run steps 1–3, then on a `chore/woo-check-baseline-<n>` branch (as in step 5): `yayh woo-check baseline "$dir" --update`, commit it as `chore(woo-check): baseline <version>`, and open the PR so the diff is reviewed. `KEPT` lines are SEC5 and MAL2 rows: they are never baselined, so say they still need a fix or an allow comment next to the line (`gitleaks:allow`, `woo-check:allow MAL2`). Baselined SEC rows stay counted in every report.

## 6. Wrap up

Report the verdict per edition, the blockers, the counts, what didn't run, the summary's link and paste-ready text, the report folder, and the fix branch and PR when there is one. End with the **Next** line (`reference/asking.md`): the PR's review after fixes; `/yay:woo-check --update-baseline` when there is no baseline yet; `/yay:release --bundle --woo-check` once nothing blocks.

## Don'ts
- Don't check the repo when a package command exists: what ships is the zip.
- Don't edit the zip, the user's working tree or the base branch. Fixes and baselines go through a branch.
- Don't install tools into the plugin (`composer require`, `npm install`); they live in the kit cache.
- Don't call an area Success that was Skipped, and don't report a row you didn't read.
- Don't baseline to make a release pass: the baseline is reviewed in its own PR.
