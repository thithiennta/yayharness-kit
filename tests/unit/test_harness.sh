# detect, inventory, wipe, sync (per JSON engine: detect/sync use JSON heavily)

FIX="${KIT%/plugins/yay}/tests/fixtures/build.sh"

_fixture() { # kind -> path; leaves you on chore/yay-harness
  local d; d="$(fixture_repo "$1")" || return 1
  git -C "$d" switch -q -c chore/yay-harness
  printf '%s\n' "$d"
}

_init() { # path: wipe + detect + sync, like /yay:harness-init does
  YAY_REPO="$1" "$YAYH" harness wipe --yes >/dev/null
  mkdir -p "$1/.yay"
  YAY_REPO="$1" "$YAYH" harness detect 2>/dev/null > "$1/.yay/config.json"
  YAY_REPO="$1" "$YAYH" harness sync >/dev/null
}

test_detect_legacy_rich() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  local c="$T_TMP/c.json"; "$YAYH" harness detect 2>/dev/null > "$c"
  assert_eq "fixture-plugin" "$(jq -r .plugin.slug "$c")"
  mkdir -p "$YAY_REPO/.yay"; cp "$c" "$YAY_REPO/.yay/config.json"
  assert_eq "free
pro" "$("$YAYH" config get editions)"
  assert_eq "dev" "$("$YAYH" config get git.baseBranch)"
  assert_eq "pnpm install && composer install" "$("$YAYH" config get commands.install)"
  assert_eq "./scripts/run.sh build" "$("$YAYH" config get commands.build)"
  assert_contains "$("$YAYH" config get commands.package)" "--plan={edition}"
  assert_contains "$("$YAYH" config get generatedPaths)" "assets/dist/"
  assert_contains "$("$YAYH" config get versionFiles)" "FIXTURE_PLUGIN_VERSION"
  assert_ok "$YAYH" config validate
}

test_detect_bare_is_free_with_wporg_slug() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  mkdir -p "$YAY_REPO/.yay"; "$YAYH" harness detect 2>/dev/null > "$YAY_REPO/.yay/config.json"
  assert_eq "free" "$("$YAYH" config get editions)"
  assert_eq "fixture-plugin" "$("$YAYH" config get plugin.wporgSlug)"
  assert_ok "$YAYH" config validate
}

test_config_validate_catches_errors() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  mkdir -p "$YAY_REPO/.yay"
  echo '{"schemaVersion":1,"plugin":{"name":"X","slug":"Bad Slug","mainFile":"nope.php"},"editions":["free"],"git":{"baseBranch":"dev","tagFormat":"v"},"commands":{}}' > "$YAY_REPO/.yay/config.json"
  local err; err="$("$YAYH" config validate 2>&1)"
  assert_contains "$err" "kebab-case"; assert_contains "$err" "nope.php"; assert_contains "$err" "{version}"
}

test_inventory_lists_targets_keeps_and_untracked() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  local inv; inv="$("$YAYH" harness inventory)"
  assert_contains "$inv" "wipe	CLAUDE.md	1"
  assert_contains "$inv" "wipe	.claude/skills	2"
  assert_contains "$inv" "wipe	docs	5"
  assert_contains "$inv" "untracked	docs/untracked-notes.md"
  assert_contains "$inv" "keep	.claude/settings.local.json"
  assert_contains "$inv" "keep	CLAUDE.local.md"
}

test_inventory_currency_layout() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-currency)"
  local inv; inv="$("$YAYH" harness inventory)"
  assert_contains "$inv" "wipe	.claude/CLAUDE.md	1"
  assert_contains "$inv" "wipe	.claude/docs	1"
  assert_contains "$inv" "wipe	.cursorrules	1"
}

test_wipe_guards() {
  local r; r="$T_TMP/g"; "$FIX" legacy-rich "$r" >/dev/null
  export YAY_REPO="$r"
  assert_fails "$YAYH" harness wipe            # needs --yes
  assert_fails "$YAYH" harness wipe --yes      # on base branch dev
  git -C "$r" switch -q -c chore/x
  echo dirty >> "$r/readme.txt"
  assert_fails "$YAYH" harness wipe --yes      # dirty tree
}

