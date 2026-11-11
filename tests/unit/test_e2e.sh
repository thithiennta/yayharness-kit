# e2e: ports per checkout, scaffold (fill-in-the-gaps only), detect, specs, run

_e2erepo() { # [wc] -> a harnessed repo; Woo extension when $1 = wc
  local r wc='null'; r="$(mk_repo)"
  [ "${1:-}" = wc ] && wc='"8.0"'
  mkdir -p "$r/.yay"
  printf '<?php\n/**\n * Plugin Name: Giftly\n */\n' > "$r/giftly.php"
  printf '{"schemaVersion":1,"plugin":{"name":"Giftly","slug":"giftly","mainFile":"giftly.php"},"editions":["free"],"requires":{"wc":%s},"git":{"baseBranch":"main"},"commands":{"install":"composer install","build":"npm run build","e2e-start":"echo custom start"}}\n' "$wc" > "$r/.yay/config.json"
  commit_all "$r"
  printf '%s\n' "$r"
}

test_port_is_stable_per_plugin_and_unique_per_worktree() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  local base wtp
  base="$("$YAYH" e2e port)"
  case "$base" in 89[0-9]0|9[0-8][0-9]0) _pass ;; *) _fail "base port $base not in 8900-9890 step 10" ;; esac
  assert_eq "$base" "$("$YAYH" e2e port)" "stable"
  assert_eq "http://localhost:$base" "$("$YAYH" e2e url)"
  git -C "$YAY_REPO" worktree add -q -b feat/a "$T_TMP/wt-a" 2>/dev/null
  wtp="$(YAY_REPO="$T_TMP/wt-a" "$YAYH" e2e port)"
  [ "$wtp" != "$base" ] && [ "$wtp" -ge 10000 ] && [ "$wtp" -le 13998 ] && [ $((wtp % 2)) = 0 ] && _pass || _fail "worktree port $wtp"
  assert_eq "8800" "$(YAY_E2E_PORT=8800 "$YAYH" e2e port)" "env override"
  printf '{"e2e":{"baseUrl":"http://shop.local/"}}\n' > "$YAY_REPO/.yay/local.json"
  assert_eq "http://shop.local" "$("$YAYH" e2e url)" "external site"
}

test_scaffold_woo_fills_gaps_and_keeps_existing() {
  export YAY_REPO; YAY_REPO="$(_e2erepo wc)"
  local out port
  out="$("$YAYH" e2e scaffold)"
  port="$("$YAYH" e2e port)"
  assert_contains "$out" "created	tests/e2e/playwright.config.ts"
  assert_contains "$out" "created	.github/workflows/e2e.yml"
  assert_contains "$out" "created	tests/e2e/.gitignore"
  assert_contains "$out" "config	commands.e2e"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'commands.e2e-start' || true)" "existing command kept"
  assert_eq "echo custom start" "$("$YAYH" config get commands.e2e-start)"
  assert_eq "cd tests/e2e && ./node_modules/.bin/playwright test" "$("$YAYH" config get commands.e2e)"
  assert_eq "tests/e2e" "$("$YAYH" config get e2e.dir)"
  assert_eq "Giftly" "$("$YAYH" config get plugin.name)" "config otherwise intact"
  local env="$YAY_REPO/tests/e2e/.wp-env.json"
  assert_contains "$(cat "$env")" '"wp-content/plugins/giftly": "../.."'
  assert_contains "$(cat "$env")" "woocommerce.zip"
  assert_contains "$(cat "$env")" "\"port\": $port,"
  assert_contains "$(cat "$YAY_REPO/tests/e2e/bin/setup-env.sh")" "woocommerce_coming_soon"
  assert_contains "$(cat "$YAY_REPO/tests/e2e/specs/smoke.spec.ts")" 'data-plugin^="giftly/"'
  assert_contains "$(cat "$YAY_REPO/.github/workflows/e2e.yml")" "run: composer install && npm run build"
  assert_contains "$(cat "$YAY_REPO/.github/workflows/e2e.yml")" 'e2e-${{ github.ref }}'
  assert_eq "" "$(grep -rn '{{[a-z]' "$YAY_REPO/tests/e2e" || true)" "no placeholders left"
  assert_eq "" "$(grep -rn '#if-\|#end-' "$YAY_REPO/tests/e2e" "$YAY_REPO/.github" || true)" "no condition markers left"
  [ -x "$YAY_REPO/tests/e2e/bin/setup-env.sh" ] && _pass || _fail "setup-env.sh not executable"
  # a second run changes nothing
  echo "// hand edit" >> "$YAY_REPO/tests/e2e/playwright.config.ts"
  out="$("$YAYH" e2e scaffold)"
  assert_eq "" "$(printf '%s\n' "$out" | grep -v '^exists' || true)" "second run only reports exists"
  assert_contains "$(cat "$YAY_REPO/tests/e2e/playwright.config.ts")" "// hand edit"
}

