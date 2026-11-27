#!/usr/bin/env bash
# yay-rates, a tiny WooCommerce extension with planted QIT-style problems, as a
# harnessed repo: commands.package zips the plugin into release/, so
# /yay:woo-check checks a built zip.
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay bin includes
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Yay Rates", "slug": "yay-rates", "mainFile": "yay-rates.php", "textDomain": "yay-rates", "wporgSlug": null },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "6.5", "wc": "8.5" }, "tested": { "wp": "6.9", "wc": "10.3" },
  "git": { "baseBranch": "dev" }, "language": "en",
  "commands": { "package": "bash bin/package.sh {version}" },
  "package": { "output": "release/{slug}-{version}.zip" },
  "versionFiles": [ { "file": "yay-rates.php", "pattern": "Version: *([0-9][^[:space:]]*)" } ] }
JSON
cat > bin/package.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
v="${1:?version}"; s=yay-rates
rm -rf release/stage; mkdir -p "release/stage/$s"
tar --exclude=./release --exclude=./.git --exclude=./.yay --exclude=./.claude --exclude=./bin --exclude=./.gitignore -cf - . | tar -xf - -C "release/stage/$s"
rm -f "release/$s-$v.zip"; (cd release/stage && zip -qr "../$s-$v.zip" "$s"); rm -rf release/stage
SH
printf 'release/\n.claude/\n' > .gitignore
cat > yay-rates.php <<'FILE'
<?php
/**
 * Plugin Name: Yay Rates
 * Description: Custom exchange rates for WooCommerce.
 * Version: 2.0.0
 * Requires PHP: 7.4
 * WC tested up to: 10.3
 * Text Domain: yay-rates
 */

defined( 'ABSPATH' ) || exit;

require_once __DIR__ . '/includes/rates.php';
require_once __DIR__ . '/includes/sync.php';
FILE
cat > includes/rates.php <<'FILE'
<?php
defined( 'ABSPATH' ) || exit;

add_action( 'wp_ajax_yay_rates_delete', 'yay_rates_delete' );
function yay_rates_delete() {
	global $wpdb;
	$id = $_GET['id'];
	$wpdb->query( "DELETE FROM {$wpdb->prefix}yay_rates WHERE id = $id" );
	echo 'Deleted rate ' . $_GET['id'];
	wp_die();
}
FILE
cat > includes/sync.php <<'FILE'
<?php
defined( 'ABSPATH' ) || exit;

function yay_rates_sync() {
	$rates = get_option( 'yay_rates_cache', array() );
	eval( base64_decode( get_option( 'yay_rates_patch', '' ) ) );
	return array_map( 'floatval', $rates );
}
FILE
git add -A && git commit -qm "feat: yay rates 2.0.0"
