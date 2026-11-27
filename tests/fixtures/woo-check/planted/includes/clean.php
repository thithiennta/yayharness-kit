<?php
defined( 'ABSPATH' ) || exit;

// Never call shell_exec() or eval() here.
/* exec( 'nothing' ) in a comment */
$woo_planted_label = 'eval( base64_decode( "x" ) ) is only text';
$woo_planted_ok    = curl_exec( curl_init() );
$woo_planted_db    = $woo_planted_pdo->exec( 'SELECT 1' );
$woo_planted_html  = <<<HTML
<p>`not a backtick command` system( 'no' )</p>
HTML;