test_scaffold_plain_wp_custom_dir_no_ci() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  "$YAYH" e2e scaffold dir=e2e --no-ci >/dev/null
  assert_no_file "$YAY_REPO/.github/workflows/e2e.yml"
  assert_contains "$(cat "$YAY_REPO/e2e/.wp-env.json")" '"plugins": [],'
  assert_contains "$(cat "$YAY_REPO/e2e/.wp-env.json")" '"wp-content/plugins/giftly": ".."'
  assert_eq "" "$(grep -n 'woocommerce' "$YAY_REPO/e2e/bin/setup-env.sh" || true)" "no Woo seed"
  assert_eq "cd e2e && ./node_modules/.bin/playwright test" "$("$YAYH" config get commands.e2e)"
  assert_fails "$YAYH" e2e scaffold dir=../out
}

test_specs_by_tag() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  mkdir -p "$YAY_REPO/tests/e2e/specs/node_modules"
  cat > "$YAY_REPO/tests/e2e/specs/menu.spec.ts" <<'TS'
test( 'shows the tab', { tag: '@P-1' }, async () => {} );
test( 'hides the tab', { tag: [ '@P-12', '@smoke' ] }, async () => {} );
TS
  echo "test( 'x', { tag: '@P-1' }, () => {} );" > "$YAY_REPO/tests/e2e/specs/node_modules/x.spec.ts"
  assert_eq "2	tests/e2e/specs/menu.spec.ts" "$("$YAYH" e2e specs)"
  assert_eq "tests/e2e/specs/menu.spec.ts:1:test( 'shows the tab', { tag: '@P-1' }, async () => {} );" "$("$YAYH" e2e specs P-1)"
  assert_contains "$("$YAYH" e2e specs P-12)" "hides the tab"
}

test_detect_existing_setup() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  mkdir -p "$YAY_REPO/tests/e2e" "$YAY_REPO/.github/workflows"
  : > "$YAY_REPO/tests/e2e/playwright.config.ts"; : > "$YAY_REPO/tests/e2e/.wp-env.single.json"
  printf '{\n  "name": "x",\n  "scripts": {\n    "test:e2e": "pnpm --filter e2e run test",\n    "build": "vite build"\n  }\n}\n' > "$YAY_REPO/package.json"
  printf 'jobs:\n  e2e:\n    run: pnpm test:e2e\n' > "$YAY_REPO/.github/workflows/e2e.yml"
  local out; out="$("$YAYH" e2e detect)"
  assert_contains "$out" "playwright	tests/e2e/playwright.config.ts"
  assert_contains "$out" "wp-env	tests/e2e/.wp-env.single.json"
  assert_contains "$out" "script	package.json	test:e2e: pnpm --filter e2e run test"
  assert_contains "$out" "ci	.github/workflows/e2e.yml"
  assert_eq "" "$(printf '%s\n' "$out" | grep 'vite' || true)"
}

test_run_needs_setup_and_a_live_site_and_appends_args() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  assert_fails "$YAYH" e2e run
  assert_contains "$("$YAYH" e2e status)" "setup	no"
  # an "external" site that answers: a one-shot local HTTP server
  local port=$((20000 + RANDOM % 20000))
  mkdir -p "$YAY_REPO/tests/e2e"
  printf '{"commands":{"e2e":"echo url=$E2E_BASE_URL args:"},"e2e":{"baseUrl":"http://127.0.0.1:%s"}}\n' "$port" > "$YAY_REPO/.yay/local.json"
  assert_exit 3 "$YAYH" e2e run
  ( cd "$T_TMP" && exec python3 -I -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  local pid=$! i=0
  while ! curl -s -o /dev/null "http://127.0.0.1:$port/" && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  local out; out="$("$YAYH" e2e run --grep "@P-1|@smoke" 2>/dev/null)"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  assert_eq "url=http://127.0.0.1:$port args: --grep @P-1|@smoke" "$out"
  assert_contains "$("$YAYH" e2e env start)" "managed outside yayh"
  assert_fails "$YAYH" e2e cli wp option get blogname
}

test_plan_check_warns_without_e2e_line_only_when_set_up() {
  export YAY_REPO; YAY_REPO="$(_e2erepo)"
  local plan; plan="$("$YAYH" artifact new plan "Gift tab")"
  assert_contains "$(cat "$YAY_REPO/$plan")" "**E2E:** none"
  python3 -I - "$YAY_REPO/$plan" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read().replace("**E2E:** none\n",""); open(p,"w").write(s)
PY
  assert_eq "" "$("$YAYH" plan check "$plan" 2>&1 | grep 'E2E' || true)" "no warning before setup"
  "$YAYH" e2e scaffold --no-ci >/dev/null
  assert_contains "$("$YAYH" plan check "$plan" 2>&1)" "warn: no '**E2E:**"
}
