# wporg: precheck.py's checklist IDs and the WordPress.org site checks

_precheck_findings() { # dir -> "<id> <check> <file>:<line>" per finding
  python3 -I "$KIT/skills/wporg/scripts/precheck.py" "$1" --slug wporg-planted --wp-version 6.9 --json \
    | python3 -I -c 'import json,sys
for f in json.load(sys.stdin)["findings"]:
    print("%s %s %s:%s" % (f["id"], f["check"], f["file"], f["line"]))'
}

test_precheck_new_checks() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  local fx="$ROOT/tests/fixtures/wporg/planted" out
  out="$(_precheck_findings "$fx")"
  assert_contains "$out" "Q9 post_type_key_length includes/planted.php:7"
  assert_contains "$out" "Q3 admin_body_class includes/planted.php:14"
  assert_contains "$out" "Q3 enqueue_scope includes/planted.php:16"
  assert_contains "$out" "S11 inline_script_json_hex includes/planted.php:19"
  assert_contains "$out" "Q13 product_query_visibility includes/planted.php:24"
  assert_not_contains "$out" "includes/clean.php" "the clean file stays quiet"
  # the text report names the ID next to the check
  assert_contains "$(python3 -I "$KIT/skills/wporg/scripts/precheck.py" "$fx" --slug wporg-planted --wp-version 6.9)" "## [ERROR] Q9 post_type_key_length (1)"
}

test_wporg_site_skips_without_e2e() {
  export YAY_REPO; YAY_REPO="$(fixture_repo legacy-rich configured)"
  local stage="$T_TMP/wstage.$RANDOM" z out rc o="$T_TMP/wout.$RANDOM"
  mkdir -p "$stage/fixture-plugin"; cp "$YAY_REPO/fixture-plugin.php" "$YAY_REPO/readme.txt" "$stage/fixture-plugin/"
  z="$T_TMP/fixture-plugin.$RANDOM.zip"; (cd "$stage" && zip -qr "$z" fixture-plugin)
  out="$("$YAYH" wporg site "$z" out="$o")"; rc=$?
  assert_eq 3 "$rc" "exit without e2e setup"
  assert_eq "SKIP	site	no e2e setup with wp-env installed (run /yay:e2e-init, then yayh run e2e-install)" "$out"
  assert_eq "$out" "$(cat "$o/site.tsv")" "site.tsv holds the same line"
  # e2e set up, Docker installed but not running
  local p; p="$(_ui_no_docker "$YAY_REPO")"
  out="$(PATH="$p" "$YAYH" wporg site "$z" out="$o")"; rc=$?
  assert_eq 3 "$rc" "exit without Docker"
  assert_eq "SKIP	site	Docker is not running" "$out"
  assert_no_file "$(git -C "$YAY_REPO" rev-parse --absolute-git-dir)/yay-release-site"
  assert_exit 1 "$YAYH" wporg site "$z"
}