test_wipe_removes_tracked_and_keeps_personal() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  "$YAYH" harness wipe --yes >/dev/null
  assert_no_file "$YAY_REPO/CLAUDE.md"; assert_no_file "$YAY_REPO/AGENTS.md"
  assert_no_file "$YAY_REPO/.claude/skills"; assert_no_file "$YAY_REPO/docs/decisions"
  assert_file "$YAY_REPO/.claude/settings.local.json"; assert_file "$YAY_REPO/.claude/worktrees/feature-x/README"
  assert_file "$YAY_REPO/CLAUDE.local.md"; assert_file "$YAY_REPO/docs/untracked-notes.md"
  assert_file "$YAY_REPO/includes/Plugin.php"
}

test_wipe_respects_keep() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  YAY_KEEP="docs/decisions" "$YAYH" harness wipe --yes >/dev/null
  assert_file "$YAY_REPO/docs/decisions/0001-free-pro.md"
  assert_no_file "$YAY_REPO/docs/architecture.md"
}

test_sync_installs_everything_then_is_idempotent() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  _init "$YAY_REPO"
  for f in CLAUDE.md .claude/rules/yay-git.md .claude/rules/yay-workflow.md .claude/rules/yay-wordpress.md \
           .claude/settings.json .github/pull_request_template.md docs/roadmap.md docs/plans/.gitkeep docs/bugs/.gitkeep; do
    assert_file "$YAY_REPO/$f"
  done
  assert_contains "$(cat "$YAY_REPO/CLAUDE.md")" "<!-- yay:managed:start v="
  assert_contains "$(cat "$YAY_REPO/CLAUDE.md")" "<!-- yay:project:start -->"
  assert_contains "$(cat "$YAY_REPO/.claude/rules/yay-git.md")" "Never commit to \`dev\` directly"
  assert_contains "$(cat "$YAY_REPO/.claude/rules/yay-wordpress.md")" "fixture-plugin"
  assert_ok "$YAYH" harness sync --check
  assert_eq "" "$("$YAYH" harness sync | grep -v up-to-date)"
  assert_eq "current $("$YAYH" version)" "$("$YAYH" harness status)"
}

test_sync_preserves_team_and_project_text_in_claude_md() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  sed -i.bak 's/_Project knowledge has not been written yet.*/Project facts here./' "$YAY_REPO/CLAUDE.md"
  printf '\nTeam footer.\n' >> "$YAY_REPO/CLAUDE.md"
  assert_ok "$YAYH" harness sync --check
  "$YAYH" harness sync --force >/dev/null
  assert_contains "$(cat "$YAY_REPO/CLAUDE.md")" "Project facts here."
  assert_contains "$(cat "$YAY_REPO/CLAUDE.md")" "Team footer."
}

test_sync_skips_hand_edits_unless_forced() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  echo "local tweak" >> "$YAY_REPO/.claude/rules/yay-git.md"
  assert_contains "$("$YAYH" harness sync)" "skipped-modified	.claude/rules/yay-git.md"
  assert_contains "$(cat "$YAY_REPO/.claude/rules/yay-git.md")" "local tweak"
  assert_exit 1 "$YAYH" harness sync --check
  assert_contains "$("$YAYH" harness sync --force)" "updated	.claude/rules/yay-git.md"
  assert_fails grep -q "local tweak" "$YAY_REPO/.claude/rules/yay-git.md"
}

test_sync_restores_deleted_kit_files() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  rm "$YAY_REPO/.github/pull_request_template.md"
  assert_contains "$("$YAYH" harness sync)" "created	.github/pull_request_template.md"
}

test_sync_does_not_reseed_workflow_files() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  echo "### R-1 Real item" >> "$YAY_REPO/docs/roadmap.md"
  "$YAYH" harness sync --force >/dev/null
  assert_contains "$(cat "$YAY_REPO/docs/roadmap.md")" "R-1 Real item"
}

test_sync_follows_config_changes() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  sed -i.bak 's/"baseBranch": "dev"/"baseBranch": "main"/' "$YAY_REPO/.yay/config.json"
  assert_contains "$("$YAYH" harness sync)" "updated	.claude/rules/yay-git.md"
  assert_contains "$(cat "$YAY_REPO/.claude/rules/yay-git.md")" "Never commit to \`main\` directly"
}

