# tests: PHP unit / integration and JS layers: scaffold (fill-in-the-gaps), detect, list by ID, run

_testrepo() { # [wc] [pkg=<package.json body>] -> a harnessed repo
  local r wc='null' pkg=""; r="$(mk_repo)"
  for a in "$@"; do case "$a" in wc) wc='"8.0"' ;; pkg=*) pkg="${a#pkg=}" ;; esac; done
  mkdir -p "$r/.yay"
  printf '<?php\n/**\n * Plugin Name: Giftly\n */\n' > "$r/giftly.php"
  printf '{"schemaVersion":1,"plugin":{"name":"Giftly","slug":"giftly","mainFile":"giftly.php"},"editions":["free"],"requires":{"wc":%s},"git":{"baseBranch":"main"},"commands":{"install":"composer install","build":"npm run build","test-js":"echo custom js"}}\n' "$wc" > "$r/.yay/config.json"
  [ -z "$pkg" ] || printf '%s\n' "$pkg" > "$r/package.json"
  commit_all "$r"
  printf '%s\n' "$r"
}

test_scaffold_woo_with_integration_and_vitest() {
  export YAY_REPO; YAY_REPO="$(_testrepo wc 'pkg={"devDependencies":{"vite":"5"}}')"
  local out; out="$("$YAYH" test scaffold)"
  assert_contains "$out" "created	tests/php/unit/TestCase.php"
  assert_contains "$out" "created	tests/php/integration/bootstrap.php"
  assert_contains "$out" "created	tests/js/vitest.config.mjs"
  assert_contains "$out" "created	.github/workflows/tests.yml"
  assert_contains "$out" "created	tests/e2e/.wp-env.json"
  assert_contains "$out" "updated	tests/e2e/.wp-env.json	testsEnvironment: true"
  assert_contains "$out" "deps	composer	composer require --dev --no-interaction -W phpunit/phpunit:^9.6 yoast/phpunit-polyfills:^2.0 brain/monkey:^2.6"
  assert_contains "$out" "deps	npm	npm install --save-dev vitest"
  assert_contains "$(cat "$YAY_REPO/tests/e2e/.wp-env.json")" '"testsEnvironment": true'
  assert_eq "vendor/bin/phpunit -c tests/php/unit.xml.dist" "$("$YAYH" config get commands.test-unit)"
  assert_eq "cd tests/e2e && ./node_modules/.bin/wp-env run tests-cli --env-cwd=wp-content/plugins/giftly vendor/bin/phpunit -c tests/php/integration.xml.dist" "$("$YAYH" config get commands.test-integration)"
  assert_eq "echo custom js" "$("$YAYH" config get commands.test-js)" "existing command kept"
  assert_eq "vendor/bin/phpunit -c tests/php/unit.xml.dist && ./node_modules/.bin/vitest run --config tests/js/vitest.config.mjs" "$("$YAYH" config get commands.test)"
  assert_eq "vitest" "$("$YAYH" config get tests.jsRunner)"
  assert_contains "$(cat "$YAY_REPO/tests/php/unit/bootstrap.php")" "dirname( __DIR__, 3 )"
  assert_contains "$(cat "$YAY_REPO/tests/php/integration/bootstrap.php")" "woocommerce/woocommerce.php"
  assert_contains "$(cat "$YAY_REPO/tests/php/integration/bootstrap.php")" "require_once \$yay_tests_root . '/giftly.php';"
  assert_contains "$(cat "$YAY_REPO/tests/php/integration/PluginLoadsTest.php")" "WC_Product_Simple"
  assert_contains "$(cat "$YAY_REPO/tests/php/unit/PluginHeaderTest.php")" "preg_quote( 'Giftly'"
  assert_contains "$(cat "$YAY_REPO/tests/js/vitest.config.mjs")" "new URL( '../../', import.meta.url )"
  assert_contains "$(cat "$YAY_REPO/.github/workflows/tests.yml")" "integration:"
  assert_contains "$(cat "$YAY_REPO/.github/workflows/tests.yml")" "run: composer install && npm run build"
  assert_eq "" "$(grep -rn '{{[a-z]' "$YAY_REPO/tests/php" "$YAY_REPO/tests/js" "$YAY_REPO/.github/workflows/tests.yml" || true)" "no placeholders left"
  assert_eq "" "$(grep -rn '#if-\|#end-' "$YAY_REPO/tests/php" "$YAY_REPO/.github/workflows/tests.yml" || true)" "no condition markers left"
  # a second run changes nothing
  echo "// hand edit" >> "$YAY_REPO/tests/php/unit/TestCase.php"
  out="$("$YAYH" test scaffold)"
  assert_eq "" "$(printf '%s\n' "$out" | grep -v '^exists' | grep -v '^deps' || true)" "second run only reports exists"
  assert_contains "$(cat "$YAY_REPO/tests/php/unit/TestCase.php")" "// hand edit"
}

