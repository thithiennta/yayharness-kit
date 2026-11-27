# woo-check: woocheck.py's MAL and VAL rows, the tool converters, yayh woo-check static, the baseline and the tool install

_wc_py() { python3 -I "$KIT/skills/woo-check/scripts/woocheck.py" "$@"; }
_wc_fx() { printf '%s\n' "$ROOT/tests/fixtures/woo-check"; }

_wc_raw() { # tool -> the saved JSON with @ROOT@ set to the planted folder
  local f="$T_TMP/raw-$1.$RANDOM.json"
  sed "s#@ROOT@#$(_wc_fx)/planted#g" "$(_wc_fx)/raw/$1.json" > "$f"
  printf '%s\n' "$f"
}

# Fake tools in a fake cache, each one printing a saved JSON the way the real tool writes it.
_wc_stub_cache() { # sec_json gitleaks_json -> cache root (YAY_CACHE_DIR)
  local base="$T_TMP/cache.$RANDOM" c
  c="$(YAY_CACHE_DIR="$base" bash -c '. "$1/lib/common.sh"; YAY_KIT_ROOT="$1"; . "$1/lib/woocheck.sh"; yay_woocheck_cache' _ "$KIT")"
  mkdir -p "$c/vendor/bin" "$c/bin"
  cat > "$c/vendor/bin/phpcs" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do case "\$a" in --report-file=*) f="\${a#--report-file=}" ;; --standard=*) s="\${a#--standard=}" ;; esac; done
case "\$s" in *compat*) cp "$(_wc_raw phpcs-cmp)" "\$f" ;; *) cp "$1" "\$f" ;; esac
exit 2
EOF
  cat > "$c/vendor/bin/phpstan" <<EOF
#!/usr/bin/env bash
cat "$(_wc_raw phpstan)"; exit 1
EOF
  cat > "$c/bin/gitleaks" <<EOF
#!/usr/bin/env bash
while [ \$# -gt 0 ]; do [ "\$1" = --report-path ] && f="\$2"; shift; done
cp "$2" "\$f"
EOF
  chmod +x "$c/vendor/bin/phpcs" "$c/vendor/bin/phpstan" "$c/bin/gitleaks"
  printf '%s\n' "$base"
}

test_woocheck_py_planted() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  local out; out="$(_wc_py scan "$(_wc_fx)/planted" --requires-wc 8.0 --tested-wc 9.3 --wc-latest 10.3)"
  assert_contains "$out" "FAIL	MAL1	includes/planted.php	5	dangerous_function	shell_exec() call"
  assert_contains "$out" "FAIL	MAL1	includes/planted.php	7	dangerous_function	backtick shell execution"
  assert_contains "$out" "FAIL	MAL2	includes/planted.php	8	obfuscation"
  assert_contains "$out" "FAIL	MAL2	includes/planted.php	9	obfuscation	base64 string of 200+ characters"
  assert_contains "$out" "FAIL	MAL2	includes/planted.php	10	obfuscation	preg_replace() with the /e modifier"
  assert_contains "$out" "WARN	MAL4	includes/planted.php	11	non_printable"
  assert_contains "$out" "WARN	MAL3	.hidden	0	hidden_file"
  assert_contains "$out" "WARN	MAL3	assets/logo.png	0	disguised_php"
  assert_contains "$out" "WARN	MAL1	vendor/lib/process.php	3	dangerous_function	proc_open() call" "library code is WARN, not FAIL"
  assert_not_contains "$out" "includes/planted.php	13" "woo-check:allow MAL1 silences the line below it"
  assert_contains "$out" "FAIL	VAL1	woo-planted.php	0	wc_headers	missing header: WC requires at least"
  assert_contains "$out" "WARN	VAL2	woo-planted.php	0	wc_headers_config	WC tested up to is 9.0, tested.wc is 9.3"
  assert_contains "$out" "FAIL	VAL3	woo-planted.php	0	declare_hpos"
  assert_contains "$out" "WARN	VAL4	woo-planted.php	18	declare_blocks	declared incompatible with cart_checkout_blocks"
  assert_contains "$out" "WARN	VAL5	woo-planted.php	0	wc_tested_latest	WC tested up to 9.0, newest WooCommerce is 10.3"
  assert_not_contains "$out" "includes/clean.php" "comments, strings, heredocs and ->exec() stay quiet"
  assert_contains "$out" "FAIL	MAL1	vendor-prefixed/src/runner.php	3" "without --lib, vendor-prefixed/ is the plugin's own code"
  assert_contains "$(_wc_py scan "$(_wc_fx)/planted" --lib vendor-prefixed/)" "WARN	MAL1	vendor-prefixed/src/runner.php	3" "--lib makes it library code"
  assert_contains "$(_wc_py scan "$(_wc_fx)/planted")" "SKIP	VAL5" "no newest version: SKIP, not a pass"
}

