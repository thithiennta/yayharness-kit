<?php
namespace YayTests\Unit;

use Brain\Monkey;
use Mockery\Adapter\Phpunit\MockeryPHPUnitIntegration;
use Yoast\PHPUnitPolyfills\TestCases\TestCase as PolyfillTestCase;

/**
 * Base for unit tests: Brain Monkey on, translation and escaping functions return their input.
 */
abstract class TestCase extends PolyfillTestCase {
	use MockeryPHPUnitIntegration;

	protected function set_up() {
		parent::set_up();
		Monkey\setUp();
		Monkey\Functions\stubTranslationFunctions();
		Monkey\Functions\stubEscapeFunctions();
	}

	protected function tear_down() {
		Monkey\tearDown();
		parent::tear_down();
	}
}
