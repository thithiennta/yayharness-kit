# engine-independent
# code index/find/similar/new: symbol search for reuse

_crepo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay" "$r/includes/Support" "$r/src" "$r/vendor/x" "$r/assets/dist"
  printf '{"git":{"baseBranch":"main"},"generatedPaths":["assets/dist/"]}\n' > "$r/.yay/config.json"
  cat > "$r/includes/Support/Format.php" <<'PHP'
<?php
namespace Giftly\Support;

/**
 * Formatting shared by every screen.
 */
final class Format {
	const DECIMALS = 2;

	/**
	 * A fee as a store price, honouring the tax display.
	 *
	 * @param float $amount Fee.
	 */
	public static function price( float $amount ): string {
		return wc_price( $amount );
	}

	/** Date in the store format. */
	public function date( $ts ) {
		$label = 'class names'; // a class word inside a string
		return gmdate( 'Y-m-d', $ts );
	}
}

function giftly_is_eligible( $order ) {
	return true;
}
define( 'GIFTLY_VERSION', '1.0.0' );
PHP
  cat > "$r/src/fees.ts" <<'TS'
/** Total of every gift fee in the cart. */
export function totalGiftFees(lines: number[]): number { return lines.reduce((a, b) => a + b, 0); }
export const formatFeeLabel = (fee: string): string => `Gift wrap (${fee})`;
export class FeeStore {
  async load(id: number) {
    if (id) { return id; }
  }
}
TS
  printf '<?php function vendored_helper() {}\n' > "$r/vendor/x/a.php"
  printf 'function builtThing(){}\n' > "$r/assets/dist/app.js"
  git -C "$r" add -A; git -C "$r" commit -qm "feat: init"
  printf '%s\n' "$r"
}

test_index_finds_php_and_ts_symbols_with_docs() {
  export YAY_REPO; YAY_REPO="$(_crepo)"
  local out; out="$("$YAYH" code index | cut -f3,4,6)"
  assert_contains "$out" "class	Format	Formatting shared by every screen."
  assert_contains "$out" "const	Format::DECIMALS"
  assert_contains "$out" "method	Format::price	A fee as a store price, honouring the tax display."
  assert_contains "$out" "method	Format::date	Date in the store format."
  assert_contains "$out" "function	giftly_is_eligible	"
  assert_contains "$out" "const	GIFTLY_VERSION"
  assert_contains "$out" "function	totalGiftFees	Total of every gift fee in the cart."
  assert_contains "$out" "function	formatFeeLabel"
  assert_contains "$out" "class	FeeStore"
  assert_contains "$out" "method	FeeStore.load"
  case "$out" in *vendored_helper*|*builtThing*|*"FeeStore.if"*) _fail "vendor, generated or keyword indexed: $out" ;; *) _pass ;; esac
  case "$out" in *"class	names"*) _fail "a string was indexed as a class" ;; *) _pass ;; esac
}

test_find_ranks_name_over_doc_matches() {
  export YAY_REPO; YAY_REPO="$(_crepo)"
  local out; out="$("$YAYH" code find format price | cut -f1,4)"
  assert_eq "4	Format::price" "$(printf '%s\n' "$out" | sed -n 1p)"
  assert_contains "$("$YAYH" code find gift fees | cut -f4)" "totalGiftFees"
  assert_eq "method" "$("$YAYH" code find store --kind=method | cut -f3 | sort -u | tr -d '\n')"
  assert_eq "1" "$("$YAYH" code find fee --limit=1 | wc -l | tr -d ' ')"
  assert_exit 1 "$YAYH" code find
}

test_similar_splits_identifiers() {
  export YAY_REPO; YAY_REPO="$(_crepo)"
  local out; out="$("$YAYH" code similar format_gift_fee_label | cut -f4)"
  assert_eq "formatFeeLabel" "$(printf '%s\n' "$out" | sed -n 1p)"
}

test_new_lists_symbols_added_on_branch() {
  export YAY_REPO; YAY_REPO="$(_crepo)"
  git -C "$YAY_REPO" switch -q -c feat/x
  python3 -I - "$YAY_REPO/includes/Support/Format.php" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("\tconst DECIMALS = 2;\n","\tconst DECIMALS = 2;\n\n\t/** Fee label. */\n\tpublic static function fee_label( float $f ): string {\n\t\treturn self::price( $f );\n\t}\n")
open(p,"w").write(s)
PY
  printf '<?php\nfunction giftly_wrap_cost() { return 1; }\n' > "$YAY_REPO/includes/wrap.php"
  local out; out="$("$YAYH" code new | cut -f1,3,4)"
  assert_contains "$out" "includes/Support/Format.php	method	Format::fee_label"
  assert_contains "$out" "includes/wrap.php	function	giftly_wrap_cost"
  case "$out" in *"Format::price"*|*"Format::date"*) _fail "unchanged symbols listed: $out" ;; *) _pass ;; esac
}

test_unused_flags_new_symbols_nothing_calls() {
  export YAY_REPO; YAY_REPO="$(_crepo)"
  git -C "$YAY_REPO" switch -q -c feat/x
  mkdir -p "$YAY_REPO/tests/php/unit" "$YAY_REPO/includes/Admin"
  cat > "$YAY_REPO/includes/wrap.php" <<'PHP'
<?php
function giftly_wrap_cost() { return giftly_wrap_rate() * 2; }
function giftly_wrap_rate() { return 1; }
function giftly_wrap_label() { return 'Wrap'; }
function giftly_wrap_later() { return 0; }
add_action( 'init', 'giftly_wrap_cost' );
PHP
  printf '<?php\nclass WrapTest { function test_label() { giftly_wrap_label(); } }\n' > "$YAY_REPO/tests/php/unit/WrapTest.php"
  cat > "$YAY_REPO/includes/Admin/Screen.php" <<'PHP'
<?php
class Giftly_Screen extends WP_List_Table {
	public function column_default( $item, $col ) { return ''; }
}
PHP
  local out; out="$("$YAYH" code unused | cut -f1,2,4,5)"
  assert_contains "$out" "unused	includes/wrap.php:5	giftly_wrap_later	"
  assert_contains "$out" "test-only	includes/wrap.php:4	giftly_wrap_label	"
  assert_contains "$out" "unused	includes/Admin/Screen.php:3	Giftly_Screen::column_default	may be called by name from its parent: Giftly_Screen extends WP_List_Table"
  case "$out" in *giftly_wrap_cost*|*giftly_wrap_rate*|*test_label*|*WrapTest*) _fail "called or test symbols listed: $out" ;; *) _pass ;; esac
}
