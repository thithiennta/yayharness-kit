#!/usr/bin/env bash
# quick-share-buttons, with the local skill's planted violations, as a harnessed
# repo that ships to WordPress.org: commands.package zips the plugin into
# release/, so /yay:wporg reviews a built zip.
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay bin includes assets/js node_modules/lodash
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Quick Share Buttons", "slug": "quick-share-buttons", "mainFile": "plugin.php", "textDomain": "qsb", "wporgSlug": "quick-share-buttons" },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "5.8", "wc": null },
  "git": { "baseBranch": "dev" },
  "commands": { "package": "bash bin/package.sh {version}" },
  "package": { "output": "release/{slug}-{version}.zip" },
  "versionFiles": [ { "file": "plugin.php", "pattern": "Version: *([0-9][^[:space:]]*)" }, { "file": "readme.txt", "pattern": "^Stable tag: *([0-9][^[:space:]]*)" } ] }
JSON
cat > bin/package.sh <<'SH'
#!/usr/bin/env bash
# Zip what ships: everything but the repo's own files.
set -euo pipefail
v="${1:?version}"; s=quick-share-buttons
rm -rf release/stage; mkdir -p "release/stage/$s"
tar --exclude=./release --exclude=./.git --exclude=./.yay --exclude=./bin --exclude=./node_modules --exclude=.DS_Store --exclude=./.gitignore -cf - . | tar -xf - -C "release/stage/$s"
rm -f "release/$s-$v.zip"; (cd release/stage && zip -qr "../$s-$v.zip" "$s"); rm -rf release/stage
SH
printf 'release/\nnode_modules/\n.DS_Store\n' > .gitignore
cat > plugin.php <<'FILE'
<?php
/**
 * Plugin Name: Quick Share Buttons
 * Description: Adds share buttons to posts.
 * Version: 1.2.0
 * Author: Acme Devs
 * License: GPLv2 or later
 * Text Domain: qsb
 * Update URI: https://acme.example.net/updates/
 */

require_once __DIR__ . '/includes/settings.php';
require_once __DIR__ . '/includes/ajax.php';

register_activation_hook( __FILE__, 'qsb_activate' );
function qsb_activate() {
	wp_remote_post( 'https://stats.acmedevs.io/ping', array( 'body' => array( 'site' => home_url(), 'admin' => get_option( 'admin_email' ) ) ) );
}

function enqueue_assets() {
	wp_enqueue_script( 'qsb-chart', 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js', array(), null );
	wp_enqueue_script( 'qsb-front', plugins_url( 'assets/js/front.min.js', __FILE__ ), array( 'jquery' ), '1.2.0', true );
}
add_action( 'wp_enqueue_scripts', 'enqueue_assets' );

add_filter( 'the_content', 'qsb_buttons' );
function qsb_buttons( $content ) {
	$label = get_option( 'qsb_label', 'Share' );
	$html  = '<div class="qsb">' . $label . '</div>';
	if ( ! qsb_is_pro() ) {
		return $content . $html; // Pro networks locked.
	}
	return $content . $html . qsb_pro_networks();
}

function qsb_is_pro() {
	return 'valid' === get_option( 'qsb_license_status' );
}

function qsb_pro_networks() {
	return '<div class="qsb-pro">LinkedIn, Reddit, Telegram</div>';
}

add_action( 'admin_notices', function () {
	echo '<div class="notice notice-info"><p>Upgrade to Quick Share Pro for 20 more networks! <a href="https://acmedevs.io/pro">Buy now</a></p></div>';
} );

FILE
cat > readme.txt <<'FILE'
=== Quick Share Buttons ===
Contributors: Acme Devs
Tags: share, social, buttons, facebook, twitter, sharethis, addtoany
Requires at least: 5.8
Tested up to: 6.4
Stable tag: 1.1.0
License: GPLv2 or later

Here is a short description of the plugin. This should be no more than 150 characters. No markup here.

== Description ==

Quick Share Buttons adds social share buttons to your posts. Upgrade to Pro to unlock 20 more networks.

== Changelog ==

= 1.2.0 =
* Initial release.

FILE
cat > includes/settings.php <<'FILE'
<?php
add_action( 'admin_menu', function () {
	add_options_page( 'Quick Share', 'Quick Share', 'manage_options', 'qsb', 'qsb_render_settings' );
} );

add_action( 'admin_init', function () {
	register_setting( 'qsb', 'qsb_label' );
} );

function qsb_render_settings() {
	if ( isset( $_POST['qsb_label'] ) ) {
		update_option( 'qsb_label', $_POST['qsb_label'] );
	}
	?>
	<div class="wrap">
		<h1><?php _e( 'Quick Share Settings', 'qsb' ); ?></h1>
		<form method="post">
			<input name="qsb_label" value="<?php echo get_option( 'qsb_label' ); ?>">
			<?php submit_button(); ?>
		</form>
	</div>
	<?php
}

FILE
cat > includes/ajax.php <<'FILE'
<?php
add_action( 'wp_ajax_qsb_delete_stats', 'qsb_delete_stats' );
add_action( 'wp_ajax_nopriv_qsb_track', 'qsb_track' );

function qsb_delete_stats() {
	global $wpdb;
	$post_id = $_POST['post_id'];
	$wpdb->query( "DELETE FROM {$wpdb->prefix}qsb_stats WHERE post_id = $post_id" );
	wp_send_json_success();
}

function qsb_track() {
	$ch = curl_init( 'https://api.acmedevs.io/track?u=' . $_SERVER['REMOTE_ADDR'] );
	curl_exec( $ch );
	$msg = <<<HTML
<p>Tracked</p>
HTML;
	echo $msg;
	wp_die();
}

FILE
cat > assets/js/front.min.js <<'FILE'
!function(e){var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;var a=1;}(jQuery);

FILE
cat > node_modules/lodash/index.js <<'FILE'
module.exports={}

FILE
printf '\0' > .DS_Store
git add -A && git commit -qm "feat: quick share buttons 1.2.0"
