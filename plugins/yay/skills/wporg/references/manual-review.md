# Manual review pass: what the tools miss

Plugin Check and the precheck script find patterns. A reviewer (and the AI scanner they use) also reads the code for *intent*: who can reach this code, what leaves the site, what is locked. Work through these areas in order; the first four are where most review emails come from and where approvals stall.

For every finding, record: its ID from `checklist.md`, file:line, the code, the rule (use the Common Issues heading from `wporg-rules.md` §2 when one exists), and the concrete fix. Each section below names the IDs it settles.

## Contents
1. Entry points: nonce, capability, sanitize, escape
2. Trialware and locked features (guideline 5)
3. Phoning home, tracking, external services (guidelines 6, 7, 8)
4. Prefixing and naming collisions
5. Admin experience: notices, upsells, menus (guideline 11)
6. Bundled libraries and licensing (guidelines 1, 2, 13)
7. Readme quality
8. Name, slug, trademarks and ownership (guideline 17)
9. Purpose-level rejections
10. Smaller things reviewers still mention
11. Replying to the email

---

## 1. Entry points: nonce, capability, sanitize, escape

IDs: S1, S2, S3, S4, S5, S6, S7, S8, S10, S11, S12, S13.

List every way a request reaches the plugin's code. The precheck inventory gives you a head start (`ajax_admin_post_handlers`, `rest_routes`, `superglobal_uses`), but also look for: form handlers on `admin_init`/`init`/`template_redirect` that read `$_POST`/`$_GET`, `add_shortcode` callbacks (attributes are user input from authors), block `render_callback`s, `wp_ajax_nopriv_*`, cron callbacks that take stored input, webhook listeners, `parse_request` handlers, custom query vars.

For each entry point check, in this order:

