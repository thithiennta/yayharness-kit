import fs from 'fs';
import path from 'path';

import { expect, type Locator, type Page, test } from '@playwright/test';

const THEME = process.env.YAY_THEME ?? '';
const OUT = process.env.YAY_UI_OUT ?? 'ui';
const ERROR_TEXT = /critical error on this website|Fatal error|Parse error|The theme is missing|Sorry, you are not allowed to access this page/i;
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

const card = ( page: Page ): Locator => page.locator( `.theme[data-slug="${ THEME }"]` ).first();

const errorOnPage = async ( page: Page ) => {
	const text = ( await page.locator( 'body' ).innerText().catch( () => '' ) ) || '';
	const match = text.match( ERROR_TEXT );
	return match ? match[ 0 ] : '';
};

// The pages every theme renders: front page, a post, a page, search, a 404.
const FRONT = [
	{ name: 'front page', url: '/' },
	{ name: 'post', url: '/?p=1' },
	{ name: 'page', url: '/?page_id=2' },
	{ name: 'search', url: '/?s=hello' },
	{ name: '404', url: '/?p=999999', expect404: true },
];

test( 'themes page and front end', async ( { page } ) => {
	fs.mkdirSync( OUT, { recursive: true } );

	await test.step( 'log in', async () => {
		await page.goto( '/wp-login.php' );
		await page.locator( '#user_login' ).fill( 'admin' );
		await page.locator( '#user_pass' ).fill( 'password' );
		await page.locator( '#wp-submit' ).click();
		await expect( page ).not.toHaveURL( /wp-login\.php/ );
	} );

	await test.step( 'the theme is listed', async () => {
		await page.goto( '/wp-admin/themes.php' );
		if ( ! ( await card( page ).isVisible() ) ) {
			const broken = await page.locator( '.broken-themes' ).innerText().catch( () => '' );
			record( 'FAIL', 'listed', `${ THEME } is not on the Themes page${ broken ? ` (broken themes: ${ broken })` : '' } — ${ await shot( page, 'themes-page-missing' ) }` );
			throw new Error( 'theme not listed' );
		}
		record( 'PASS', 'listed', `${ THEME } — ${ await shot( page, 'themes-page' ) }` );
	} );

	await test.step( 'activate', async () => {
		const href = await card( page ).locator( 'a.activate' ).getAttribute( 'href' );
		if ( ! href ) {
			record( 'FAIL', 'activate', `no Activate link — ${ await shot( page, 'no-activate-link' ) }` );
			throw new Error( 'no activate link' );
		}
		await page.goto( href );
		const error = await errorOnPage( page );
		const landing = await shot( page, 'after-activate' );
		await page.goto( '/wp-admin/themes.php' );
		const active = await card( page ).evaluate( ( el ) => el.classList.contains( 'active' ) );
		if ( error || ! active ) record( 'FAIL', 'activate', `${ error || 'the theme is not active afterwards' } — ${ landing }` );
		else record( 'PASS', 'activate', `activates — ${ landing }` );
	} );

	await test.step( 'front-end pages', async () => {
		for ( const p of FRONT ) {
			const response = await page.goto( p.url );
			const status = response?.status() ?? 0;
			const error = await errorOnPage( page );
			const file = await shot( page, `front-${ p.name }` );
			const bad = error || status >= 500 || ( ! p.expect404 && status >= 400 );
			record( bad ? 'FAIL' : 'PASS', 'front', `${ p.name } ${ p.url } (HTTP ${ status })${ error ? `: ${ error }` : '' } — ${ file }` );
		}
	} );

	await test.step( 'editor screen', async () => {
		// A block theme opens the Site Editor; a classic theme gets core's "not compatible" page, so try the Customizer.
		await page.goto( '/wp-admin/site-editor.php' );
		const classic = /not compatible with the Site Editor/i.test( await page.locator( 'body' ).innerText().catch( () => '' ) );
		if ( classic ) await page.goto( '/wp-admin/customize.php' );
		const error = await errorOnPage( page );
		const file = await shot( page, classic ? 'customizer' : 'site-editor' );
		record( error ? 'FAIL' : 'PASS', 'editor', `${ classic ? 'Customizer' : 'Site Editor' } opens${ error ? `: ${ error }` : '' } — ${ file }` );
	} );

	await test.step( 'switch back', async () => {
		await page.goto( '/wp-admin/themes.php' );
		const other = page.locator( `.theme:not([data-slug="${ THEME }"]) a.activate` ).first();
		const href = ( await other.count() ) ? await other.getAttribute( 'href' ) : null;
		if ( ! href ) {
			record( 'INFO', 'switch-back', 'no other theme installed to switch to' );
			return;
		}
		await page.goto( href );
		const error = await errorOnPage( page );
		const file = await shot( page, 'after-switch-back' );
		record( error ? 'FAIL' : 'PASS', 'switch-back', `switching to another theme ${ error ? `fails: ${ error }` : 'works' } — ${ file }` );
	} );
} );
