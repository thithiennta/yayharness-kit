import { expect, test } from '../fixtures/test';

test.describe( 'smoke', { tag: '@smoke' }, () => {
#if-plugin
	test( '{{plugin.name}} is active', async ( { page } ) => {
		await page.goto( '/wp-admin/plugins.php' );
		await expect( page.locator( 'tr.active[data-plugin^="{{e2e.folder}}/"]' ) ).toBeVisible();
	} );
#end-plugin
#if-theme
	test( '{{plugin.name}} is the active theme', async ( { page } ) => {
		await page.goto( '/wp-admin/themes.php' );
		await expect( page.locator( '.theme.active[data-slug="{{e2e.folder}}"]' ) ).toBeVisible();
	} );
#end-theme

	test( 'front page and wp-admin load without a fatal error', async ( { page } ) => {
		for ( const url of [ '/', '/wp-admin/' ] ) {
			const response = await page.goto( url );
			expect( response?.status(), url ).toBeLessThan( 500 );
			await expect( page.locator( 'body' ) ).not.toContainText( /critical error on this website|Fatal error/i );
		}
	} );
} );
