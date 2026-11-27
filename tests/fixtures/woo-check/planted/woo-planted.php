<?php
/**
 * Plugin Name: Woo Planted
 * Version: 1.0.0
 * Requires PHP: 7.4
 * WC tested up to: 9.0
 */

defined( 'ABSPATH' ) || exit;

if ( ! defined( 'WOO_PLANTED_URL' ) ) {
	define( 'WOO_PLANTED_URL', plugin_dir_url( __FILE__ ) );
}

add_action(
	'before_woocommerce_init',
	function () {
		\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'cart_checkout_blocks', __FILE__, false );
	}
);

require __DIR__ . '/includes/planted.php';
require __DIR__ . '/includes/clean.php';
