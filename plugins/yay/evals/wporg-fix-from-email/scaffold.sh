#!/usr/bin/env bash
# event-countdown-kit, as the local skill's fix-from-email fixture, in a harnessed
# repo that ships to WordPress.org: commands.package zips the plugin into release/.
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay bin includes
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Event Countdown Kit", "slug": "event-countdown-kit", "mainFile": "event-countdown-kit.php", "textDomain": "event-countdown-kit", "wporgSlug": "event-countdown-kit" },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "6.2", "wc": null },
  "git": { "baseBranch": "dev" },
  "commands": { "package": "bash bin/package.sh {version}" },
  "package": { "output": "release/{slug}-{version}.zip" },
  "versionFiles": [ { "file": "event-countdown-kit.php", "pattern": "Version: *([0-9][^[:space:]]*)" }, { "file": "readme.txt", "pattern": "^Stable tag: *([0-9][^[:space:]]*)" } ] }
JSON
cat > bin/package.sh <<'SH'
#!/usr/bin/env bash
# Zip what ships: everything but the repo's own files.
set -euo pipefail
v="${1:?version}"; s=event-countdown-kit
rm -rf release/stage; mkdir -p "release/stage/$s"
tar --exclude=./release --exclude=./.git --exclude=./.yay --exclude=./.claude --exclude=./bin --exclude=./.gitignore -cf - . | tar -xf - -C "release/stage/$s"
rm -f "release/$s-$v.zip"; (cd release/stage && zip -qr "../$s-$v.zip" "$s"); rm -rf release/stage
SH
printf 'release/\n.claude/\n' > .gitignore
cat > event-countdown-kit.php <<'FILE'
<?php
/**
 * Plugin Name: Event Countdown Kit
 * Description: Countdown timers for upcoming events via a shortcode.
 * Version: 1.0.0
 * Requires at least: 6.2
 * Requires PHP: 7.4
 * Author: Brightlane
 * License: GPLv2 or later
 * Text Domain: event-countdown-kit
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'ECK_VERSION', '1.0.0' );

require_once __DIR__ . '/includes/shortcode.php';
require_once __DIR__ . '/includes/admin.php';

function get_countdown_settings() {
	return get_option( 'countdown_settings', array( 'label' => 'Starts in', 'tz_offset' => 0 ) );
}

FILE
cat > readme.txt <<'FILE'
=== Event Countdown Kit ===
Contributors: brightlane
Tags: countdown, timer, events
Requires at least: 6.2
Tested up to: 7.1
Stable tag: 1.0.0
Requires PHP: 7.4
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Simple countdown timers for your upcoming events, with automatic public holiday labels.

== Description ==

Add `[eck_countdown date="2026-12-25" title="Christmas"]` to any post or page to show a countdown. If the date is a US public holiday, its name is shown under the timer.

== Installation ==

1. Upload the plugin and activate it.
2. Go to Settings > Event Countdown to change the label.

== Changelog ==

= 1.0.0 =
* Initial release.

FILE
cat > includes/shortcode.php <<'FILE'
<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_shortcode( 'eck_countdown', 'eck_render_countdown' );

function eck_render_countdown( $atts ) {
	$atts     = shortcode_atts( array( 'date' => '', 'title' => '' ), $atts, 'eck_countdown' );
	$settings = get_countdown_settings();
	$holiday  = eck_holiday_name( $atts['date'] );

	ob_start();
	?>
	<div class="eck-countdown" data-date="<?php echo $atts['date']; ?>">
		<h3><?php echo $atts['title']; ?></h3>
		<span class="eck-label"><?php echo $settings['label']; ?></span>
		<?php if ( $holiday ) : ?>
			<em><?php echo $holiday; ?></em>
		<?php endif; ?>
	</div>
	<?php
	return ob_get_clean();
}

function eck_holiday_name( $date ) {
	$cached = get_transient( 'holidays_' . substr( $date, 0, 4 ) );
	if ( false === $cached ) {
		$response = wp_remote_get( 'https://date.nager.at/api/v3/PublicHolidays/' . substr( $date, 0, 4 ) . '/US' );
		$cached   = json_decode( wp_remote_retrieve_body( $response ), true );
		set_transient( 'holidays_' . substr( $date, 0, 4 ), $cached, DAY_IN_SECONDS );
	}
	foreach ( (array) $cached as $h ) {
		if ( isset( $h['date'] ) && $h['date'] === $date ) {
			return $h['name'];
		}
	}
	return '';
}

FILE
cat > includes/admin.php <<'FILE'
<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'admin_menu', 'eck_admin_menu' );
function eck_admin_menu() {
	add_options_page( 'Event Countdown', 'Event Countdown', 'manage_options', 'eck', 'eck_settings_page' );
}

add_action( 'admin_init', 'eck_register_settings' );
function eck_register_settings() {
	register_setting( 'eck', 'countdown_settings', array( 'sanitize_callback' => 'eck_sanitize_settings' ) );
}

function eck_sanitize_settings( $input ) {
	return array(
		'label'     => sanitize_text_field( $input['label'] ?? '' ),
		'tz_offset' => (int) ( $input['tz_offset'] ?? 0 ),
	);
}

function eck_settings_page() {
	$settings = get_countdown_settings();
	?>
	<div class="wrap">
		<h1><?php echo esc_html__( 'Event Countdown', 'event-countdown-kit' ); ?></h1>
		<form method="post" action="options.php">
			<?php settings_fields( 'eck' ); ?>
			<input type="text" name="countdown_settings[label]" value="<?php echo $settings['label']; ?>">
			<input type="number" name="countdown_settings[tz_offset]" value="<?php echo $settings['tz_offset']; ?>">
			<?php submit_button(); ?>
		</form>
	</div>
	<?php
}

FILE
git add -A && git commit -qm "feat: event countdown kit 1.0.0"
