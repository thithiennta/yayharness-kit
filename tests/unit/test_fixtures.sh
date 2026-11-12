# fixture repos build and contain the legacy layouts init must handle

FIX="${KIT%/plugins/yay}/tests/fixtures/build.sh"

test_each_fixture_builds_with_tag_and_untracked_files() {
  local k d
  for k in legacy-rich legacy-notibar legacy-currency bare; do
    d="$T_TMP/$k"
    "$FIX" "$k" "$d" >/dev/null || { _fail "fixture $k did not build"; continue; }
    assert_eq "v1.2.3" "$(git -C "$d" describe --tags --abbrev=0)" "$k tag"
    assert_eq "dev" "$(git -C "$d" branch --show-current)" "$k branch"
    assert_file "$d/.claude/settings.local.json"
    assert_contains "$(git -C "$d" status --porcelain --ignored)" "CLAUDE.local.md"
  done
}

test_legacy_layouts() {
  "$FIX" legacy-rich "$T_TMP/r" >/dev/null
  "$FIX" legacy-currency "$T_TMP/c" >/dev/null
  "$FIX" legacy-notibar "$T_TMP/n" >/dev/null
  assert_file "$T_TMP/r/CLAUDE.md"; assert_file "$T_TMP/r/.claude/skills/yayplan/SKILL.md"; assert_file "$T_TMP/r/docs/decisions/0001-free-pro.md"
  assert_file "$T_TMP/c/.claude/CLAUDE.md"; assert_file "$T_TMP/c/.cursorrules"
  assert_file "$T_TMP/n/docs/journals/2026-10-01.md"; assert_file "$T_TMP/n/.claude/agent-memory/notes.md"
}