test_scaffold_plain_wp_without_integration_or_js() {
  export YAY_REPO; YAY_REPO="$(_testrepo)"
  printf '{"require-dev":{"phpunit/phpunit":"^9.6","brain/monkey":"^2.6","yoast/phpunit-polyfills":"^2.0"}}\n' > "$YAY_REPO/composer.json"
  local out; out="$("$YAYH" test scaffold php=tests/unit-php --no-integration --no-ci)"
  assert_no_file "$YAY_REPO/tests/unit-php/integration.xml.dist"
  assert_no_file "$YAY_REPO/tests/e2e"
  assert_no_file "$YAY_REPO/.github/workflows/tests.yml"
  assert_file "$YAY_REPO/tests/unit-php/unit/TestCase.php"
  assert_eq "" "$(printf '%s\n' "$out" | grep '^deps' || true)" "no deps when composer already declares them"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'commands.test-integration' || true)"
  assert_eq "none" "$("$YAYH" config get tests.jsRunner)" "no package.json: no JS layer"
  assert_eq "vendor/bin/phpunit -c tests/unit-php/unit.xml.dist" "$("$YAYH" config get commands.test)"
  assert_fails "$YAYH" test scaffold php=../out
  assert_fails "$YAYH" test scaffold js-runner=mocha
}

test_scaffold_keeps_the_repo_runner_and_e2e_package() {
  export YAY_REPO; YAY_REPO="$(_testrepo wc 'pkg={"devDependencies":{"@wordpress/scripts":"27"}}')"
  "$YAYH" e2e scaffold --no-ci >/dev/null
  local out; out="$("$YAYH" test scaffold --no-ci)"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'created	tests/e2e' || true)" "existing e2e package reused"
  assert_contains "$out" "updated	tests/e2e/.wp-env.json"
  assert_no_file "$YAY_REPO/tests/js/vitest.config.mjs"
  assert_eq "wp-scripts" "$("$YAYH" config get tests.jsRunner)"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'deps	npm' || true)" "wp-scripts already declared"
}

test_detect_existing_test_setup() {
  export YAY_REPO; YAY_REPO="$(_testrepo 'pkg={"scripts":{"test:unit":"jest src","test:e2e":"playwright test"},"devDependencies":{"jest":"29"}}')"
  mkdir -p "$YAY_REPO/tests/phpunit/Rules" "$YAY_REPO/src/__tests__" "$YAY_REPO/.github/workflows"
  printf '<?xml version="1.0"?>\n<phpunit bootstrap="tests/phpunit/bootstrap.php"></phpunit>\n' > "$YAY_REPO/phpunit.xml.dist"
  : > "$YAY_REPO/tests/phpunit/Rules/TierTest.php"; : > "$YAY_REPO/tests/phpunit/Rules/CapTest.php"
  : > "$YAY_REPO/src/__tests__/store.test.js"
  printf '{"require-dev":{"10up/wp_mock":"1"},"scripts":{"test":"phpunit"}}\n' > "$YAY_REPO/composer.json"
  printf 'jobs:\n  t:\n    run: vendor/bin/phpunit\n' > "$YAY_REPO/.github/workflows/ci.yml"
  local out; out="$("$YAYH" test detect)"
  assert_contains "$out" "phpunit	phpunit.xml.dist	bootstrap=tests/phpunit/bootstrap.php"
  assert_contains "$out" "composer-dev	composer.json	10up/wp_mock"
  assert_contains "$out" "script	composer.json	test: phpunit"
  assert_contains "$out" "php-tests	tests/phpunit/Rules	2 files"
  assert_contains "$out" "js-runner	package.json	jest"
  assert_contains "$out" "script	package.json	test:unit: jest src"
  assert_contains "$out" "js-tests	.	1 files"
  assert_contains "$out" "ci	.github/workflows/ci.yml"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'playwright' || true)" "e2e scripts left to yayh e2e detect"
}

