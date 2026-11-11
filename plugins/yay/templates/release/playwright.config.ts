import { defineConfig, devices } from '@playwright/test';

export default defineConfig( {
	testDir: '.',
	testMatch: /plugins-page\.spec\.ts/,
	outputDir: process.env.YAY_UI_OUT ? `${ process.env.YAY_UI_OUT }/test-results` : './test-results',
	timeout: 180_000,
	expect: { timeout: 15_000 },
	workers: 1,
	retries: 0,
	reporter: [ [ 'list' ] ],
	use: {
		...devices[ 'Desktop Chrome' ],
		baseURL: process.env.YAY_UI_URL,
		trace: 'retain-on-failure',
		screenshot: 'only-on-failure',
	},
} );
