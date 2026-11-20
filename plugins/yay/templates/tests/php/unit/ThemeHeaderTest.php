<?php
namespace YayTests\Unit;

final class ThemeHeaderTest extends TestCase {

	public function test_style_css_declares_the_theme() {
		$header = file_get_contents( dirname( __DIR__, {{tests.levels}} ) . '/style.css' );

		$this->assertMatchesRegularExpression( '/Theme Name:\s*' . preg_quote( '{{plugin.name}}', '/' ) . '/', $header );
	}
}
