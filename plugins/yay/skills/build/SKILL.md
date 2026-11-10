---
name: build
description: Build and verify a Yay plugin's distributable zip for one or all editions - runs the repo's declared build and package commands, finds the zip, and checks it (single top folder, no dev files like .claude/.yay/CLAUDE.md/node_modules, no Pro code in Free/Lite zips, version headers and Stable tag match, PHP parses, repo-defined checks). Use before a release (/yay:release calls it), to hand a test build to QA or support, or when the user says "build the zip", "package it", "make a build", "check the zip".
argument-hint: "[--edition=<name>|all] [--version=x.y.z] [--no-build] [--no-checks] [--zip=<path>]"
allowed-tools: Bash, Read
---

# /yay:build

Arguments: `$ARGUMENTS`

Produce the zip a merchant would install, and prove it's clean. The commands come from `.yay/config.json` (`commands.build`, `commands.package`, `package.output`, `package.forbidden`, `checks`). Never improvise a different build.

## Options

| Option | Effect |
|---|---|
| `--edition=<e>\|all` | Which edition(s). Default `all` (`yayh config get editions`). |
| `--version=x.y.z` | The version the zip must carry. Default: `yayh version current`. |
| `--no-build` | Skip `commands.build` (assets already built), and only package and check. |
| `--no-checks` | Package without checking. Only for throwaway local builds; never for a release. |
| `--zip=<path>` | Only check an existing zip (with `--edition`, and `--version` if known). |

## Steps

1. **Preflight.**
   - Run `yayh version check`. The version files must agree. If they don't, stop and report the list. A release fixes it; a plain build doesn't paper over it.
   - Run `yayh config get commands.package` and `yayh config get package.output`. If either is missing, stop and say which config key to add, with a suggestion based on `scripts/`, `bin/` or the `package.json`/`composer.json` scripts.
   - Note `git status --porcelain`, so you can tell afterwards what the build changed.
2. **For each edition:**
   1. Unless `--no-build`, run `yayh run build edition=<e>`. If dependencies are missing, run `yayh run install` once.
   2. Run `yayh run package version=<v> edition=<e>`.
   3. Run `zip="$(yayh build zip edition=<e> version=<v>)"`. If it's empty, the package command didn't produce what `package.output` describes; report both.
   4. Unless `--no-checks`, run `yayh build check "$zip" edition=<e> version=<v>`.
3. **Clean up.** Compare `git status` with step 1. Some package scripts rewrite the version files or leave files behind:
   - If this isn't a release and tracked files changed, restore them (`git checkout -- <files>`) and say so.
   - Never commit from this skill.
4. **Report.** One table row per edition: the zip path, its size, PASS/WARN/FAIL counts, and the details of each FAIL and WARN.
   - Any FAIL means the build is **not shippable**. Say what to fix: a dev file means fixing the package script's excludes or `.distignore`; forbidden paths mean fixing the edition strip step; a version mismatch means running `/yay:release`, or fixing `versionFiles`.
   - WARN lines are judgment calls: silence a legitimate one with `package.allow` in `.yay/config.json`.

## Don'ts
- Don't hand-edit zip contents or "fix" a failing check by deleting files from the zip. Fix the build.
- Don't skip checks for anything that leaves the developer's machine.
