<?php
function woo_planted_prefixed_run() {
	return shell_exec( "ls" );
}
if ( ! defined( "WOO_PLANTED_LIB" ) ) { define( "WOO_PLANTED_LIB", 1 ); }
