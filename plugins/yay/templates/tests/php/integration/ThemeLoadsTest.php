<?php
namespace YayTests\Integration;

use WP_UnitTestCase;

final class ThemeLoadsTest extends WP_UnitTestCase {

	public function test_the_theme_is_active() {
		$this->assertSame( '{{plugin.slug}}', get_stylesheet() );
		$this->assertTrue( wp_get_theme()->exists(), 'wp-env did not map the theme into wp-content/themes/' );
	}
#if-woo

	public function test_woocommerce_saves_a_product() {
		$product = new \WC_Product_Simple();
		$product->set_name( 'Integration product' );
		$product->set_regular_price( '10' );
		$product->save();

		$this->assertSame( '10', wc_get_product( $product->get_id() )->get_regular_price() );
	}
#end-woo
}