test_woocheck_convert() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  local r="$(_wc_fx)/planted" out
  out="$(_wc_py convert phpcs-sec "$(_wc_raw phpcs-sec)" --root "$r")"
  assert_contains "$out" "FAIL	SEC1	includes/planted.php	12	WordPress.Security.EscapeOutput.OutputNotEscaped"
  assert_contains "$out" "FAIL	SEC2	includes/planted.php	20	WordPress.DB.PreparedSQL.InterpolatedNotPrepared"
  assert_contains "$out" "WARN	SEC1	includes/planted.php	21	WordPress.Security.NonceVerification.Missing"
  assert_not_contains "$out" "vendor/" "PHPCS rows from vendor/ are dropped"
  assert_contains "$(_wc_py convert phpcs-cmp "$(_wc_raw phpcs-cmp)" --root "$r")" "FAIL	CMP1	woo-planted.php	18	PHPCompatibility.Syntax.NewNullsafeOperator.Found"
  out="$(_wc_py convert phpstan "$(_wc_raw phpstan)" --root "$r")"
  assert_eq "FAIL	STAN1	includes/planted.php	30	function.notFound	Function woo_planted_missing not found." "$out" "one row, vendor/ dropped"
  out="$(_wc_py convert composer "$(_wc_raw composer)" --root "$r")"
  assert_contains "$out" "FAIL	SEC3	composer.lock	0	guzzlehttp/guzzle"
  assert_contains "$out" "WARN	SEC3	composer.lock	0	monolog/monolog"
  out="$(_wc_py convert npm "$(_wc_raw npm)" --root "$r")"
  assert_contains "$out" "FAIL	SEC4	package-lock.json	0	lodash"
  assert_contains "$out" "WARN	SEC4	package-lock.json	0	nth-check	through css-select (moderate, range <2.0.1), no fix available"
  out="$(_wc_py convert gitleaks "$(_wc_raw gitleaks)" --root "$r")"
  assert_contains "$out" "FAIL	SEC5	includes/settings.php	4	stripe-access-token"
  assert_not_contains "$out" "sk_live" "the secret is never printed"
  assert_eq "FAIL	SEC4	pnpm-lock.yaml	0	zod	Zod can exhaust memory while validating oversized constrained collections (high, affects <4.6.6, patched >=4.6.6) https://github.com/advisories/GHSA-mrhx-c7xc-m3w5" \
    "$(_wc_py convert pnpm "$(_wc_raw pnpm)" --root "$r")"
  assert_eq "FAIL	STAN1	includes/planted.php	14	new.static	Unsafe usage of new static()." "$(_wc_py convert phpstan "$(_wc_raw phpstan-trait)" --root "$r")" \
    "a trait's error comes once, under the trait's file"
  printf '{"totals":{},"files":{"%s/vendor-prefixed/src/runner.php":{"messages":[{"message":"x","line":3}]}}}' "$r" > "$T_TMP/stan-lib.json"
  assert_eq "" "$(_wc_py convert phpstan "$T_TMP/stan-lib.json" --root "$r" --lib vendor-prefixed/)" "--lib rows are dropped"
  printf '{"error":{"code":"ENOTFOUND","summary":"offline"}}' > "$T_TMP/npm-err.json"
  assert_eq "SKIP	SEC4	package-lock.json	0	npm-audit	audit didn't run: offline" "$(_wc_py convert npm "$T_TMP/npm-err.json" --root "$r")"
}

