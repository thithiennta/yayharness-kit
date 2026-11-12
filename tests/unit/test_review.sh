# review diff: flag-only reuse and comment findings

_rvrepo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay" "$r/includes" "$r/docs/plans"
  printf '{"git":{"baseBranch":"main"}}\n' > "$r/.yay/config.json"
  cat > "$r/includes/Settings.php" <<'PHP'
<?php
/**
 * Settings.
 */
final class Settings {

	/**
	 * Defaults.
	 */
	public static function defaults(): array {
		return array(
			// Labels default to empty: the fallbacks
			// stay translatable.
			'my_account' => array(
				'reviews_label' => '',
			),
		);
	}

	/**
	 * Format a fee as a store price.
	 */
	public static function format_fee( float $fee ): string {
		// Two decimals, like the cart.
		return number_format( $fee, 2 );
	}
}
PHP
  git -C "$r" add -A; git -C "$r" commit -qm "feat: init"
  git -C "$r" switch -qc feat/x
  printf '%s\n' "$r"
}

_kinds() { "$YAYH" review diff main "$@" | cut -f1 | grep -v '^summary' | sort | uniq -c | awk '{print $2"="$1}' | tr '\n' ' ' | sed 's/ $//'; }

test_clean_diff_has_no_findings() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  sed -i.bak "s/'reviews_label' => '',/'reviews_label' => '',\n\t\t\t\t'reviews_in_menu' => true,/" "$YAY_REPO/includes/Settings.php"; rm -f "$YAY_REPO/includes/Settings.php.bak"
  assert_eq "" "$(_kinds)"
  assert_eq "summary	0 finding(s)" "$("$YAYH" review diff main | tail -1)"
}

test_grown_heavy_and_edited_comments() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  python3 -I - "$YAY_REPO/includes/Settings.php" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("\t\t\t// stay translatable.\n","\t\t\t// stay translatable.\n\t\t\t// The in-menu flag only hides the tab; the endpoint stays registered\n\t\t\t// so links in emails keep working.\n")
s=s.replace("// Two decimals, like the cart.","// Always two decimals, matching the cart totals.")
open(p,"w").write(s)
PY
  local out; out="$("$YAYH" review diff main)"
  assert_contains "$out" "comment-grown	includes/Settings.php:14"
  assert_contains "$out" "comment-heavy	includes/Settings.php:14	2 inline comment line(s) for 0 code line(s)"
  assert_contains "$out" "comment-edited	includes/Settings.php:"
  assert_contains "$(printf '%s' "$out" | tail -1)" "summary	3 finding(s)"
}

test_comment_elsewhere_and_changelog() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  cat > "$YAY_REPO/includes/Menu.php" <<'PHP'
<?php
/**
 * Menu.
 */
function giftly_menu( array $items ): array {
	// MyAccountEndpoints keeps the endpoint registered, see endpoints.php.
	$items['x'] = 'X';
	// Added for R-2 so merchants can hide tabs.
	unset( $items['y'] );
	/* translators: %s: tab name, used by giftly_menu() */
	$label = sprintf( __( 'Tab %s', 'giftly' ), 'x' );
	return $items;
}
PHP
  local out; out="$("$YAYH" review diff main)"
  assert_contains "$out" "comment-elsewhere	includes/Menu.php:6	comment mentions MyAccountEndpoints"
  assert_contains "$out" "comment-changelog	includes/Menu.php:8"
  case "$out" in *"Menu.php:10"*) _fail "translators comment flagged: $out" ;; *) _pass ;; esac
}

test_docblock_prose() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  cat > "$YAY_REPO/includes/Long.php" <<'PHP'
<?php
/**
 * Short and fine.
 *
 * @param int $a A.
 */
function giftly_ok( $a ) { return $a; }

/**
 * Compute the thing.
 *
 * This walks the cart lines and adds them up, which
 * matters because the totals can be stale after a coupon
 * changes, and the old approach broke on HPOS stores.
 *
 * @param int $b B.
 */
function giftly_long( $b ) { return $b; }
PHP
  local out; out="$("$YAYH" review diff main)"
  assert_contains "$out" "docblock-prose	includes/Long.php:9	docblock has 3 prose lines"
  case "$out" in *"Long.php:2	"*) _fail "short docblock flagged" ;; *) _pass ;; esac
}

test_similar_function_flagged() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  printf '<?php\n/** Fee as price. */\nfunction giftly_format_fee_price( $f ) { return $f; }\n' > "$YAY_REPO/includes/fees.php"
  local out; out="$("$YAYH" review diff main)"
  assert_contains "$out" "similar-exists	includes/fees.php:3	giftly_format_fee_price() is new; existing look-alikes: Settings::format_fee (includes/Settings.php:23)"
}

test_no_caller_flagged() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  printf '<?php\nfunction giftly_unwired_helper() { return 1; }\n' > "$YAY_REPO/includes/unwired.php"
  local out; out="$("$YAYH" review diff main)"
  assert_contains "$out" "no-caller	includes/unwired.php:2	giftly_unwired_helper is new and no other code names it."
}

test_outside_plan() {
  export YAY_REPO; YAY_REPO="$(_rvrepo)"
  printf -- '---\nid: P-1\ntitle: t\nstatus: ready\n---\n## Tasks\n- [ ] T1 x — `includes/Settings.php`\n\n## Verify\n- y\n' > "$YAY_REPO/docs/plans/t.md"
  echo "<?php // x" > "$YAY_REPO/includes/Other.php"
  sed -i.bak 's/reviews_label/reviews_title/' "$YAY_REPO/includes/Settings.php"; rm -f "$YAY_REPO/includes/Settings.php.bak"
  local out; out="$("$YAYH" review diff main --plan=P-1)"
  assert_contains "$out" "outside-plan	includes/Other.php	changed, but no task in P-1 names it"
  case "$out" in *"outside-plan	includes/Settings.php"*|*"outside-plan	docs/"*) _fail "planned file flagged: $out" ;; *) _pass ;; esac
  assert_exit 0 "$YAYH" review diff main --plan=P-1
}
