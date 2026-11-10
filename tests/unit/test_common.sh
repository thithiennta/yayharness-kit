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

# Under `set -o pipefail`, `producer | head` and `producer | grep -q` can fail
# the whole pipeline when the consumer exits early (SIGPIPE) - this bit the kit
# four times. Use `sed -n '1,Np'` and yay_in_list / case instead.
test_no_early_exit_consumers_in_pipes() {
  local hits
  hits="$(grep -nE '(^|[^|])\|[[:space:]]*head([[:space:]]|$)' "$KIT"/lib/*.sh "$KIT"/hooks/*.sh "$KIT"/bin/yayh || true)"
  assert_eq "" "$hits" "pipes into head"
  hits="$(grep -nE '(^|[^|])\|[[:space:]]*grep[[:space:]]+-[a-zA-Z]*q' "$KIT"/lib/*.sh "$KIT"/hooks/*.sh "$KIT"/bin/yayh | grep -v "printf '%s'" | grep -v "printf ' %s" | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
  assert_eq "" "$hits" "pipes into grep -q (single printf producers are safe)"
}
