# themes (plugin.kind = theme): detect from style.css, validate, wp-env and test scaffolds, release checks

_themerepo() { # [dir] -> a theme repo (Brandy-like), detected into .yay/config.json and committed
  local r
  if [ -n "${1:-}" ]; then
    r="$1"; mkdir -p "$r"; git -C "$r" init -q -b main
    git -C "$r" config user.email test@example.invalid; git -C "$r" config user.name test; git -C "$r" config commit.gpgsign false
  else
    r="$(mk_repo)"
  fi
  cat > "$r/style.css" <<'EOF'
/*
Theme Name: Brandy
Author: YayCommerce
Description: A block theme.
Version: 1.4.0
Requires at least: 6.5
Tested up to: 6.7
Requires PHP: 7.4
License: GNU General Public License v2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html
Text Domain: brandy
*/
EOF
  printf "<?php\ndefine( 'BRANDY_VERSION', '1.4.0' );\n" > "$r/functions.php"
  printf '=== Brandy ===\nContributors: yaycommerce\nRequires at least: 6.5\nTested up to: 6.7\nRequires PHP: 7.4\n\n== Changelog ==\n' > "$r/readme.txt"
  mkdir -p "$r/templates" "$r/.yay"; printf '<!-- wp:post-content /-->\n' > "$r/templates/index.html"
  YAY_REPO="$r" "$YAYH" harness detect 2>/dev/null > "$r/.yay/config.json"
  commit_all "$r"
  printf '%s\n' "$r"
}

test_detect_theme_from_style_css() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  local c="$YAY_REPO/.yay/config.json"
  assert_eq "theme" "$(jq -r .plugin.kind "$c")"
  assert_eq "style.css" "$(jq -r .plugin.mainFile "$c")"
  assert_eq "Brandy" "$(jq -r .plugin.name "$c")"
  assert_eq "brandy" "$(jq -r .plugin.slug "$c")" "slug from the text domain, not the folder"
  assert_eq "null" "$(jq -r .plugin.wporgSlug "$c")"
  assert_eq "6.7" "$(jq -r .tested.wp "$c")"
  assert_contains "$(jq -c .versionFiles "$c")" '"file":"functions.php"'
  assert_not_contains "$(jq -c .versionFiles "$c")" 'readme.txt' "no Stable tag, no readme version file"
  assert_eq "theme" "$("$YAYH" config get plugin.kind)"
  assert_ok "$YAYH" config validate
  "$YAYH" version set 1.5.0 >/dev/null
  assert_contains "$(cat "$YAY_REPO/style.css")" "Version: 1.5.0"
  assert_contains "$(cat "$YAY_REPO/functions.php")" "'BRANDY_VERSION', '1.5.0'"
}

test_detect_skips_a_version_constant_read_from_the_header() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  printf '/*\nTheme Name: Brandy\nVersion: 2.1.1\nText Domain: brandy\n*/\n' > "$YAY_REPO/style.css"
  printf "<?php\ndefine( 'BRANDY_VERSION', wp_get_theme()->get( 'Version' ) );\n" > "$YAY_REPO/functions.php"
  mkdir -p "$YAY_REPO/.yay"; "$YAYH" harness detect 2>/dev/null > "$YAY_REPO/.yay/config.json"
  assert_not_contains "$(jq -c .versionFiles "$YAY_REPO/.yay/config.json")" 'functions.php' "a non-literal define has no version to rewrite"
  "$YAYH" version set 2.1.2 >/dev/null
  assert_contains "$(cat "$YAY_REPO/style.css")" "Version: 2.1.2"
}

test_plugin_repo_has_no_kind_and_defaults_to_plugin() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  printf '<?php\n/**\n * Plugin Name: Giftly\n */\n' > "$YAY_REPO/giftly.php"
  printf '/*\nTheme Name: Not me\n*/\n' > "$YAY_REPO/style.css"   # a plugin's own stylesheet with a stray header
  mkdir -p "$YAY_REPO/.yay"; "$YAYH" harness detect 2>/dev/null > "$YAY_REPO/.yay/config.json"
  assert_eq "null" "$(jq -r .plugin.kind "$YAY_REPO/.yay/config.json")"
  assert_eq "giftly.php" "$("$YAYH" config get plugin.mainFile)"
  assert_eq "plugin" "$("$YAYH" config get plugin.kind)"
}

