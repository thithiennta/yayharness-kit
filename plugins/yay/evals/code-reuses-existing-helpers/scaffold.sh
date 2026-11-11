#!/usr/bin/env bash
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay docs/bugs docs/plans docs/brainstorms docs/backlog docs/knowledge includes
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Giftly", "slug": "giftly", "mainFile": "giftly.php", "textDomain": "giftly", "wporgSlug": null },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "6.5", "wc": "9.0" },
  "git": { "baseBranch": "dev" },
  "commands": { "test": "php tests/run.php" },
  "versionFiles": [ { "file": "giftly.php", "pattern": "Version: *([0-9][^[:space:]]*)" }, { "file": "readme.txt", "pattern": "^Stable tag: *([0-9][^[:space:]]*)" } ] }
JSON
cat > giftly.php <<'PHP'
<?php
/**
 * Plugin Name: Giftly
 * Version: 1.2.0
 * Text Domain: giftly
 */
defined( 'ABSPATH' ) || exit;
require __DIR__ . '/includes/GiftMessage.php';
PHP
cat > includes/GiftMessage.php <<'PHP'
<?php
namespace Giftly;

/** Gift messages typed at checkout. */
final class GiftMessage {
    const MAX = 200;

    /** Trim and cap a message; messages of exactly MAX characters are allowed. */
    public static function clean( string $text ): string {
        $text = trim( $text );
        return strlen( $text ) >= self::MAX ? substr( $text, 0, self::MAX - 1 ) : $text;
    }
}
PHP
mkdir -p tests
cat > tests/run.php <<'PHP'
<?php
define( 'ABSPATH', __DIR__ );
require __DIR__ . '/../includes/GiftMessage.php';
$ok = Giftly\GiftMessage::clean( '  hi  ' ) === 'hi';
echo $ok ? "ok
" : "FAIL
"; exit( $ok ? 0 : 1 );
PHP
cat > readme.txt <<'TXT'
=== Giftly ===
Stable tag: 1.2.0

== Changelog ==

= 1.2.0 - 2026-10-01 =
* New: Gift messages at checkout.
TXT
cat > docs/roadmap.md <<'MD'
---
horizon: 2026-12-31
sprint_length: 2w
updated: 2026-10-20
---
# Roadmap: Giftly

## Sprint 1 (2026-10-20 → 2026-11-02)

### R-1 Gift wrap option
- status: in-progress
- size: M
- why: most-requested feature in the support forum

## Sprint 2 (2026-11-03 → 2026-11-16)

### R-2 Gift message preview
- status: planned
- size: S
- why: shoppers can't see how the card will look

## Later

### R-3 Scheduled delivery date
- status: planned
- size: L
MD
cat > docs/bugs/2026-11-05-checkout-crash-on-emoji.md <<'MD'
---
id: B-1
title: Checkout crashes when the gift message has an emoji
status: root-caused
severity: high
editions: [free]
found_in: 1.2.0
fixed_in:
branch:
pr:
created: 2026-11-05
---
# B-1 Checkout crashes when the gift message has an emoji
MD
git add -A && git commit -qm "chore: fixture"
mkdir -p includes/Helpers
cat > includes/Helpers/Money.php <<'PHP'
<?php
/**
 * Money formatting.
 *
 * @package Giftly
 */

namespace Giftly\Helpers;

defined( 'ABSPATH' ) || exit;

/**
 * Formats every price the plugin shows.
 */
final class Money {

	/**
	 * Format an amount as a store price (currency, decimals, tax display).
	 *
	 * @param float $amount Amount in the store currency.
	 * @return string Price HTML.
	 */
	public static function format( float $amount ): string {
		return function_exists( 'wc_price' ) ? wc_price( $amount ) : number_format( $amount, 2 );
	}
}
PHP
cat > includes/Settings.php <<'PHP'
<?php
/**
 * Plugin settings.
 *
 * @package Giftly
 */

namespace Giftly;

defined( 'ABSPATH' ) || exit;

/**
 * Reads the giftly_settings option merged over the defaults.
 */
final class Settings {

	/**
	 * Default values.
	 *
	 * @return array
	 */
	public static function defaults(): array {
		return array(
			'gift_wrap_enabled' => false,
			'gift_wrap_fee'     => 2.5,
			// Slugs and labels default to empty and hold merchant overrides only: the fallbacks
			// live in MyAccountEndpoints, so the default label stays translatable instead of
			// being frozen into the saved option.
			'my_account'        => array(
				'reviews_slug'  => '',
				'reviews_label' => '',
				'rewards_slug'  => '',
				'rewards_label' => '',
			),
		);
	}

	/**
	 * One setting, falling back to its default.
	 *
	 * @param string $key Top-level key.
	 * @return mixed
	 */
	public static function get( string $key ) {
		$saved = get_option( 'giftly_settings', array() );
		$all   = array_replace_recursive( self::defaults(), is_array( $saved ) ? $saved : array() );
		return $all[ $key ] ?? null;
	}
}
PHP
cat > includes/Cart.php <<'PHP'
<?php
/**
 * Cart integration.
 *
 * @package Giftly
 */

namespace Giftly;

use Giftly\Helpers\Money;

defined( 'ABSPATH' ) || exit;

/**
 * Adds the gift wrap fee to the cart.
 */
final class Cart {

	/**
	 * Fee line label shown in the cart totals.
	 *
	 * @return string
	 */
	public static function fee_label(): string {
		/* translators: %s: formatted fee */
		return sprintf( __( 'Gift wrap (%s)', 'giftly' ), Money::format( (float) Settings::get( 'gift_wrap_fee' ) ) );
	}
}
PHP
cat > includes/Checkout.php <<'PHP'
<?php
/**
 * Checkout fields.
 *
 * @package Giftly
 */