test_list_and_run_by_id() {
  export YAY_REPO; YAY_REPO="$(_testrepo)"
  mkdir -p "$YAY_REPO/tests/php/unit/Rules" "$YAY_REPO/tests/js"
  printf '<?php\n/**\n * @group P-1\n */\nclass TierTest {\n  public function test_a() {}\n  public function test_b() {}\n}\n' > "$YAY_REPO/tests/php/unit/Rules/TierTest.php"
  printf '<?php\n/** @group P-12 */\nclass CapTest { public function test_c() {} }\n' > "$YAY_REPO/tests/php/unit/CapTest.php"
  printf "describe( 'tiers @P-1', () => {\n  it( 'x', () => {} );\n} );\n" > "$YAY_REPO/tests/js/tiers.test.js"
  printf '{"commands":{"test-unit":"echo unit:","test-js":"echo js:"}}\n' > "$YAY_REPO/.yay/local.json"
  assert_contains "$("$YAYH" test list)" "unit	2	tests/php/unit/Rules/TierTest.php"
  assert_contains "$("$YAYH" test list)" "js	1	tests/js/tiers.test.js"
  local l; l="$("$YAYH" test list P-1)"
  assert_contains "$l" "unit	tests/php/unit/Rules/TierTest.php:3: * @group P-1"
  assert_contains "$l" "js	tests/js/tiers.test.js:1:"
  assert_eq "" "$(printf '%s\n' "$l" | grep CapTest || true)" "P-1 never matches P-12"
  assert_eq "unit: --group P-1" "$("$YAYH" test run unit --id=P-1 2>/dev/null)"
  assert_eq "js: -t @P-1" "$("$YAYH" test run js --id=P-1 2>/dev/null)"
  assert_eq "unit: --filter test_a" "$("$YAYH" test run unit --filter test_a 2>/dev/null)"
  assert_contains "$("$YAYH" test run unit --id=P-9 2>&1)" "no unit tests tagged P-9"
  local all; all="$("$YAYH" test run all --id=P-1 2>/dev/null)"
  assert_contains "$all" "unit	passed"
  assert_contains "$all" "js	passed"
  printf '{"commands":{"test-unit":"exit 1","test-js":"true"}}\n' > "$YAY_REPO/.yay/local.json"
  assert_fails "$YAYH" test run all
  assert_fails "$YAYH" test run integration
}

test_integration_needs_its_tests_site() {
  export YAY_REPO; YAY_REPO="$(_testrepo)"
  local port=$((20000 + RANDOM % 20000))
  printf '{"commands":{"test-unit":"true","test-integration":"echo port=$WP_ENV_TESTS_PORT args:"},"e2e":{"port":%s}}\n' "$port" > "$YAY_REPO/.yay/local.json"
  assert_exit 3 "$YAYH" test run integration
  local all; all="$("$YAYH" test run all 2>/dev/null)"
  assert_contains "$all" "integration	skipped	tests site down"
  assert_contains "$("$YAYH" test status)" "integration	yes	site down http://localhost:$((port + 1))"
  ( cd "$T_TMP" && exec python3 -I -m http.server "$((port + 1))" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  local pid=$! i=0
  while ! curl -s -o /dev/null "http://127.0.0.1:$((port + 1))/" && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  local out; out="$("$YAYH" test run integration --filter x 2>/dev/null)"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  assert_eq "port=$((port + 1)) args: --filter x" "$out"
}

test_plan_check_warns_on_tests_without_a_layer() {
  export YAY_REPO; YAY_REPO="$(_testrepo)"
  local plan; plan="$("$YAYH" artifact new plan "Gift tiers")"
  assert_eq "" "$("$YAYH" plan check "$plan" 2>&1 | grep 'has no layer' || true)" "none is fine"
  python3 -I - "$YAY_REPO/$plan" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("**Tests:** none\n","**Tests:** [unit] test_rounds (tests/php/unit/TierTest.php) — wrong totals; test_saves_option — lost setting; [js] formats — label\n",1)
open(p,"w").write(s)
PY
  local out; out="$("$YAYH" plan check "$plan" 2>&1)"
  assert_contains "$out" "warn: test 'test_saves_option — lost setting' has no layer"
  assert_eq "1" "$(printf '%s\n' "$out" | grep -c 'has no layer')"
}