test_woocheck_constants_stub() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  local out; out="$(_wc_py constants "$(_wc_fx)/planted" --lib vendor-prefixed/)"
  assert_contains "$out" "define( 'WOO_PLANTED_URL', '' );" "a define() inside if ( ! defined() ) is in the stub"
  assert_not_contains "$out" "WOO_PLANTED_LIB" "library constants aren't"
}

test_woocheck_static_exit() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local o="$T_TMP/wc-out.$RANDOM" rc out none="$T_TMP/none.$RANDOM.json"
  printf '[]' > "$none"; printf '{"totals":{"errors":0,"warnings":0},"files":{}}' > "$T_TMP/clean-sec.json"
  # SEC fails: exit 1
  out="$(YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$(_wc_stub_cache "$(_wc_raw phpcs-sec)" "$none")" \
    "$YAYH" woo-check static "$(_wc_fx)/planted" out="$o" repo="$YAY_REPO" --only=sec)"; rc=$?
  assert_eq 1 "$rc" "a SEC FAIL stops it"
  assert_contains "$out" "SEC	Failed	2	1	0	2"
  assert_contains "$(cat "$o/findings.tsv")" "FAIL	SEC2	includes/planted.php	20"
  assert_contains "$(cat "$o/findings.tsv")" "SKIP	SEC3	-	0	-	no composer.lock in the repo"
  # SEC clean, STAN and CMP fail: they don't block
  out="$(YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$(_wc_stub_cache "$T_TMP/clean-sec.json" "$none")" \
    "$YAYH" woo-check static "$(_wc_fx)/planted" out="$o" repo="$YAY_REPO" --only=sec,stan,cmp)"; rc=$?
  assert_eq 0 "$rc" "STAN and CMP don't block"
  assert_contains "$out" "SEC	Success	0	0	0	2"
  assert_contains "$out" "STAN	Failed	1	0	0	0"
  assert_contains "$out" "CMP	Failed	1	0	0	0"
  assert_contains "$out" "MAL	Skipped"
  # a secret: exit 1
  YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$(_wc_stub_cache "$T_TMP/clean-sec.json" "$(_wc_raw gitleaks)")" \
    "$YAYH" woo-check static "$(_wc_fx)/planted" out="$o" repo="$YAY_REPO" --only=sec >/dev/null; rc=$?
  assert_eq 1 "$rc" "a secret stops it"
  # MAL from the planted folder: exit 1
  YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$T_TMP/empty-cache.$RANDOM" \
    "$YAYH" woo-check static "$(_wc_fx)/planted" out="$o" repo="$YAY_REPO" --only=mal >/dev/null; rc=$?
  assert_eq 1 "$rc" "MAL2 stops it"
}

test_woocheck_static_zip() {
  command -v python3 >/dev/null 2>&1 && command -v zip >/dev/null 2>&1 || { _pass; return; }
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local stage="$T_TMP/wc-stage.$RANDOM" z o="$T_TMP/wc-zout.$RANDOM"
  mkdir -p "$stage"; cp -R "$(_wc_fx)/planted" "$stage/woo-planted"
  z="$T_TMP/woo-planted.$RANDOM.zip"; (cd "$stage" && zip -qr "$z" woo-planted)
  YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$T_TMP/empty-cache.$RANDOM" "$YAYH" woo-check static "$z" out="$o" repo="$YAY_REPO" --only=val >/dev/null
  assert_contains "$(cat "$o/findings.tsv")" "FAIL	VAL3	woo-planted.php	0" "paths are relative to the zip's top folder"
  assert_eq "$o/src/woo-planted" "$(cat "$o/plugin-dir.txt")"
}