test_settings_extra_merges_and_keeps_kit_keys() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  echo '{"permissions":{"allow":["Bash(composer lint *)"]},"env":{"X":"1"}}' > "$YAY_REPO/.yay/settings.extra.json"
  "$YAYH" harness sync --only=settings >/dev/null
  local s; s="$(cat "$YAY_REPO/.claude/settings.json")"
  assert_contains "$s" "Bash(composer lint *)"
  assert_contains "$s" "Bash(yayh *)"
  assert_contains "$s" '"yay@yayharness": true'
  assert_contains "$s" '"X": "1"'
}

test_marketplace_source_override() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  YAY_MARKETPLACE_SOURCE='{"source":"directory","path":"/opt/yayharness"}' _init "$YAY_REPO"
  assert_contains "$(cat "$YAY_REPO/.claude/settings.json")" '/opt/yayharness'
}

test_sync_removes_files_the_kit_dropped() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  mkdir -p "$YAY_REPO/.claude/rules"; echo old > "$YAY_REPO/.claude/rules/yay-old.md"
  "$YAYH" manifest record .claude/rules/yay-old.md rules/yay-old.md
  assert_contains "$("$YAYH" harness sync)" "removed	.claude/rules/yay-old.md"
  assert_no_file "$YAY_REPO/.claude/rules/yay-old.md"
}

test_status_outdated() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  sed -i.bak 's/"kitVersion": *"[^"]*"/"kitVersion": "0.0.1"/' "$YAY_REPO/.yay/manifest.json"
  assert_contains "$("$YAYH" harness status)" "outdated 0.0.1 ->"
}

test_gitignore_lines_added_once_and_team_lines_kept() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  _init "$YAY_REPO"
  local g; g="$(cat "$YAY_REPO/.gitignore")"
  assert_contains "$g" "vendor/"; assert_contains "$g" ".claude/worktrees/"; assert_contains "$g" "CLAUDE.local.md"
  "$YAYH" harness sync >/dev/null
  assert_eq "1" "$(grep -c '^.claude/worktrees/$' "$YAY_REPO/.gitignore")"
  assert_eq "" "$(git -C "$YAY_REPO" status --porcelain --untracked-files=all | grep -E 'worktrees|settings.local|CLAUDE.local')"
}

test_harness_files_lists_only_kit_paths() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  _init "$YAY_REPO"
  local f; f="$("$YAYH" harness files)"
  assert_contains "$f" ".yay/config.json"; assert_contains "$f" "CLAUDE.md"; assert_contains "$f" "docs/plans/.gitkeep"
  assert_eq "" "$(printf '%s\n' "$f" | grep -E 'untracked-notes|settings.local|worktrees')"
  git -C "$YAY_REPO" add -u; git -C "$YAY_REPO" add -- $f
  assert_contains "$(git -C "$YAY_REPO" status --porcelain)" "?? docs/untracked-notes.md"
}

test_version_stamped_only_when_nothing_unresolved() {
  export YAY_REPO; YAY_REPO="$(_fixture bare)"
  _init "$YAY_REPO"
  sed -i.bak 's/"kitVersion": *"[^"]*"/"kitVersion": "0.0.9"/' "$YAY_REPO/.yay/manifest.json"
  echo "tweak" >> "$YAY_REPO/.claude/rules/yay-git.md"
  "$YAYH" harness sync >/dev/null
  assert_contains "$("$YAYH" harness status)" "outdated 0.0.9"
  assert_exit 1 "$YAYH" harness sync --check
  "$YAYH" harness sync --only=rules --force >/dev/null
  assert_contains "$("$YAYH" harness status)" "outdated 0.0.9"   # --only never stamps
  "$YAYH" harness sync >/dev/null
  assert_eq "current $("$YAYH" version)" "$("$YAYH" harness status)"
  assert_ok "$YAYH" harness sync --check
}

test_keep_option_on_inventory_and_wipe() {
  export YAY_REPO; YAY_REPO="$(_fixture legacy-rich)"
  assert_contains "$("$YAYH" harness inventory --keep=docs/backlog)" "keep	docs/backlog/idea.md"
  "$YAYH" harness wipe --yes --keep=docs/backlog >/dev/null
  assert_file "$YAY_REPO/docs/backlog/idea.md"
  assert_no_file "$YAY_REPO/docs/plans/old-plan.md"
}