| Check | Wanted | Typical miss |
|---|---|---|
| Nonce | `check_ajax_referer()`, `check_admin_referer()` or `wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['x_nonce'] ) ), 'x_action' )` before any work | `isset( $_POST['nonce'] ) && wp_verify_nonce(...)` that lets execution continue when the nonce is absent; nonce verified but result ignored |
| Capability | `current_user_can( 'manage_options' )` (or the specific cap) for anything that changes data or reveals non-public data | relying on `is_admin()` (true for any admin-ajax request, even logged-out) or on the nonce alone. "A nonce alone is not authorization" is the #1 trigger of the 2026 release scanner |
| REST | `permission_callback` that checks a capability; `__return_true` only for genuinely public, read-only data | `__return_true` on routes that write options or return user data |
| nopriv | Logged-out handlers must not write options/posts/users, delete anything, or return private data | "track" or "save" endpoints open to the world |
| Sanitize early | Read only the keys you need; `wp_unslash()` then a type-appropriate sanitizer (`sanitize_text_field`, `sanitize_email`, `absint`, `sanitize_key`, `esc_url_raw` for URLs to store, `wp_kses_post` for HTML); validate against allowed values (`in_array( $v, $allowed, true )`) | sanitizing with `esc_*`; `sanitize_text_field` on arrays; whole-`$_POST` loops; `$_SERVER['HTTP_*']`/`REMOTE_ADDR` used raw |
| Escape late | At the echo: `esc_html`, `esc_attr`, `esc_url`, `esc_textarea`, `wp_kses_post`/`wp_kses`, `wp_json_encode` for JS data | escaping when building `$html` then echoing later (reviewers want it at output); options echoed raw because "they were sanitized on save"; `echo $html` returned from a helper |
| SQL | `$wpdb->prepare()` with placeholders (`%d %s %f %i`), `IN()` via `implode( ',', array_fill( 0, count( $ids ), '%d' ) )` | table names or `ORDER BY` from user input; `prepare()` with no placeholders; `esc_sql` used instead of prepare |
| Files | Paths built from input go through `sanitize_file_name()`, `realpath()` + a base-dir check; uploads via `wp_handle_upload()` with a MIME allow-list | `include $_GET['tab'] . '.php'`; delete/unlink with request paths |
| Redirects | `wp_safe_redirect( $url ); exit;` | `wp_redirect( $_GET['redirect_to'] )` (open redirect) |
| Deserialization | JSON for anything that crossed a trust boundary | `unserialize()` / `maybe_unserialize()` on cookies, request data or remote responses |
| Output callbacks | Shortcode, `render_callback` and `the_content`/`the_title` filter callbacks sanitize their inputs (shortcode atts are user input) and escape what they return | building block comment markup by hand from atts (`<!-- wp:x/col-<?php echo $slug ?> …`); use an allow-list + `get_comment_delimited_block_content()` / `serialize_block_attributes()` |
| Public REST | Each `__return_true` route is either read-only public data or justified (public form) with validation and abuse protection | public POST routes with no justification. The email lists *every* `__return_true` route, so plan a one-line justification per route for the reply |
| Inline script JSON (S11) | `wp_json_encode( $data, JSON_HEX_TAG \| JSON_HEX_AMP )` for every value handed to `wp_add_inline_script()` or `wp_print_inline_script_tag()`, translations included (they aren't your text) | plain `wp_json_encode( $data )`, so a value holding `</script>` closes the tag. Don't remove `JSON_HEX_*` flags to satisfy S6: S6 is about `JSON_UNESCAPED_*` |
| Stored HTML (S12) | Echo through `wp_kses()` with an allow-list for that markup, or escape each attribute at output and drop the `$html` variable | `echo $html; // phpcs:ignore`: the comment doesn't pass review. `wp_kses_post()` strips `<input>`, `<svg>` and `srcset`, so form and icon markup needs its own allow-list. After the change, parse the HTML from before and after and compare each tag, attribute and value |
| Block comments (S13) | `serialize_block_attributes()` / `get_comment_delimited_block_content()` | `<!-- wp:x <?php echo wp_json_encode( $attrs ); ?> -->`: a value holding `-->` closes the comment and adds markup |

Write security findings with the exact handler name, because the reviewer will. Group them per handler rather than per rule when one handler has several problems; it makes the fix obvious.

## 2. Trialware and locked features (guideline 5)

ID: G4.

The free plugin may advertise a pro version, but every line of code it ships must work without a license. Start from the precheck `pro_license_gates` inventory, which includes built JS (`assets/dist`, `build/`): the scanner reads minified bundles and has quoted an `isPro` check from one. Search for: `is_pro`, `is_premium`, `pro_active`, `license`, `license_key`, `activation_key`, `premium`, `upgrade`, `freemius`, `fs_is_paying`, `can_use_premium_code`, `__premium_only`, `get_option( '*_license*' )`, trial/days-left logic, quota counters (`max_`, `limit`, `count >`).

Flag when:
- code present in the free zip is skipped/disabled unless a license/pro flag is set (classic: `if ( ! $this->is_pro() ) return;` around a feature implemented right there);
- features stop after N days, N uses, N items;
- the plugin calls a server only to validate a key that unlocks bundled code (guideline 6: a license check is not a "service");
- UI shows pro features as disabled controls with the real implementation hidden in the same plugin.

Fine: upsell links/screens, a separate pro add-on plugin that adds code (the free plugin can check `defined( 'PRO_ADDON_VERSION' )` to hide its own upsell), SaaS features that genuinely run on the vendor's server and are documented.

Fix to suggest: move locked code to the pro add-on and expose hooks/filters for it; or make the feature free.

## 3. Phoning home, tracking, external services (guidelines 6, 7, 8)

IDs: G1, G2, G3, R6.

Start from the precheck `external_hosts` and `http_calls` inventory, then read each call site and also search JS for `fetch(`, `axios`, `XMLHttpRequest`, `navigator.sendBeacon`, `<iframe`, `new Image().src`.

For each host the plugin *contacts* (links in admin UI don't count):
1. When does it fire? On activation, on every page load, only after the user enables a feature?
2. What data goes out? Site URL, admin email, IP, user data, content?
3. Is there explicit opt-in before the first request? (Activation pings, "anonymous usage stats" enabled by default, and telemetry SDKs that send before consent are guideline 7 violations.)
4. Is it in readme.txt? The team wants an `== External services ==` section with, per service: what it is and what it's used for, what data is sent and when, a link to the service, its Terms of Service and its Privacy Policy. Your own domain counts as a third party here.

Also guideline 8: no JS/CSS from CDNs (fonts are OK), no remote JS execution, no installing or updating code from anywhere but WordPress.org (custom updaters, `Update URI`, downloading zips, "install our other plugins" without consent), no admin iframes to a service.

Suggested readme block for the report:
```
== External services ==

This plugin connects to the Acme Share Counts API to show share totals next to the buttons.
It sends the post URL each time a post with share buttons is viewed, and only when "Show counts" is enabled in Settings > Quick Share.
Service: https://acme.example/  Terms: https://acme.example/terms  Privacy: https://acme.example/privacy
```

## 4. Prefixing and naming collisions

IDs: Q2, Q9.

Everything in the global namespace must carry a unique prefix of 4+ characters (or live under a unique PHP namespace): functions, classes, interfaces, traits, constants/`define`s, global variables, option names, transient names, user/post meta keys, custom hooks fired with `do_action`/`apply_filters`, AJAX action names, REST namespaces, script/style handles, CPT and taxonomy names, shortcode tags, DB table names, cookie names, cron hook names, localized JS object names.

Precheck lists suspicious names; confirm by reading. Reviewers also flag:
- prefixes of 2–3 letters (`qsb_`), or very generic ones (`wp_`, `my_`, `plugin_`, `settings_`, `admin_`);
- `if ( ! function_exists( 'x' ) )` wrapped around your own functions (only for shared library code);
- the namespace itself being generic (`App\`, `Admin\`, `Plugin\`).

Recommend one prefix derived from the slug and show the rename list. If the plugin is already in use somewhere, note that option/meta renames need a migration.

## 5. Admin experience: notices, upsells, menus (guideline 11)

IDs: G5, Q3.

Check every `admin_notices` hook (precheck inventory) and any dashboard widgets, admin pointers, and menu registrations:
- notices show only on the plugin's own screens or where they're relevant (check `get_current_screen()->id`), not on the Dashboard, Posts or Plugins pages. A notice doesn't have to be dismissible to pass, but one that shows outside the plugin's screens does, and the dismissal must stick;
- error notices must say how to fix the problem and disappear when fixed;
- review requests and upsells: limited, contextual, dismissible permanently;
- no ads in the dashboard; no top-level menu items that link off-site (Plugin Check error); a "Go Pro" submenu linking to your site is fine;
- no hijacking of other plugins' or core screens; no redirect to a welcome page on every activation in bulk activations (redirect only on single activation, once).
- **Q3: nothing leaks into WordPress's own screens.** An `admin_body_class` filter adds its class only on the plugin's screen (the classes then style the whole admin). CSS selectors stay under the plugin's wrapper, never bare `body`, `.wrap`, `#wpcontent` or `.button`. `admin_enqueue_scripts` callbacks check `$hook_suffix`; `wp_enqueue_scripts` and `enqueue_block_assets` callbacks load a dependency (a WooCommerce script, a slider) only on pages that use it. To confirm, open a front-end page with no plugin content and an unrelated admin page, and filter DevTools → Network by the slug: nothing should load. Precheck flags `admin_body_class` filters and unconditional enqueue callbacks (`Q3`).

## 6. Bundled libraries and licensing (guidelines 1, 2, 13)

IDs: G7, Q8, B1, B2, B3.

Look in `vendor/`, `lib/`, `libs/`, `includes/libraries/`, `assets/vendor/`, `node_modules/` and any copied JS/CSS:
- license of each library is GPL-compatible (MIT, BSD, Apache-2.0, LGPL, MPL-2.0, ISC, Unlicense are fine); fonts and images too; anything "premium"/commercial (pro builds of icon sets, slider libs, some chart libs) must go;
- it isn't a copy of something core ships (jQuery, jQuery UI, Backbone, Underscore, Lodash, Moment, React, PHPMailer, SimplePie, PHPass) — use the core handle;
- it's the latest stable version and maintained (check the version string in the file header against what you know; say "verify" if unsure rather than guessing);
- Composer `vendor/` ships with `composer.json`;
- minified/compiled JS/CSS has human-readable source in the zip or a public repo linked **in the readme**, with build steps.
- **B1: the public source is really public.** Open every repo link from the readme in a logged-out browser: a private repo answers 404, and that's a blocker. Reviewers land on the default branch, so it must hold the same code as the zip, not a stale `master`. The public repo also exposes every branch and the history, so check that no paid code is in it.
- **B2: the build steps work from nothing.** Clone the public repo into an empty folder with no login, run the readme's steps exactly (`npm ci && npm run build`), and compare the result with the zip's built folders. The readme names the tool versions (Node, npm/pnpm, Composer).
- **B3:** each bundled library has its header comment, or is listed in the readme with name, version and URL.

Plugin header `License` and readme `License` match, and the plugin itself is GPLv2-or-later compatible.

## 7. Readme quality

IDs: R1, R5, R6.

Beyond the field checks the script does:
- Written in English (required since July 2025).
- The description explains what the plugin does and how to use it (first submissions get extra scrutiny on this). Placeholder or one-line descriptions get flagged.
- No keyword stuffing, no competitor names as tags, at most 5 tags, no links to "leave a 5-star review".
- No claims of guaranteed legal compliance ("makes your site GDPR compliant").
- Affiliate links disclosed; no cloaked links.
- External services section (see §3) and source/build section (see §6) present when needed.
- If there's no support, say so.

## 8. Name, slug, trademarks and ownership (guideline 17)

IDs: N1, N2, N3, U2.

- The slug comes from the Plugin Name at upload and can be changed only once before approval and never after. Settle it now.
- Don't start the name/slug with someone else's trademark or project name (Woo, WooCommerce, Elementor, Google, Facebook, ChatGPT, etc.); "X for WooCommerce" is the accepted pattern. Never "WordPress" or "plugin" in the slug, no version numbers.
- The display name must not imply it is official.
- Slug, folder name, main file name (`slug.php`) and Text Domain should all be the same string.
- **Check every distinctive word, not just the trademark lists.** For each word in the name, ask whether it is the name of someone else's project, library, framework, theme, builder or service (precheck `PROJECT_NAMES` covers common ones; "Shadcn" was flagged in a real email). If it is and it comes first, recommend `<Own brand> <function> for <Project>`. Also search the web or the directory for the full name: similar names get flagged, and "AB Prices", "Easy Prices" or "Prices for X by Brand" don't fix that (the distinguishing term goes at the **start**).
- Apply the same check to the Plugin URI/domain, the WordPress.org username and display name, contributors, and the icon and banner art.
- **Ownership ("Are you the rightful owner?").** Compare Plugin Name, Plugin URI, Author, Author URI and Contributors with the account that will submit (ask the user which account and email domain). Mismatches trigger the ownership section: a Plugin URI on another domain, a brand name that isn't the account's, or a personal account for a company plugin. Tell the user in advance which proof they'll need: a DNS TXT record `wordpressorg-<username>-verification` at that domain's root, an account email on that domain, a transfer to the owner's account (never resubmit from another account), or a reply explaining the relationship. Simplest prevention: make Plugin URI and Author URI the submitting company's domain.
- If the name changes, the reply must **explicitly** request the new slug. Changing the header alone doesn't change the slug.

## 9. Purpose-level rejections

ID: G8.

Mention these up front if they apply, because no code fix helps:
- lets users insert/execute arbitrary PHP/JS/CSS/HTML (code-snippet boxes, custom JS fields without `unfiltered_html` gating);
- only installs other plugins, or is a framework/library/boilerplate with no end-user function;
- duplicates core with no meaningful improvement, or copies an existing plugin;
- storefront-only (a plugin whose only purpose is selling something);
- black-hat SEO, content spinning, auto-posting scraped content.

## 10. Smaller things reviewers still mention

IDs: S9, Q1, Q4, Q6, Q7, Q9, Q10, Q11, Q12, Q13, Q14, T3, B4.

- `if ( ! defined( 'ABSPATH' ) ) exit;` in every PHP file with code that runs at load, including block pattern files in `patterns/` that contain `<?php echo … ?>`.
- `ob_start()` closed in the same function, and no filter, hook or early return able to skip the close. Opening in one hook and closing in another is flagged.
- No `load_plugin_textdomain()` (not needed since WP 4.6), and no `Tested up to` in the plugin header (readme only).
- No direct `wp-load.php` includes; use admin-ajax, REST or `admin-post.php`.
- No writing files into the plugin folder (wiped on update) — `wp_upload_dir()` instead.
- `uninstall.php` checks `WP_UNINSTALL_PLUGIN` and actually cleans up options/tables the plugin created. If a Pro version shares the same options/posts, make sure deleting Free doesn't wipe Pro's data (and that any "you can safely delete Free" notice is true); on multisite, check it cleans every site or says it doesn't.
- When the build strips files (licensing, Pro code), check that nothing still references them: Composer autoload maps (`vendor/composer/autoload_*.php`), `require` lists, asset manifests. A stripped updater class still named in the classmap reads as an updater to the scanner.
- Scripts and styles via `wp_enqueue_*`, loaded only on screens that need them (`$hook_suffix` check in `admin_enqueue_scripts`).
- No PHP notices/warnings with `WP_DEBUG` on; no `error_log`/`var_dump` debug leftovers.
- `Requires at least` is honest: functions used exist in that version.
- Blocks: `block.json` `apiVersion: 3`.
- AI features: call the WordPress AI Client rather than providers directly where possible, and document the provider as an external service.
- Shipping only what's needed: no `.git`, `.github`, `node_modules`, tests, `.DS_Store`, AI tool folders (`.claude`, `.cursor`), zips, or stray markdown — but keep `composer.json`/`package.json` so the code can be rebuilt.
- **Q9: post type keys are 20 characters or fewer.** A longer key makes `register_post_type()` fail. A long prefix uses up the limit, so count again after a prefix rename. Precheck flags literal keys (`Q9`); check keys built from constants by hand.
- **Q10: requirements are checked at runtime.** `Requires at least`, `Requires PHP` and `Requires Plugins` don't protect a site that downgrades WordPress or PHP, or deactivates WooCommerce. Before loading code that needs them, the plugin checks the minimum WordPress and PHP versions and its required plugins, shows an admin notice and stops. `yayh wporg site` tests this by forcing an older `$GLOBALS['wp_version']` from a mu-plugin (`Q10`): a fatal is a FAIL, no notice is a WARN.
- **Q11: activation is clean.** With `WP_DEBUG` on, `wp plugin activate` prints nothing, logs nothing and contacts no server. Tables use `$wpdb->prefix`, `$wpdb->get_charset_collate()` and `dbDelta()`. `yayh wporg site` checks the activation output and one front-end and one admin request (`Q11`).
- **Q12: query and render cost is bounded.** For each loop over posts, products or variations (`posts_per_page => -1`, `get_available_variations()`, `get_children()`, `wc_get_product()` in a loop), find its upper limit, including when a setting turns pagination off. A limit in the admin UI alone doesn't count: the server applies it too.
  - Prime the cache before a loop with `_prime_post_caches( $ids )`. An uncached `wc_get_product()` costs about 4 queries.
  - `clone` on a `WC_Data` object runs a meta query unless the meta is already read, so clone only when needed.
  - **Method:** turn on `SAVEQUERIES`, render the page at two data sizes (for example 10 and 500 products), one PHP process per size, and compare `count( $wpdb->queries )` with a similar WooCommerce block. Build the large set inside a transaction and roll it back. Report it under "Other details" with the numbers; it's never an automated check.
- **Q13: product queries respect catalog visibility** (WooCommerce plugins). A `WP_Query` or `get_posts()` on `product` doesn't hide products set to "Catalog visibility: Hidden". Exclude the `exclude-from-catalog` term of `product_visibility` (`exclude-from-search` while searching), or use `wc_get_products()` with `'visibility' => 'catalog'`. Check search results and pagination totals too. Precheck flags product queries with no visibility filter (`Q13`).

## 11. Replying to the email

IDs: U3, U4.

- **U4: fix every occurrence.** The email shows examples only. For each heading, map it to its IDs (`checklist.md`), search the whole plugin for the same pattern, and fix every case. Then test the new zip on a clean site with `WP_DEBUG` on (`yayh wporg site`). An update that fixes only the examples gets another round.
- **U3: a short reply in the same thread.** Only context the reviewer can't see in the code: the new slug if the name changed, ownership proof, a one-line reason for each public REST route or nopriv handler you kept, real questions. No list of changes and no thanks paragraph. When a finding is a false positive, or a name belongs to another plugin, say so and quote the line. AI-detected findings can be wrong: read the code, then fix it or explain why not.
