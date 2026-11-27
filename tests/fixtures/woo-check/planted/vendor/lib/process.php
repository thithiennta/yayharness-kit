<?php
function woo_planted_vendor_run() {
	return proc_open( 'ls', array(), $pipes );
}