test_validate_guards_kind_and_main_file() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  local c="$YAY_REPO/.yay/config.json" err
  jq '.plugin.mainFile = "functions.php"' "$c" > "$c.n" && mv "$c.n" "$c"
  err="$("$YAYH" config validate 2>&1 || true)"
  assert_contains "$err" "a theme's plugin.mainFile must be style.css"
  jq '.plugin.mainFile = "style.css" | .plugin.kind = "block"' "$c" > "$c.n" && mv "$c.n" "$c"
  err="$("$YAYH" config validate 2>&1 || true)"
  assert_contains "$err" "plugin.kind must be plugin or theme"
}

test_site_path_derived_inside_wp_content_themes() {
  export YAY_REPO; YAY_REPO="$(_themerepo "$T_TMP/wp/wp-content/themes/brandy")"
  assert_eq "$(cd "$T_TMP/wp" && pwd -P)" "$(cd "$("$YAYH" config get site.wpPath)" && pwd -P)"
}

test_e2e_scaffold_maps_and_activates_the_theme() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  "$YAYH" e2e scaffold --no-ci >/dev/null
  assert_contains "$(cat "$YAY_REPO/tests/e2e/.wp-env.json")" '"wp-content/themes/brandy": "../.."'
  assert_not_contains "$(cat "$YAY_REPO/tests/e2e/.wp-env.json")" 'wp-content/plugins/'
  assert_contains "$(cat "$YAY_REPO/tests/e2e/bin/setup-env.sh")" "wp theme activate brandy"
  assert_contains "$(cat "$YAY_REPO/tests/e2e/specs/smoke.spec.ts")" '.theme.active[data-slug="brandy"]'
  assert_not_contains "$(cat "$YAY_REPO/tests/e2e/specs/smoke.spec.ts")" 'plugins.php'
  assert_eq "" "$(grep -rn '#if-\|#end-' "$YAY_REPO/tests/e2e" || true)" "no condition markers left"
  assert_eq "" "$(grep -rn '{{[a-z]' "$YAY_REPO/tests/e2e" || true)" "no placeholders left"
}

test_test_scaffold_writes_theme_tests() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  "$YAYH" test scaffold --no-ci >/dev/null
  local php="$YAY_REPO/tests/php"
  assert_file "$php/unit/ThemeHeaderTest.php"
  assert_no_file "$php/unit/PluginHeaderTest.php"
  assert_file "$php/integration/ThemeLoadsTest.php"
  assert_no_file "$php/integration/PluginLoadsTest.php"
  assert_contains "$(cat "$php/unit/ThemeHeaderTest.php")" "preg_quote( 'Brandy'"
  assert_contains "$(cat "$php/integration/bootstrap.php")" "pre_option_stylesheet', static fn() => 'brandy'"
  assert_not_contains "$(cat "$php/integration/bootstrap.php")" "/style.css"
  assert_contains "$("$YAYH" config get commands.test-integration)" "--env-cwd=wp-content/themes/brandy"
  assert_eq "" "$(grep -rn '{{[a-z]\|#if-\|#end-' "$php" || true)" "no placeholders or markers left"
}

test_release_checks_a_theme() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  local out; out="$("$YAYH" release check 1.4.0 || true)"
  assert_contains "$out" "PASS	stable-tag	none (a theme's version is its style.css Version)"
  "$YAYH" version tested wp=6.9 >/dev/null
  assert_contains "$(cat "$YAY_REPO/style.css")" "Tested up to: 6.9"
  assert_contains "$(cat "$YAY_REPO/readme.txt")" "Tested up to: 6.9"
  # a zip of the theme passes the content checks against style.css
  (cd "$T_TMP" && rm -rf z && mkdir -p z/brandy && cp "$YAY_REPO/style.css" "$YAY_REPO/functions.php" z/brandy/ && cd z && zip -qr ../brandy.zip brandy)
  out="$("$YAYH" build check "$T_TMP/brandy.zip" version=1.4.0 || true)"
  assert_contains "$out" "PASS	version	style.css Version: 1.4.0"
}

test_wporg_site_refuses_a_theme() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  : > "$T_TMP/x.zip"
  assert_contains "$("$YAYH" wporg site "$T_TMP/x.zip" out="$T_TMP/o" 2>&1 || true)" "/yay:wporg-theme"
}

