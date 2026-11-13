<?php
/**
 * Plugin Name: Wporg Planted Fixture
 * Description: Test fixture for precheck.py: one planted violation per new check.
 * Version: 1.0.0
 * Requires at least: 6.5
 * Requires PHP: 7.4
 * Author: Yay Kit Tests
 * License: GPLv2 or later
 * Text Domain: wporg-planted
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require __DIR__ . '/includes/planted.php';
require __DIR__ . '/includes/clean.php';
