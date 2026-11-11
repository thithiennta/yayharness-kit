<?php
/**
 * Unit test bootstrap. WordPress isn't loaded: stub what the code under test calls with Brain Monkey.
 */

$yay_tests_root = dirname( __DIR__, {{tests.levels}} );
require_once $yay_tests_root . '/vendor/autoload.php';

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', sys_get_temp_dir() . '/wordpress/' );
}

require_once __DIR__ . '/TestCase.php';