test_woocheck_static_missing_tools() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local o="$T_TMP/wc-miss.$RANDOM" rc out
  out="$(YAY_WOOCHECK_OFFLINE=1 YAY_CACHE_DIR="$T_TMP/empty-cache.$RANDOM" \
    "$YAYH" woo-check static "$(_wc_fx)/planted" out="$o" repo="$YAY_REPO" --only=sec,stan,cmp)"; rc=$?
  assert_eq 3 "$rc" "nothing ran"
  for id in SEC1 SEC2 SEC3 SEC4 SEC5 STAN1 CMP1; do assert_contains "$(cat "$o/findings.tsv")" "SKIP	$id	"; done
  assert_contains "$out" "SEC	Skipped	0	0	0	5"
  assert_not_contains "$out" "Success" "a skipped area is never a pass"
}

test_woocheck_baseline() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local o="$T_TMP/wc-base.$RANDOM" out b
  mkdir -p "$o"; b="$YAY_REPO/.yay/woo-check-baseline.tsv"
  printf '%s\n' "INFO	STAN1	-	0	phpstan	ran phpstan" \
    "FAIL	STAN1	a.php	10	function.notFound	Function x not found on line 10." \
    "FAIL	SEC1	a.php	3	WordPress.Security.EscapeOutput	not escaped" \
    "FAIL	SEC5	b.php	4	stripe-access-token	Stripe token" \
    "FAIL	MAL2	c.php	9	obfuscation	base64 string of 200+ characters" > "$o/findings.tsv"
  out="$("$YAYH" woo-check baseline "$o" --update)"
  assert_contains "$out" "KEPT	MAL2	never baselined"
  assert_contains "$out" "KEPT	SEC5	never baselined"
  assert_not_contains "$(grep -v "^#" "$b")" "SEC5"
  assert_not_contains "$(grep -v "^#" "$b")" "MAL2"
  local first; first="$(cat "$b")"
  # The STAN1 row moved (line and number in the message), SEC1 is gone, one STAN1 row is new.
  printf '%s\n' "INFO	STAN1	-	0	phpstan	ran phpstan" \
    "FAIL	STAN1	a.php	42	function.notFound	Function x not found on line 42." \
    "FAIL	STAN1	a.php	50	function.notFound	Function y not found." > "$o/findings.tsv"
  out="$("$YAYH" woo-check baseline "$o")"
  assert_contains "$(cat "$o/findings.tsv")" "BASE	STAN1	a.php	42" "a moved row stays baselined"
  assert_contains "$(cat "$o/findings.tsv")" "FAIL	STAN1	a.php	50" "a new row still counts"
  assert_contains "$out" "GONE	SEC1	a.php	WordPress.Security.EscapeOutput	not escaped"
  assert_contains "$(cat "$o/areas.tsv")" "STAN	Failed	1	0	1	0"
  # --update twice on the same input gives the same file
  printf '%s\n' "FAIL	STAN1	a.php	10	function.notFound	Function x not found on line 10." \
    "FAIL	SEC1	a.php	3	WordPress.Security.EscapeOutput	not escaped" > "$o/findings.tsv"
  "$YAYH" woo-check baseline "$o" --update >/dev/null
  assert_eq "$first" "$(cat "$b")" "sorted and stable"
}

test_woocheck_tools_sha_mismatch() {
  command -v python3 >/dev/null 2>&1 || { _pass; return; }
  local base="$T_TMP/cache-sha.$RANDOM" c p="$T_TMP/curl-bin.$RANDOM" rc
  c="$(YAY_CACHE_DIR="$base" "$YAYH" woo-check tools | head -1 | cut -f4)"; c="${c%/vendor/bin/phpcs}"
  mkdir -p "$c/vendor/bin" "$p"
  printf '#!/bin/sh\n' > "$c/vendor/bin/phpcs"; cp "$c/vendor/bin/phpcs" "$c/vendor/bin/phpstan"; chmod +x "$c/vendor/bin/"*
  printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && f="$2"; shift; done\necho junk > "$f"\n' > "$p/curl"; chmod +x "$p/curl"
  PATH="$p:$PATH" YAY_CACHE_DIR="$base" "$YAYH" woo-check tools --install >/dev/null 2>&1; rc=$?
  assert_eq 1 "$rc" "a wrong sha256 fails the install"
  assert_no_file "$c/bin/.gitleaks.tar.gz"
  assert_no_file "$c/bin/gitleaks"
}
