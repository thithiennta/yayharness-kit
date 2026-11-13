<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function wporg_planted_register() {
	register_post_type( 'wporg_planted_long_type_key', array( 'public' => true ) );
}
add_action( 'init', 'wporg_planted_register' );

function wporg_planted_body_class( $classes ) {
	return $classes . ' wporg-planted';
}
add_filter( 'admin_body_class', 'wporg_planted_body_class' );

function wporg_planted_admin_assets() {
	wp_enqueue_script( 'wporg-planted', plugins_url( 'admin.js', __FILE__ ), array(), '1.0.0', true );
	$data = array( 'label' => get_option( 'wporg_planted_label' ) );
	wp_add_inline_script( 'wporg-planted', 'var wporgPlanted = ' . wp_json_encode( $data ) . ';' );
}
add_action( 'admin_enqueue_scripts', 'wporg_planted_admin_assets' );

function wporg_planted_products() {
	return new WP_Query( array( 'post_type' => 'product', 'posts_per_page' => 10 ) );
}
