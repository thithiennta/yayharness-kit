# engine-independent
# slug, version, sha256, CLI dispatch

test_slug_basic() {
  assert_eq "coupon-field-disappears" "$("$YAYH" slug "Coupon Field — disappears!!")"
  assert_eq "a-b" "$("$YAYH" slug "  --A   b--  ")"
}

test_slug_truncates_to_50_without_trailing_dash() {
  local s; s="$("$YAYH" slug "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbb")"
  assert_eq "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$s"
}

test_version_matches_plugin_json() {
  local want; want="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$KIT/.claude-plugin/plugin.json")"
  assert_eq "$want" "$("$YAYH" version)"
}

test_unknown_command_exits_2() {
  assert_exit 2 "$YAYH" nope
}

test_help_lists_every_group() {
  local h; h="$("$YAYH" help)"
  for g in config slug "id next" "fm get" "manifest status" "git worktree"; do assert_contains "$h" "$g"; done
}
