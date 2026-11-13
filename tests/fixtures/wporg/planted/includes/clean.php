<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function wporg_planted_register_book() {
	register_post_type( 'wporg_book', array( 'public' => true ) );
}
add_action( 'init', 'wporg_planted_register_book' );

function wporg_planted_settings_assets( $hook_suffix ) {
	if ( 'settings_page_wporg-planted' !== $hook_suffix ) {
		return;
	}
	wp_enqueue_script( 'wporg-planted-settings', plugins_url( 'settings.js', __FILE__ ), array(), '1.0.0', true );
	$json = wp_json_encode( array( 'label' => get_option( 'wporg_planted_label' ) ), JSON_HEX_TAG | JSON_HEX_AMP );
	wp_add_inline_script( 'wporg-planted-settings', 'var wporgPlantedSettings = ' . $json . ';' );
}
add_action( 'admin_enqueue_scripts', 'wporg_planted_settings_assets' );

function wporg_planted_visible_products() {
	return new WP_Query(
		array(
			'post_type'      => 'product',
			'posts_per_page' => 10,
			'tax_query'      => array(
				array(
					'taxonomy' => 'product_visibility',
					'field'    => 'name',
					'terms'    => array( 'exclude-from-catalog' ),
					'operator' => 'NOT IN',
				),
			),
		)
	);
}

function wporg_planted_block( $attrs ) {
	return get_comment_delimited_block_content( 'wporg-planted/column', $attrs, '' );
}

register_setting( 'wporg_planted', 'wporg_planted_custom_css_class', array( 'sanitize_callback' => 'sanitize_html_class' ) );