_png() { # file w h: a minimal valid PNG
  python3 -I -c 'import struct,sys,zlib
w,h=int(sys.argv[2]),int(sys.argv[3])
c=lambda t,d: struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
raw=b"".join(b"\x00"+b"\x00"*w*3 for _ in range(h))
open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+c(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))+c(b"IDAT",zlib.compress(raw))+c(b"IEND",b""))' "$@"
}

_theme_stage() { # dir -> a clean block theme "brandy" in <dir>/brandy, the kind the Themes Team approves
  local t="$1/brandy"; mkdir -p "$t/templates" "$t/assets/js"
  cat > "$t/style.css" <<'CSS'
/*
Theme Name: Brandy
Author: YayCommerce
Description: A block theme for stores.
Version: 1.4.0
Requires at least: 6.5
Tested up to: 6.7
Requires PHP: 7.4
License: GNU General Public License v2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html
Text Domain: brandy
*/
CSS
  printf '=== Brandy ===\nContributors: yaycommerce\nRequires at least: 6.5\nTested up to: 6.7\nRequires PHP: 7.4\nLicense: GPLv2 or later\nLicense URI: http://www.gnu.org/licenses/gpl-2.0.html\n\nBrandy, Copyright 2026 YayCommerce.\n\n== Resources ==\n* Inter font, OFL-1.1\n' > "$t/readme.txt"
  printf '{ "version": 3, "settings": { "typography": { "fontFamilies": [ { "fontFace": [ { "src": [ "file:./assets/fonts/inter.woff2" ] } ] } ] } } }\n' > "$t/theme.json"
  printf '<!-- wp:post-content /-->\n' > "$t/templates/index.html"
  printf "<?php\nwp_enqueue_style( 'brandy-fonts', 'https://fonts.googleapis.com/css2?family=Inter' );\nregister_block_style( 'core/button', array( 'name' => 'brandy-outline', 'label' => __( 'Outline', 'brandy' ) ) );\n" > "$t/functions.php"
  printf 'x\n' > "$t/assets/js/app.js"; printf 'x\n' > "$t/assets/js/app.min.js"
  _png "$t/screenshot.png" 1200 900
}

_precheck() { python3 -I "$KIT/skills/wporg-theme/scripts/precheck.py" "$@"; }

test_precheck_passes_a_clean_theme() {
  local s="$T_TMP/clean.$RANDOM"; _theme_stage "$s"
  (cd "$s" && zip -qr ../clean.zip brandy)
  local out; out="$(_precheck "$T_TMP/clean.zip" --json)"
  assert_eq "0" "$(printf '%s' "$out" | jq '.counts.error // 0')" "no errors: $(printf '%s' "$out" | jq -c '[.findings[] | .check]')"
  assert_eq "0" "$(printf '%s' "$out" | jq '.counts.warning // 0')" "no warnings: $(printf '%s' "$out" | jq -c '[.findings[] | .check]')"
  assert_eq "true" "$(printf '%s' "$out" | jq .block)"
}

test_precheck_finds_planted_theme_issues() {
  local s="$T_TMP/bad.$RANDOM" t; _theme_stage "$s"; t="$s/brandy"
  sed -i.bak 's/^Theme Name: Brandy/Theme Name: WPShadcn Theme/; s/^Text Domain: brandy/Text Domain: wpshadcn/' "$t/style.css"; rm -f "$t/style.css.bak"
  rm "$t/theme.json" "$t/assets/js/app.js"
  _png "$t/screenshot.png" 1280 720
  : > "$t/.DS_Store"; : > "$t/install.sh"; : > "$t/assets/js/jquery.min.js"
  cat >> "$t/functions.php" <<'PHP'
register_post_type( 'brandy_portfolio', array() );
add_shortcode( 'brandy_button', 'brandy_button' );
wp_enqueue_script( 'brandy-x', 'https://cdn.jsdelivr.net/npm/x.js' );
remove_action( 'wp_head', 'wp_generator' );
show_admin_bar( false );
add_action( 'after_switch_theme', function () { wp_safe_redirect( admin_url( 'themes.php?page=brandy' ) ); exit; } );
__( 'Hi', 'woocommerce' );
PHP
  printf '@import url("https://cdn.example.com/x.css");\n' > "$t/extra.css"
  local f; f="$(_precheck "$t" --slug brandy --json | jq -r '.findings[] | "\(.id) \(.check)"')"
  local want
  for want in "B1 missing_theme_json" "X6 screenshot_too_big" "X6 screenshot_ratio" "X1 hidden_file" "X1 disallowed_file" \
      "X4 bundled_core_library" "X3 minified_without_source" "F7 plugin_territory_register_post_type" "F7 plugin_territory_add_shortcode" \
      "X2 remote_asset" "X2 remote_css_import" "F6 removes_core_hook" "F4 hides_admin_bar" "F5 redirect_on_activation" \
      "N1 reserved_word_in_name" "N3 third_party_name" "I2 text_domain_mismatch" "I3 other_text_domains"; do
    assert_contains "$f" "$want"
  done
  assert_not_contains "$f" "fonts.googleapis.com" "Google Fonts may stay remote for a theme"
  assert_contains "$(_precheck "$t" --slug brandy)" "## [ERROR] F7 plugin_territory_register_post_type (1)"
}

