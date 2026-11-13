# wporg: precheck.py's checklist IDs and the WordPress.org site checks

_precheck_findings() { # dir -> "<id> <check> <file>:<line>" per finding
  python3 -I "$KIT/skills/wporg/scripts/precheck.py" "$1" --slug wporg-planted --wp-version 6.9 --json \
    | python3 -I -c 'import json,sys
for f in json.load(sys.stdin)["findings"]:
    print("%s %s %s:%s" % (f["id"], f["check"], f["file"], f["line"]))'
}

test_precheck_new_checks() { # P-1
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