namespace Giftly;

defined( 'ABSPATH' ) || exit;

/**
 * Renders the gift options at checkout.
 */
final class Checkout {

	/**
	 * Gift wrap checkbox, shown when gift wrap is enabled.
	 */
	public static function render_gift_wrap_field(): void {
		if ( ! Settings::get( 'gift_wrap_enabled' ) ) {
			return;
		}
		echo '<p class="giftly-wrap"><label><input type="checkbox" name="giftly_wrap" value="1"> ' . esc_html__( 'Add gift wrap', 'giftly' ) . '</label></p>';
	}
}
PHP
cat > includes/MyAccountEndpoints.php <<'PHP'
<?php
/**
 * My Account endpoints.
 *
 * @package Giftly
 */

namespace Giftly;

defined( 'ABSPATH' ) || exit;

/**
 * Registers the Reviews and Rewards tabs in My Account.
 */
final class MyAccountEndpoints {

	/**
	 * Hook in.
	 */
	public static function init(): void {
		add_action( 'init', array( __CLASS__, 'register' ) );
		add_filter( 'woocommerce_account_menu_items', array( __CLASS__, 'menu_items' ) );
	}

	/**
	 * Register the endpoints.
	 */
	public static function register(): void {
		add_rewrite_endpoint( self::slug( 'reviews' ), EP_ROOT | EP_PAGES );
		add_rewrite_endpoint( self::slug( 'rewards' ), EP_ROOT | EP_PAGES );
	}

	/**
	 * Add the tabs to the menu.
	 *
	 * @param array $items Menu items.
	 * @return array
	 */
	public static function menu_items( array $items ): array {
		$items[ self::slug( 'reviews' ) ] = self::label( 'reviews', __( 'Reviews', 'giftly' ) );
		$items[ self::slug( 'rewards' ) ] = self::label( 'rewards', __( 'Rewards', 'giftly' ) );
		return $items;
	}

	/**
	 * Endpoint slug: the merchant's override, else the tab name.
	 *
	 * @param string $tab reviews|rewards.
	 * @return string
	 */
	public static function slug( string $tab ): string {
		$my_account = Settings::get( 'my_account' );
		return $my_account[ $tab . '_slug' ] ? $my_account[ $tab . '_slug' ] : $tab;
	}

	/**
	 * Tab label: the merchant's override, else the translated fallback.
	 *
	 * @param string $tab      reviews|rewards.
	 * @param string $fallback Translated default label.
	 * @return string
	 */
	public static function label( string $tab, string $fallback ): string {
		$my_account = Settings::get( 'my_account' );
		return $my_account[ $tab . '_label' ] ? $my_account[ $tab . '_label' ] : $fallback;
	}
}
PHP
cat > includes/Notices.php <<'PHP'
<?php
/**
 * Admin notices.
 *
 * @package Giftly
 */

namespace Giftly;

defined( 'ABSPATH' ) || exit;

/**
 * Stock notices for gift wrap products.
 */
final class Notices {

	/**
	 * Show the low-stock notice on the products screen.
	 *
	 * @param int $stock Units left.
	 */
	public static function maybe_low_stock( int $stock ): void {
		// Warn early enough that a merchant can restock before the weekend rush.
		if ( $stock < 5 ) {
			echo '<div class="notice notice-warning"><p>' . esc_html__( 'Gift wrap is running low.', 'giftly' ) . '</p></div>';
		}
	}
}
PHP
git add -A && git commit -qm "feat: gift wrap, settings, endpoints and notices"
# Make the reuse realistic: the price helper lives under Support/, has tax-display
# logic an inline wc_price() would miss, and is only used far from checkout.
git rm -q includes/Helpers/Money.php includes/Cart.php
mkdir -p includes/Support includes/Admin
cat > includes/Support/Format.php <<'PHP'
<?php
/**
 * Display formatting.
 *
 * @package Giftly
 */

namespace Giftly\Support;

defined( 'ABSPATH' ) || exit;

/**
 * Formatting shared by every screen.
 */
final class Format {

	/**
	 * A fee as a store price, honouring the shop's tax display and suffix.
	 *
	 * @param float $amount Fee, excluding tax.
	 * @return string Price HTML.
	 */
	public static function price( float $amount ): string {
		$incl = 'incl' === get_option( 'woocommerce_tax_display_shop' );
		$shown = $incl ? $amount * ( 1 + self::tax_rate() ) : $amount;
		return wc_price( $shown ) . ( $incl ? ' <small>' . esc_html__( 'incl. tax', 'giftly' ) . '</small>' : '' );
	}

	/**
	 * Standard tax rate for the shop base location, as a fraction.
	 *
	 * @return float
	 */
	public static function tax_rate(): float {
		$rates = class_exists( 'WC_Tax' ) ? \WC_Tax::get_base_tax_rates() : array();
		$rate  = $rates ? reset( $rates ) : array( 'rate' => 0 );
		return (float) $rate['rate'] / 100;
	}
}
PHP
cat > includes/Admin/Report.php <<'PHP'
<?php
/**
 * Gift wrap report.
 *
 * @package Giftly
 */

namespace Giftly\Admin;

use Giftly\Settings;
use Giftly\Support\Format;

defined( 'ABSPATH' ) || exit;

/**
 * Admin report of gift wrap revenue.
 */
final class Report {

	/**
	 * Current fee, for the report header.
	 *
	 * @return string
	 */
	public static function fee_html(): string {
		return Format::price( (float) Settings::get( 'gift_wrap_fee' ) );
	}
}
PHP
git add -A && git commit -qm "refactor: move price formatting to Support\\Format"
