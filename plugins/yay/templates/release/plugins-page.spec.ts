import fs from 'fs';
import path from 'path';

import { expect, type Locator, type Page, test } from '@playwright/test';

const PLUGIN = process.env.YAY_PLUGIN_FILE ?? '';
const OUT = process.env.YAY_UI_OUT ?? 'ui';
const ERROR_TEXT = /critical error on this website|Fatal error|Parse error|Plugin could not be activated|Sorry, you are not allowed to access this page/i;
const lines: string[] = [];

const record = ( status: 'PASS' | 'WARN' | 'FAIL' | 'INFO', check: string, detail: string ) => {
	lines.push( `${ status }\t${ check }\t${ detail.replace( /\s+/g, ' ' ).trim() }` );
	fs.writeFileSync( path.join( OUT, 'ui-check.tsv' ), lines.join( '\n' ) + '\n' );
};

let shots = 0;
const shot = async ( page: Page, name: string ) => {
	shots++;
	const file = `${ String( shots ).padStart( 2, '0' ) }-${ name.replace( /[^a-z0-9]+/gi, '-' ).toLowerCase() }.png`;
	await page.screenshot( { path: path.join( OUT, file ), fullPage: true } );
	return file;
};

const row = ( page: Page ): Locator => page.locator( `tr[data-plugin="${ PLUGIN }"]` ).first();

const errorOnPage = async ( page: Page ) => {
	const text = ( await page.locator( 'body' ).innerText().catch( () => '' ) ) || '';
	const match = text.match( ERROR_TEXT );
	return match ? match[ 0 ] : '';
};

const openPluginsPage = async ( page: Page ) => {
	await page.goto( '/wp-admin/plugins.php' );
	await expect( row( page ) ).toBeVisible();
};

test( 'plugins page actions', async ( { page, baseURL } ) => {
	fs.mkdirSync( OUT, { recursive: true } );
	const origin = new URL( baseURL ?? '' ).origin;

	await test.step( 'log in', async () => {
		await page.goto( '/wp-login.php' );
		await page.locator( '#user_login' ).fill( 'admin' );
		await page.locator( '#user_pass' ).fill( 'password' );
		await page.locator( '#wp-submit' ).click();
		await expect( page ).not.toHaveURL( /wp-login\.php/ );
	} );

	await test.step( 'the plugin is listed', async () => {
		await page.goto( '/wp-admin/plugins.php' );
		if ( ! ( await row( page ).isVisible() ) ) {
			await shot( page, 'plugins-page-missing' );
			record( 'FAIL', 'listed', `${ PLUGIN } is not on the Plugins page` );
			throw new Error( 'plugin not listed' );
		}
		const version = ( await row( page ).locator( '.plugin-version-author-uri' ).innerText().catch( () => '' ) ).split( '|' )[ 0 ];
		record( 'PASS', 'listed', `${ PLUGIN } (${ version }) — ${ await shot( page, 'plugins-page' ) }` );
	} );

	await test.step( 'activate', async () => {
		if ( await row( page ).evaluate( ( el ) => el.classList.contains( 'active' ) ) ) {
			await page.goto( ( await row( page ).locator( 'span.deactivate a' ).getAttribute( 'href' ) ) ?? '' );
			await openPluginsPage( page );
		}
		const link = row( page ).locator( 'span.activate a' );
		if ( ! ( await link.count() ) ) {
			record( 'FAIL', 'activate', `no Activate link — ${ await shot( page, 'no-activate-link' ) }` );
			return;
		}
		await link.click();
		await page.waitForLoadState( 'load' );
		const landed = page.url();
		const error = await errorOnPage( page );
		const landing = await shot( page, 'after-activate' );
		await openPluginsPage( page );
		const active = await row( page ).evaluate( ( el ) => el.classList.contains( 'active' ) );
		if ( error || ! active ) {
			record( 'FAIL', 'activate', `${ error || 'the row is not active afterwards' } — ${ landing }` );
		} else {
			const where = landed.includes( '/plugins.php' ) ? 'stays on the Plugins page' : `redirects to ${ landed.replace( origin, '' ) }`;
			record( 'PASS', 'activate', `activates, ${ where } — ${ landing }` );
		}
		record( 'INFO', 'active-row', await shot( page, 'active-row' ) );
	} );

	await test.step( 'row action and meta links', async () => {
		await openPluginsPage( page );
		const links = await row( page ).locator( '.row-actions a, .plugin-version-author-uri a' ).evaluateAll( ( els ) =>
			els.map( ( a ) => ( {
				text: ( a.textContent ?? '' ).trim(),
				href: ( a as HTMLAnchorElement ).href,
				deactivate: !! a.closest( 'span.deactivate' ),
				dialog: a.getAttribute( 'href' ) === '#' || ( a.getAttribute( 'href' ) ?? '' ).startsWith( 'javascript:' ),
			} ) )
		);
		for ( const l of links.filter( ( x ) => ! x.deactivate ) ) {
			if ( l.dialog ) {
				record( 'INFO', 'link', `"${ l.text }" opens something on the page (no URL), not followed` );
				continue;
			}
			if ( ! l.href.startsWith( origin ) ) {
				record( 'INFO', 'link', `"${ l.text }" → ${ l.href } (external, not followed)` );
				continue;
			}
			const response = await page.goto( l.href );
			const status = response?.status() ?? 0;
			const error = await errorOnPage( page );
			const file = await shot( page, `link-${ l.text }` );
			if ( status >= 400 || error ) {
				record( 'FAIL', 'link', `"${ l.text }" → ${ l.href.replace( origin, '' ) }: ${ error || `HTTP ${ status }` } — ${ file }` );
			} else {
				record( 'PASS', 'link', `"${ l.text }" → ${ l.href.replace( origin, '' ) } (HTTP ${ status }) — ${ file }` );
			}
		}
		if ( ! links.some( ( x ) => ! x.deactivate ) ) record( 'INFO', 'link', 'no row action or meta links besides Deactivate' );
	} );

	await test.step( 'deactivate', async () => {
		await openPluginsPage( page );
		const link = row( page ).locator( 'span.deactivate a' );
		if ( ! ( await link.count() ) ) {
			record( 'FAIL', 'deactivate', `no Deactivate link — ${ await shot( page, 'no-deactivate-link' ) }` );
			return;
		}
		const href = ( await link.getAttribute( 'href' ) ) ?? '';
		const before = page.url();
		await link.click();
		const navigated = await page.waitForURL( ( u ) => u.href !== before, { timeout: 8_000 } ).then( () => true, () => false );
		if ( ! navigated ) {
			record( 'INFO', 'deactivate', `clicking Deactivate opens a dialog — ${ await shot( page, 'deactivate-dialog' ) }` );
			await page.goto( href );
		}
		const error = await errorOnPage( page );
		await openPluginsPage( page );
		const inactive = await row( page ).evaluate( ( el ) => el.classList.contains( 'inactive' ) );
		const file = await shot( page, 'after-deactivate' );
		if ( error || ! inactive ) record( 'FAIL', 'deactivate', `${ error || 'the row is still active' } — ${ file }` );
		else record( 'PASS', 'deactivate', `deactivates cleanly — ${ file }` );
	} );
} );