test_precheck_checks_a_classic_theme_hooks() {
  local s="$T_TMP/classic.$RANDOM" t; _theme_stage "$s"; t="$s/brandy"
  rm -rf "$t/templates" "$t/theme.json"
  printf '<!DOCTYPE html><html <?php language_attributes(); ?>><head><?php wp_head(); ?></head><body <?php body_class(); ?>>\n' > "$t/index.php"
  local f; f="$(_precheck "$t" --json | jq -r '.findings[] | "\(.id) \(.check)"')"
  assert_contains "$f" "K1 missing_comments_php"
  assert_contains "$f" "K2 missing_wp_footer"
  assert_contains "$f" "K2 missing_wp_body_open"
  assert_contains "$f" "K2 missing_title_tag"
  assert_not_contains "$f" "K2 missing_wp_head"
}

test_theme_site_skips_without_e2e_and_refuses_plugins() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  local s="$T_TMP/ts.$RANDOM" out rc o="$T_TMP/tsout.$RANDOM"; _theme_stage "$s"
  (cd "$s" && zip -qr ../ts.zip brandy)
  out="$("$YAYH" wporg theme-site "$T_TMP/ts.zip" out="$o")"; rc=$?
  assert_eq 3 "$rc" "exit without e2e setup"
  assert_contains "$out" "SKIP	site	no e2e setup"
  assert_eq "$out" "$(cat "$o/site.tsv")"
  local p; p="$(_ui_no_docker "$YAY_REPO")"
  out="$(PATH="$p" "$YAYH" wporg theme-site "$T_TMP/ts.zip" out="$o")"; rc=$?
  assert_eq 3 "$rc" "exit without Docker"
  assert_eq "SKIP	site	Docker is not running" "$out"
  assert_exit 1 "$YAYH" wporg theme-site "$T_TMP/ts.zip"
  # a plugin repo gets pointed back to yayh wporg site
  YAY_REPO="$(fixture_repo legacy-rich configured)"
  assert_contains "$("$YAYH" wporg theme-site "$T_TMP/ts.zip" out="$o" 2>&1 || true)" "use yayh wporg site"
}

test_e2e_surfaces_list_theme_templates_not_woo_hook_calls() {
  export YAY_REPO; YAY_REPO="$(_themerepo)"
  mkdir -p "$YAY_REPO/parts" "$YAY_REPO/patterns" "$YAY_REPO/woocommerce/cart"
  printf '<!-- wp:site-title /-->\n' > "$YAY_REPO/parts/header.html"
  printf '<?php\n/**\n * Title: Hero\n * Slug: brandy/hero\n */\n?>\n<p>Hi</p>\n' > "$YAY_REPO/patterns/hero.php"
  printf "<?php\ndo_action( 'woocommerce_before_cart' );\n" > "$YAY_REPO/woocommerce/cart/cart.php"
  printf "<?php\nadd_action( 'woocommerce_before_cart', 'brandy_notice' );\n" >> "$YAY_REPO/functions.php"
  commit_all "$YAY_REPO"
  local out; out="$(cd "$YAY_REPO" && "$YAYH" e2e surfaces)"
  assert_contains "$out" "template	templates/index.html:1	index"
  assert_contains "$out" "part	parts/header.html:1	header"
  assert_contains "$out" "pattern	patterns/hero.php:1	brandy/hero"
  assert_contains "$out" "wc-template	woocommerce/cart/cart.php:1	cart/cart.php"
  assert_contains "$out" "checkout	functions.php:4	woocommerce_before_cart"
  assert_not_contains "$out" "checkout	woocommerce/cart/cart.php" "calling a Woo hook is not a surface"
}
