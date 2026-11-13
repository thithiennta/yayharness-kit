# WordPress.org plugin review rules: full reference

Compiled 2026-10-29 from the primary sources listed in section 0. **[VERIFIED]** means read from the source; **[UNVERIFIED]** means inferred. If a rule matters to a decision and looks stale, re-check the source URL.

Contents:
- 0. Sources
- 1. The 18 guidelines: what reviewers flag
- 2. Common issues (the text review emails quote)
  - 2.1 Security: sanitize, escape, files, libraries, WPDB, HEREDOC, direct access
  - 2.2 Compatibility: prefixing, PHP settings, main file, headers, readme, license, stable tag, HTTP API, enqueue, core libraries, i18n
  - 2.3 Compliance: changing plugins, updaters, external services, folders, file types, GPL, source for minified code, composer
  - 2.4 Other frequent items: capabilities, nonces, redirects, unserialize, register_setting, uninstall, blocks, AI, React 19
- 3. Plugin Check (PCP): CLI flags, check slugs, PHPCS sniffs, trademark list
- 4. WPCS / PHPCS setup
- 5. readme.txt and plugin header rules
- 6. Process changes 2024 to 2026 and the submission/reply workflow
- 7. Unverified items

## 0. Primary sources and their dates

| Source | URL | Last updated |
|---|---|---|
| Detailed Plugin Guidelines | https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/ | 2026-03-11 (the body also contains a stale "Last Updated: March 15, 2024" line) |
| Common issues | https://developer.wordpress.org/plugins/wordpress-org/common-issues/ | first published 2024-08-03, last updated 2026-03-20 |
| Plugin Developer FAQ | https://developer.wordpress.org/plugins/wordpress-org/plugin-developer-faq/ | 2026-09-01 |
| Plugin Readmes (readme.txt) | https://developer.wordpress.org/plugins/wordpress-org/how-your-readme-txt-works/ | 2026-03-11 |
| Sample readme | https://wordpress.org/plugins/readme.txt | n/a |
| Header Requirements | https://developer.wordpress.org/plugins/plugin-basics/header-requirements/ | 2026-03-11 |
| Reviewer checklist (internal handbook) | https://make.wordpress.org/plugins/handbook/performing-reviews/review-checklist/ | 2026-10-14 |
| Plugin Check repo (trunk, latest release 2.1.0, 2026-08-16) | https://github.com/WordPress/plugin-check (docs/CLI.md, docs/checks.md, docs/ai-features.md, source) | cloned 2026-10-29 |
| WPCS (latest release 3.4.1, 2026-07-27) | https://github.com/WordPress/WordPress-Coding-Standards | n/a |
| Make/Plugins blog | https://make.wordpress.org/plugins/ | posts through 2026-10-02 |
| Partner pre-submission checklist (the S/G/B/Q/R/T/U IDs in `checklist.md`) | `YayCommerce/YayAutomation@develop:.claude/docs/context-wporg-release-checklist.md` | read 2026-11-13 |

---

## 1. The 18 Detailed Plugin Guidelines: what reviewers actually flag

Source: https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/ [VERIFIED]. Practical notes draw on Common Issues and the reviewer checklist.

1. **GPL-compatible license.** All code, data and images, including bundled third-party material, must be GPL or GPL-compatible. GPLv2-or-later is recommended. *Flagged:* missing license, a license in the readme that differs from the header, bundled non-GPL libraries, fonts or images, and "premium" libraries that forbid redistribution (for example some commercial JS libraries or pro builds of frameworks).
2. **Developer is responsible for every file.** This covers third-party libraries and API terms of service. Unverifiable libraries or APIs are not allowed, and deliberately circumventing the guidelines is prohibited. *Flagged:* libraries of unknown origin, and use of an API against its ToS.
3. **A stable version must be available from the directory.** Distributing elsewhere while leaving the WordPress.org copy stale can lead to removal.
4. **Code must be (mostly) human-readable.** Obfuscation, packers and mangled names are banned. Source and build tools must be public, either bundled or linked from the readme. *Flagged:* minified JS/CSS with no source or readme link, ionCube/Zend Guard/SourceGuardian (a PCP error), `eval`/`base64_decode`-packed code, and no build instructions.
5. **No trialware.** No locked features, time or quota limits, or sandbox-only API access. Upselling is fine within guideline 11, and premium code belongs in a separate add-on hosted elsewhere. *Flagged:* `if ( ! $is_pro ) return;` gates around code that ships in the plugin, and license-key checks that unlock bundled code.
6. **SaaS is allowed** when the external service provides substantial functionality and is documented in the readme with a ToS link. *Not allowed:* a service that only validates license keys, functionality moved off the plugin to fake a service, and storefront-only plugins.
7. **No tracking without explicit opt-in consent.** Any contact with an external server needs authorized opt-in, such as a registration or a settings checkbox, and must be documented in the readme, ideally with a privacy policy. *Flagged:* analytics or "usage stats" pings on activation, telemetry SDKs enabled by default, remote blocklists, and ad networks.
8. **No executable code from third parties.** No updates or installs from servers other than WordPress.org, no installing the premium version of the same plugin, no third-party CDN assets other than fonts, and no iframes connecting admin pages to a service. *Flagged:* custom updaters, `Update URI`, downloading zips to install plugins, JS/CSS loaded from CDNs, and remote JS execution.
9. **Nothing illegal, dishonest or morally offensive.** Covers SEO manipulation, fake or paid reviews, sockpuppets, claims that a plugin guarantees legal compliance (GDPR, ADA), crypto-mining, and using users' resources without permission.
10. **Credits and "powered by" links must be opt-in.** They must be off by default, and the plugin must work without them.
11. **Don't hijack the admin dashboard.** Upsell notices must be limited, contextual and dismissible, and error notices must explain the fix and disappear once it is resolved. No dashboard ads, and no referral tracking through ads. *Flagged:* non-dismissible site-wide notices, notices on every admin page, review nags, external URLs in top-level admin menus (PCP `external_admin_menu_links`), and dashboard widgets with ads.
12. **No spam in public pages (readme, translations).** No more than 5 tags, no competitor names as tags, no keyword stuffing, and no undisclosed or cloaked affiliate links. *Flagged:* readmes stuffed with keywords, tags naming competitors, and links to 5-star reviews (PCP `five_star_reviews_detected`).
13. **Use WordPress's bundled libraries.** Don't ship jQuery, SimplePie, PHPMailer, PHPass, Atom lib, and similar. PCP reports `library_core_files`.
14. **Avoid frequent SVN commits.** SVN is a release repository: commit only deployable code with descriptive messages.
15. **Increment version numbers on every release.** The trunk readme Stable tag must match the current version.
16. **Submit a complete plugin.** No placeholders and no name reservations. Unused slugs from approved plugins may be reassigned.
17. **Respect trademarks and project names.** A trademark or another project's name cannot be the sole or initial term of a slug unless you are its legal owner or representative. Use "Dancing Sloths for Superbox", not "superbox-dancing-sloths".
18. **WordPress.org may update the guidelines, remove plugins, grant exceptions or modify code** for public safety. Developers must keep contact emails current, and **auto-replies that route review emails to a support or ticket system are not allowed**.

Extra items from the reviewer checklist that reviewers apply (https://make.wordpress.org/plugins/handbook/performing-reviews/review-checklist/) [VERIFIED]:
- **Subject matter generally rejected:** black-hat SEO, auto-posting and content spinners; frameworks, boilerplates and libraries; plugins that require editing a theme or another plugin; storefront-only plugins; duplicating core without meaningful improvement; and letting users paste raw JS/CSS/HTML/PHP without sanitization. The FAQ also lists **new plugins that allow arbitrary code insertion or execution**, plugins that only install other plugins, and copies of existing work.
- **Plugin must not:** bundle themes or other whole plugins; call `wp-load.php` directly; save content in the plugin folder (it is wiped on update); use URL shorteners; or produce PHP/JS errors or notices with `WP_DEBUG` on.
- **Allowed:** upsells on the plugin's own settings screen or plugin-list link, UTM links to your own site, and fonts loaded remotely.
- **Readme:** if no support is provided, say so clearly.

---

## 2. Common Issues: every item (the text of review emails)

Source: https://developer.wordpress.org/plugins/wordpress-org/common-issues/ [VERIFIED, read in full]. The page itself says it contains "excerpts from the team's email messages" and is not exhaustive. Item headings below match the page's anchors, so a skill can link to `#<anchor>`.

### 2.1 Security

**Sanitize** ("Input data must be Sanitized, Validated, and Escaped on output")
- *Trigger:* `$_POST`, `$_GET`, `$_REQUEST`, `$_FILES` (and in practice `$_SERVER`, `$_COOKIE`) used without sanitizing or validating.
- *Wanted:* "Sanitize early, Escape late, Always validate," using the function for the context: `sanitize_email()` for email, `wp_kses_post()` for HTML, and so on. Validate allowed values, for example by rejecting 'dog' when a number is expected.

**Sanitize: Confusion about escape and sanitize functions**
- *Trigger:* `esc_*` functions used to sanitize input. They are filterable and meant for output.
- *Wanted:* sanitize on input, then escape on output.
```php
echo esc_html( sanitize_text_field( $_POST['example'] ) );
```

**Sanitize: Using filter functions to sanitize**
- *Trigger:* `filter_var`, `filter_var_array`, `filter_input` or `filter_input_array` called without a filter, which defaults to `FILTER_DEFAULT` and does not sanitize. `FILTER_UNSAFE_RAW` gets the same treatment [UNVERIFIED, but follows from the rule].
```php
$post_id = filter_input( INPUT_GET, 'post_id', FILTER_SANITIZE_NUMBER_INT );
```

**Sanitize: Nonces**
- *Trigger:* raw `$_POST['nonce']` passed to `wp_verify_nonce()`. The function is pluggable, so its input must be clean.
```php
if ( ! isset( $_POST['prefix_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['prefix_nonce'] ) ), 'prefix_nonce' ) )
```

**Processing the whole input**
- *Trigger:* looping over or sanitizing the entire `$_POST`, `$_REQUEST` or `$_GET` array, for example `foreach ( $_POST as $k => $v )` or `map_deep( $_POST, ... )`.
- *Wanted:* read only the specific keys the plugin needs.

**Escape** ("Variables and options must be escaped when echo'd")
- *Trigger:* any echoed `$variable`, option or generated data that is not escaped at output time. This includes options that were sanitized on save. Escape late, not when building the variable.
- Also: echoing JSON is usually wrong. Return it instead (APIs).

**Escape: Use of esc_url_raw**
- *Trigger:* `esc_url_raw()` used for output. It is a sanitizer, like `sanitize_url`, for the database and redirects.
- *Wanted:* `esc_url()` for output.

**Escape: Use of __**
- *Trigger:* `echo __( ... )`.
```php
<h2><?php echo esc_html__( 'Settings page', 'plugin-slug' ); ?></h2>
<h2><?php echo esc_html( __( 'Settings page', 'plugin-slug' ) ); ?></h2>
```

**Escape: Use of _e and _ex**
- *Trigger:* `_e()` or `_ex()`, which output translations unescaped.
```php
<h2><?php esc_html_e( 'Settings page', 'plugin-slug' ); ?></h2>
<h2><?php echo esc_html( __( 'Settings page', 'plugin-slug' ) ); ?></h2>
<h2><?php echo esc_html( _x( 'Settings page', 'Settings page title', 'plugin-slug' ) ); ?></h2>
```

**Escape: Use json_encode**
- *Trigger:* `echo json_encode(...)`, or flags passed to the second parameter that disable escaping, such as `JSON_UNESCAPED_SLASHES` or `JSON_UNESCAPED_UNICODE` in an HTML context [flag examples are UNVERIFIED; the page only says "options passed on the second parameter"].
```php
echo wp_json_encode( $array_or_object );
```

**Escape: HTML**
- *Trigger:* `esc_html()` used on content that is meant to contain HTML, which strips or encodes the tags.
```php
echo wp_kses_post( $html_content );
echo wp_kses( $html_content, array( 'a', 'div', 'span' ) ); // as given on the page; real usage is array( 'a' => array( 'href' => array() ), ... )
```

**Escape: Using sanitizing functions**
- *Trigger:* `echo sanitize_text_field( $x )` or similar used as output escaping.
- *Wanted:* `echo esc_html( sanitize_text_field( $_POST['example'] ) );`

**Files: Use the WordPress file uploader**
- *Trigger:* `move_uploaded_file()`, which is also a PCP forbidden-function error.
- *Wanted:* `wp_handle_upload()` (or `media_handle_upload()`).

**Files: Unfiltered uploads**
- *Trigger:* any reference to `ALLOW_UNFILTERED_UPLOADS`, even in a conditional. PCP reports `allow_unfiltered_uploads_detected` as an error.
- *Wanted:* add specific safe MIME types with the `upload_mimes` filter (see `wp_get_mime_types()`).

**Files: Calling files remotely**
- *Trigger:* JS, CSS, images or other scripts loaded from your own servers or a CDN (Google, MaxCDN, jquery.com, cdnjs, jsdelivr, unpkg...). Iframes of help docs, and images from your own domain, also count.
- *Allowed:* Google Fonts or other GPL-compatible font CDNs; API calls to a service (Akismet-style); offloading comments (Disqus-style); and oEmbed (YouTube, Twitter).
- *Wanted:* bundle files locally. Use core copies of anything core ships. If the plugin really is a service, the readme must document the service, the servers called, and whether an account is needed.

**Libraries: Using development versions**
- *Trigger:* beta, alpha or dev builds of libraries. *Wanted:* the stable release, or an explanation of why the beta is technically needed.

**Libraries: Not maintained**
- *Trigger:* abandoned libraries, which are "no longer accepted." *Wanted:* a maintained alternative.

**Libraries: Out of Date**
- *Trigger:* a bundled third-party library that is not the latest stable version. *Wanted:* upgrade it.

**WPDB: Unsafe SQL calls**
- *Trigger:* SQL built with variables or concatenation instead of `$wpdb->prepare()`.
- *Wanted:* `$wpdb` methods with `prepare()` placeholders (`%s`, `%d`, `%f`, and `%i` for identifiers on WP 6.2+).

**WPDB: Arrays of placeholders**
```php
$wordcamp_id_placeholders = implode( ', ', array_fill( 0, count( $wordcamp_ids ), '%d' ) );
$prepare_values = array_merge( array( $new_status ), $wordcamp_ids );
$wpdb->query( $wpdb->prepare( "
    UPDATE `$table_name`
    SET `post_status` = %s
    WHERE ID IN ( $wordcamp_id_placeholders )",
    $prepare_values
) );
```

**Not use HEREDOC-NOWDOC**
- *Trigger:* any `<<<EOT` or `<<<'EOT'`. This is not permitted because sniffers can't see unescaped output inside it. PCP sniff `PluginCheck.CodeAnalysis.Heredoc` reports an error.

**Direct file access**
- *Trigger:* PHP files with executable code at file scope (function calls, instantiation, includes) that lack an ABSPATH guard.
```php
if ( ! defined( 'ABSPATH' ) ) exit; // Exit if accessed directly
```

### 2.2 Compatibility

**Prefixing** ("Generic function/class/define/namespace/option names")
- *Trigger:* unprefixed or generic functions, classes, namespaces, `define`s, option names, transients, globals, hooks, and so on. Two- or three-letter prefixes are no longer accepted. Names starting with `__`, `wp_` or `_` are reserved; they are fine inside classes but not as standalone functions. Wrapping all your functions or classes in `if ( ! function_exists() )` is also flagged; it is reserved for shared libraries.
- *Good:* `function ecpt_save_post()`, `class ECPT_Admin{}`, `namespace ECPT;`, `update_option( 'ecpt_settings', $settings );`, `define( 'ECPT_LICENSE', true );`, `global $ecpt_options;`

**PHP: Do not use Short Tags**
- *Trigger:* `<?` short open tags. `<?=` is also discouraged because sniffers miss unescaped output in it; PCP reports `Generic.PHP.DisallowShortOpenTag.EchoFound` at severity 7.
- *Wanted:* `<?php echo esc_html( $x ); ?>`

**PHP: Changing Settings globally**
- *Trigger:* `ini_set( 'memory_limit', '-1' )`, `set_time_limit()` and the like run globally, for example on `init` or in a constructor.
- *Wanted:* scope them only to the exact function that needs them, or remove them. PCP flags `ini_set`, `ini_alter`, `set_time_limit` and `dl` through `Squiz.PHP.DiscouragedFunctions`.

**PHP: Setting a default timezone**
- *Trigger:* `date_default_timezone_set()`, even when set to the site's timezone. WordPress expects UTC.
- *Wanted:* `wp_date()`, `current_time()`, `wp_timezone()`, `DateTimeImmutable` with `wp_timezone()` [alternatives are UNVERIFIED on this page].

**PHP: Error reporting**
- *Trigger:* `error_reporting()` (and `ini_set('display_errors', ...)`) in production code. The PCP check is `php_error_reporting`.

**Plugin standards: Main file convention**
- *Trigger:* the main file (the one with the headers) is not named `<slug>.php`, or has a generic name such as `plugin.php`, `main.php` or `index.php`.
- *Good:* slug `ecpt-social-manager` with main file `ecpt-social-manager/ecpt-social-manager.php`.

**Plugin standards: Incomplete Headers**
- *Trigger:* missing or incomplete plugin headers, or headers in more than one file.
- *Wanted:* complete headers in the main file only (see section 5).

**Plugin standards: Incomplete Readme**
- *Trigger:* missing or incomplete readme; only a `readme.md`; or a readme that fails the validator. The requirement is stricter for first plugins, plugins with dependencies, and plugins that call external services.
- *Wanted:* a `readme.txt` with headers, a proper description, and how-to-use documentation, based on https://wordpress.org/plugins/readme.txt. Since July 2025 it must also be in English.

**Plugin standards: No GPL-compatible license declared**
- *Trigger:* no License in the readme or plugin header. *Wanted:* declare it in both. All bundled code and assets must be GPL-compatible (see gnu.org license list).

**Plugin standards: Incorrect Stable Tag**
- *Trigger:* readme `Stable tag` differs from the header `Version`, or is set to `trunk`, which is prohibited for new plugins.
- *Wanted:* identical values (SemVer recommended), and tag each release.

**Plugin standards: Declared license mismatched**
- *Trigger:* the readme `License` differs from the header `License`. *Wanted:* the same single license in both. Third-party code under other GPL-compatible licenses must be documented.

**Use HTTP API** ("Using CURL Instead of HTTP API")
- *Trigger:* `curl_init`, `curl_exec` and similar in the plugin's own code. Third-party vendor libraries are allowed.
- *Wanted:* `wp_remote_get()`, `wp_remote_post()`, `wp_remote_request()`, `wp_safe_remote_*()`. Set cURL options through the `http_api_curl` hook. PCP also errors on `WordPress.WP.AlternativeFunctions` (curl, `file_get_contents` on URLs, `json_encode`, `parse_url`, `rand`, `strip_tags`, `fopen`/`fwrite` file ops -> WP_Filesystem, etc. [function list is WPCS standard, UNVERIFIED per version]).

**Use wp_enqueue commands**
- *Trigger:* `<script>`, `<script src>`, `<style>` or `<link rel="stylesheet">` printed directly. WPCS sniff `WordPress.WP.EnqueuedResources` reports an error.
- *Wanted:* `wp_register_script()`/`wp_enqueue_script()` and `wp_add_inline_script()`; `wp_register_style()`/`wp_enqueue_style()` and `wp_add_inline_style()`; on admin pages, `admin_enqueue_scripts` (also `admin_print_scripts`, `admin_print_styles`). Since WP 5.7, attributes go through `wp_get_script_tag()`/`wp_print_inline_script_tag()` and the related filters.

**Including Libraries Already In Core**
- *Trigger:* bundling jQuery, jQuery UI, Atom lib, SimplePie, PHPMailer, PHPass, and the like. PCP reports `library_core_files` as an error.
- *Wanted:* use core's registered handles. Only add-on files that core does not ship may be bundled. If code fails with core jQuery it is "most likely a noConflict issue".

**Internationalization: Using variables**
- *Trigger:* a variable, constant or function call as the text, context or text domain of a gettext function.
```php
esc_html__( $greetings, 'plugin-slug' );               // bad
esc_html__( 'Hello, how are you?', $plugin_slug );     // bad
esc_html__( 'Hello, how are you?', 'plugin-slug' );    // good
printf(
    /* translators: %s: First name of the user */
    esc_html__( 'Hello %s, how are you?', 'plugin-slug' ),
    esc_html( $user_firstname )
);
```
- The text domain must equal the plugin slug.

### 2.3 Compliance

**Changing Active Plugins**
- *Trigger:* `activate_plugin()`/`deactivate_plugins()` on other plugins, or interfering with the user's activation or deactivation.
- *Allowed:* deactivating your own plugin when a dependency is missing. Prefer the WP 6.5 `Requires Plugins` header; a custom check is fine as a fallback.

**Update checker** ("Including An Update Checker / Changing Updates functionality")
- *Trigger:* phoning home for updates (plugin-update-checker, EDD SL updater...), `Update URI` header, filtering `pre_set_site_transient_update_plugins`/`site_transient_update_plugins`/`auto_update_plugin` etc. PCP: `plugin_updater_detected` is an error and `update_modification_detected` is a warning.
- *Wanted:* remove it. WordPress.org serves updates.

**Undocumented 3rd party** ("Undocumented use of a 3rd Party or external service")
- *Trigger:* any external HTTP call (APIs, your own server, CDNs, analytics) that the readme does not document. This applies even when you are the third party.
- *Wanted:* a readme section, commonly titled `== External services ==` [the heading convention is UNVERIFIED but widely used], that for **each** service:
  1. says the plugin relies on the service and under what circumstances, including what data is sent and when;
  2. links to the service;
  3. links to its terms of use and privacy policy.

**Included Unneeded Folders**
- *Trigger:* dev tools, unneeded vendor folders (bower, node_modules, grunt), demos, unit tests. PCP also warns on `.github`, AI tool directories, and unexpected markdown files.
- *Wanted:* remove them, but **keep `composer.json`** and other config files that let people rebuild. Linking to readable source from the readme is fine.

**Not permitted files**
- *Trigger:* files that are not normal plugin types (php, js, css, txt, md, images such as png/svg/jpg, json, xml): for example `.zip`, `.phar`, `.exe`, `.sh`, hidden files and VCS directories.
- **Including code from a "premium" source:** premium libraries whose license forbids inclusion in free plugins must be removed.

**GPL: Non-GPL compatible Code Included**
- *Wanted:* remove the code and replace it with GPL-compatible alternatives.

**GPL: No publicly documented resource** ("No publicly documented resource for your compressed content")
- *Trigger:* minified or compiled JS/CSS (webpack, Gutenberg build) with no human-readable source.
- *Wanted:* ship the source (for example `src/`) **or** link a public repository **in the readme**; a link only in the code is not enough. Include build instructions (`npm install && npm run build`).

**GPL: Using composer but no composer.json file**
- *Trigger:* a `vendor/` directory built by Composer without `composer.json`. PCP reports `missing_composer_json_file` as a warning.
- *Wanted:* include `composer.json`, even if it is only used in development.

**Saving data in the plugin folder.** PCP's `write_file` check links to `common-issues/#saving-data-in-the-plugin-folder`, but **that anchor does not exist on the current page** [VERIFIED absent]. The rule comes from the reviewer checklist: "Don't save content in the plugin folder". Use `wp_upload_dir()` or the database.

### 2.4 Other things review emails commonly cite that are not on the Common Issues page

These come from the reviewer checklist, the PCP checks and the Sept 2026 security post:
- **Capability checks:** "A nonce alone is not authorization." REST routes need a real `permission_callback`, and `__return_true` only for genuinely public data. AJAX and admin-post handlers need `current_user_can()`. `wp_ajax_nopriv_` handlers get extra scrutiny.
- **Nonces** on every state-changing form, AJAX call or link (`check_admin_referer`, `check_ajax_referer`, `wp_verify_nonce`). The PCP sniff `PluginCheck.Security.VerifyNonce` errors on unsafe patterns, such as a `wp_verify_nonce()` result that is not acted on, or `isset() && wp_verify_nonce()` logic that lets execution continue when the nonce is missing.
- **Redirects:** use `wp_safe_redirect()` plus `exit`. `wp_redirect()` with user input is warned by `safe_redirect`.
- **`unserialize()` on request data or remote responses**, file paths, includes or deletes built from request data, and `eval`, `create_function`, `passthru`, `proc_open`, `str_rot13` (PCP forbidden-function errors). Backticks and `goto` are also errors.
- **`register_setting()` without `sanitize_callback`** (PCP `setting_sanitization`, error).
- **Localhost or 127.0.0.1 URLs** left in code (PCP `localhost`, error). URL shorteners (`ShortURL`, warning).
- **uninstall.php without the `WP_UNINSTALL_PLUGIN` check** (PCP `uninstall_missing_constant_check`, error).
- **Raster images as admin menu icons** (warning). Use a dashicon or an SVG data URI.
- **Blocks:** `block.json` `apiVersion` below 3 is now an error (`block_api_version_too_low`, for WP 7.0 iframe editor compatibility).
- **AI integrations:** PCP warns (`ai_provider`) when a plugin calls OpenAI, Anthropic or other providers directly instead of the WordPress AI Client. Reading AI connector API keys directly is an error (`DirectAIConnectorAPIKeyAccess`).
- **React 19 incompatibilities** (`react_usage`): errors for removed APIs such as `ReactDOM.render`.
- **Internal WordPress functions** such as `_get_plugin_data_markup_translate` and `do_shortcode_tag` are forbidden (errors).

### 2.5 Items seen in real 2026 review emails (AUTOPREREVIEW scanner)

The 2026 first-round emails are generated by the AI pre-review scanner. Their sections are always, in this order: "Have you read the guidelines…" (auto-flagged guidelines), "Is the name… distinctive… trademarks", "Are you the rightful owner", "Have you checked for common technical issues?", "Other details". Every item below was cited in a real email:

- **Auto-flagged guidelines (section 1).** The scanner lists guidelines it *suspects*: GPL (1, 4), locked functionality (1, 5, 9, 6 for SaaS), public source for built files (1, 4), dashboard hijacking (11). They are "we will verify this", but each one maps to a concrete finding later in the email, so treat each as a finding to clear.
- **Third-party *project* names, not just trademarks.** "Shadcn" (a UI library) was flagged although it is in no trademark list. Any distinctive word at the start of the name that names someone else's project, library, framework, theme or service is treated like a trademark. Accepted pattern: `<Own brand> <what it does> for <Project>` (e.g. "YayCommerce Blocks for Shadcn UI"). The check also covers the account username/display name, contributors, Plugin URI/domain, icons and banners.
- **Ownership.** The team compares the names and domains in the plugin (Plugin Name, Plugin URI, Author URI, contributors) with the submitting account's email domain. A Plugin URI on a different domain (e.g. `wpshadcn.com` while the account is `@yaycommerce.com`) triggers "Are you the rightful owner?". Ways to clear it: DNS TXT record `wordpressorg-<username>-verification` at the domain root; account email on that domain; transfer to the right account (never resubmit from another account); rename; or explain in the reply (same company, existing approved plugins on the account).
- **`Tested up to` in the plugin header.** "Please declare Tested up to only in your readme file", even when the two values match.
- **`printf( __( … ) )`.** `__()` doesn't escape. Use `printf( esc_html__( … ) )`, or `wp_kses()` when the translated string contains `%1$s…%2$s` link placeholders, and escape the arguments (`esc_url( admin_url( … ) )`).
- **Every `__return_true` REST route is listed** ("Possible cases found"), including legitimate public form submissions and pings. Fix the ones that need a capability check, and justify the rest in the reply.
- **ABSPATH guard in block pattern files** (`patterns/*.php`) that contain executable PHP (e.g. `<?php echo esc_html( gmdate( 'Y' ) ); ?>`).
- **Block comment markup built by hand**: `<!-- wp:ns/block-<?php echo $slug; ?> <?php echo wp_json_encode( $attrs, JSON_HEX_TAG | JSON_UNESCAPED_SLASHES ); ?> /-->`. Two findings: the raw slug, and `wp_json_encode` with flags ("make sure you are not avoiding escaping with the options passed on the second parameter"). Wanted: validate the slug against an allow-list (`sanitize_key()` + `in_array()`), and build the markup with core's `get_comment_delimited_block_content( $name, $attrs, $inner )` / `serialize_block_attributes()` / `serialize_block()`.
- **Shortcode / filter callbacks that return HTML** ("Callback calls to a function/method whose return values are output must be properly escaped"). Shortcode attributes are user input. Sanitize them, and escape what the callback returns.
- **Updater inside scoped vendor code**: `vendor-prefixed/src/License/EDD_SL_Plugin_Updater.php` was reported as "Including an update checker". Scoped and vendor copies count.
- **Unclosed `ob_start()`**: opening a buffer in one hook callback and closing it in another, or a filter/early return that can skip the close. Wanted: open and close in the same function. For whole-page changes, WP 6.9 adds a standard template enhancement output buffer.
- **`load_plugin_textdomain()`**: not needed for directory plugins since WP 4.6. Remove it, or call it on `init` if older WP is supported.
- **Built files without matching source**: files in `assets/dist/` were reported one by one ("… out of a total of 25 incidences"), including a minified editor script that contained an `isPro` check. The scanner reads built JS for trialware too. YayCheckout (2026-11) got 59 such incidences. Yay's fix: a `== Source Code ==` readme section linking the public GitHub repo, with a built → source folder map and the build steps, rather than shipping the source in the zip.
- **Arbitrary code insertion, CSS included** (YayCheckout, 2026-11): a `custom_css` setting was reported as "Attempting to process custom CSS/JS/PHP / Allowing arbitrary script insertion". The team points to WordPress's own Additional CSS editor. Remove the setting.
- **"Use wp_enqueue commands"**: a hard-coded `<style id="…">` printed by an admin class (`LayoutEditorEmbed.php`) was reported. Use `wp_add_inline_style()` on a registered handle.
- **A `phpcs:ignore` with a justification still fails**: `echo '<span>' . $price . '</span>'; // phpcs:ignore … -- wc_price() HTML, an escaped tax label, and what the rate-label filter appended`. The scanner traced `$price` back to a filter-controlled suffix. Wrap the assembled HTML in `wp_kses_post()` (or `wp_kses()` with an allow-list) at the echo.
- **Your own domain is an external service**: `wp_remote_get( 'https://yaycommerce.com/yaycheckout/compatibility.json' )` needed an `== External services ==` entry with what is sent, when, and Terms and Privacy links, which "we will check… in the next review".
- **`render_block` filters count as output callbacks**: a `render_block` callback that ran shortcodes and returned their HTML was reported under "Callback calls…". Escape or `wp_kses_post()` what it returns.
- **Every first-round email links a Playground blueprint** ("Test it on Playground") for the exact zip submitted, with Plugin Check preloaded (`type=pcp`). Check that the zip activates there before uploading.

---

## 3. Plugin Check (PCP)

Sources: https://github.com/WordPress/plugin-check (`docs/CLI.md`, `docs/checks.md`, `docs/ai-features.md`, `includes/Checker/Default_Check_Repository.php`, `phpcs-rulesets/plugin-check.ruleset.xml`, and the source of each check) [VERIFIED, trunk 2026-10-29; latest tag 2.1.0, 2026-08-16]. Requires PHP 7.4+. AI features require WordPress 7.0+.

### 3.1 Install and run
```bash
wp plugin install plugin-check --activate
wp plugin check my-plugin                        # table output, all non-experimental checks, mode=new
wp plugin check my-plugin --format=json          # machine-readable
wp plugin check my-plugin --format=csv --fields=code,type,severity,message
wp plugin check my-plugin --categories=plugin_repo          # what the upload gate runs
wp plugin check my-plugin --categories=plugin_repo,security
wp plugin check my-plugin --checks=late_escaping,prefixing
wp plugin check my-plugin --exclude-checks=enqueued_scripts_size,enqueued_styles_size
wp plugin check my-plugin --ignore-codes=missing_composer_json_file
wp plugin check my-plugin --include-experimental
wp plugin check my-plugin --severity=7           # drop results below severity 7
wp plugin check my-plugin --mode=update          # softer rules for already-approved plugins
wp plugin check my-plugin --slug=my-real-slug    # when the folder name != intended wp.org slug
wp plugin check my-plugin --use-pcpignore        # local/CI only; wp.org never applies .pcpignore
wp plugin check my-plugin --ai --ai-model=anthropic::<model>   # AI false-positive triage, WP 7.0+
wp plugin list-checks [--format=json] [--include-experimental] [--categories=...]
wp plugin list-check-categories
```
You can also check a zip or a path, for example `wp plugin check /path/to/plugin.zip` or a URL [UNVERIFIED in the current CLI.md, which only says "Plugin name"; earlier versions accepted a path or URL].

**All flags** (from docs/CLI.md):
- Selecting checks: `<plugin>`, `--checks`, `--exclude-checks` (applied after `--checks`), `--ignore-codes` (result codes, not check slugs), `--include-experimental`.
- Output: `--format=table|csv|json|ctrf|strict-table|strict-csv|strict-json|strict-ctrf`, `--fields`, `--categories`, `--ignore-warnings`, `--ignore-errors`.
- Severity: `--severity`, `--error-severity`, `--warning-severity`, `--include-low-severity-errors`, `--include-low-severity-warnings`.
- Files: `--exclude-directories`, `--exclude-files`. Defaults already exclude `.git`, `vendor`, `vendor_prefixed`, `vendor-prefixed` and `node_modules`. Note that WordPress.org does not exclude vendor from every check.
- Other: `--use-pcpignore`, `--slug`, `--mode=new|update`, `--ai`, `--ai-model`.

The `strict-*` formats aren't documented in detail; my reading is that they promote warnings or keep everything for CI [UNVERIFIED]. `ctrf` is the Common Test Report Format JSON.

**Results:** each has a type (`ERROR` or `WARNING`) and a severity from 1 to 10 (default 5). Use check slugs with `--checks`/`--exclude-checks`, and result codes with `--ignore-codes`.

**Modes:** `new` is the default and matches submission. `update` downgrades some findings: an outdated "Tested up to" becomes a warning instead of an error, `plugin_content` severity drops from 7 to 5, and the unsupported-plugin-name and nonexistent Domain Path checks are skipped.

**CI:** the GitHub Action `wordpress/plugin-check-action` (recommended by the Plugins Team).

**Categories:** `general`, `plugin_repo`, `security`, `performance`, `accessibility` [the last is UNVERIFIED; no current check uses it].

### 3.2 Check slugs (all 36 registered in trunk; none currently marked experimental)

The type column is taken from the source. "PHPCS" means the type comes from the sniff, with WPCS defaults unless overridden.

| Slug | Category | What it catches | Type / notable result codes |
|---|---|---|---|
| `i18n_usage` | general, plugin_repo | `WordPress.WP.I18n` with text_domain = slug: wrong or missing text domain, non-literal strings, missing translators comments, placeholders | PHPCS. Mostly ERROR, e.g. `WordPress.WP.I18n.TextDomainMismatch`, `NonSingularStringLiteralText`. Missing translators comment is a WARNING |
| `php_error_reporting` | general | `error_reporting()` and `ini_set('display_errors')` calls (`PluginCheck.CodeAnalysis.PHPErrorReporting`) | PHPCS (DirectErrorReportingCall, IniDirective) |
| `ai_provider` | general | direct integration with an AI provider instead of the WP AI Client | WARNING |
| `react_usage` | general, plugin_repo | React APIs removed in React 19 | ERROR / WARNING (`react_removed_api`) |
| `code_obfuscation` | plugin_repo | ionCube, Zend Guard, Source Guardian | ERROR sev 7 `obfuscated_code_detected` |
| `plugin_content` | plugin_repo | links to 5-star reviews; `block.json` apiVersion < 3 | ERROR `five_star_reviews_detected`, `block_api_version_too_low` |
| `file_type` | plugin_repo | compressed files (zip etc.), `.phar`, VCS dirs, hidden files, application files (`a bin bpk deploy dist distz dmg dms dump elc exe iso lha lrf lzh o obj phar pkg sh so`), bad file names, case-colliding files or folders, core library copies, composer dir without composer.json, AI dirs (`.cursor .claude .aider .continue .windsurf .ai`), `.github`, markdown in root other than `README.md, readme.txt, LICENSE, LICENSE.md, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md` | ERROR: `compressed_files`, `phar_files`, `vcs_present`, `hidden_files`, `application_detected`, `badly_named_files`, `case_sensitive_folders`, `case_sensitive_files`, `library_core_files`. WARNING: `missing_composer_json_file`, `ai_instruction_directory`, `github_directory`, `unexpected_markdown_file` |
| `plugin_header_fields` | plugin_repo | see section 5 | mostly ERROR; `textdomain_mismatch` and the Domain Path codes are WARNING |
| `late_escaping` | security, plugin_repo | `WordPress.Security.EscapeOutput` (OutputNotEscaped, UnsafePrintingFunction e.g. `_e`, UnsafeSearchQuery, ExceptionNotEscaped) | PHPCS, ERROR |
| `safe_redirect` | security, plugin_repo | `wp_redirect()` instead of `wp_safe_redirect()` | WARNING (WPCS SafeRedirect) |
| `plugin_updater` | plugin_repo | `Update URI` header, updater libraries or classes, update-transient filters | ERROR `plugin_updater_detected`; WARNING `update_modification_detected` |
| `plugin_uninstall` | plugin_repo | `uninstall.php` without the `defined('WP_UNINSTALL_PLUGIN')` check | ERROR `uninstall_missing_constant_check` |
| `external_admin_menu_links` | plugin_repo | external URLs as top-level admin menu items | ERROR `external_admin_menu_link` |
| `menu_image_icon` | plugin_repo | PNG/JPG menu icons | WARNING `menu_image_icon` |
| `wp_functions_compatibility` | plugin_repo | WordPress functions newer than the `Requires at least` header | ERROR `wp_function_not_compatible_with_requires_wp` |
| `plugin_review_phpcs` | plugin_repo | the `plugin-review.xml` ruleset (see 3.3) | mixed |
| `direct_db_queries` | security, plugin_repo | `WordPress.DB.DirectDatabaseQuery` (DirectQuery, NoCaching, SchemaChange) | WARNING (WPCS default) |
| `direct_db` | security, plugin_repo | `PluginCheck.Security.DirectDB`: unescaped or unprepared variables in `$wpdb` queries | ERROR `UnescapedDBParameter`; some known-safe variables and query prefixes are downgraded to WARNING |
| `performant_wp_query_params` | performance | `WordPress.DB.SlowDBQuery` (meta_query, tax_query, meta_key...), VIP `WPQueryParams` (`posts_per_page => -1`, `suppress_filters`) | WARNING |
| `enqueued_scripts_in_footer` | performance | `WordPress.WP.EnqueuedResourceParameters`: no in_footer or strategy, missing version | WARNING |
| `enqueued_resources` | plugin_repo, performance | `WordPress.WP.EnqueuedResources`: hard-coded `<script>` or `<link>` | ERROR |
| `plugin_readme` | plugin_repo | see section 5 | many ERRORs |
| `localhost` | plugin_repo | `localhost` or `127.0.0.1` URLs | ERROR |
| `minified_files` | plugin_repo | minified PHP and tokenizer errors | ERROR |
| `no_unfiltered_uploads` | plugin_repo | `ALLOW_UNFILTERED_UPLOADS` | ERROR `allow_unfiltered_uploads_detected` |
| `trademarks` | plugin_repo | trademarks in the slug, name or readme name (list in 3.4) | WARNING `trademarked_term` in PCP. WordPress.org's upload scanner and the AI name check enforce harder |
| `offloading_files` | plugin_repo | assets enqueued from remote hosts, and remote `<script>`/`<link>`/`<img>` URLs | ERROR (`OffloadedContent`) |
| `write_file` | plugin_repo | writes into the plugin directory (`PluginDirectoryWrite`) | ERROR / WARNING |
| `setting_sanitization` | plugin_repo | `register_setting()` without a sanitize callback | ERROR |
| `prefixing` | plugin_repo | `WordPress.NamingConventions.PrefixAllGlobals`, with prefixes auto-derived from the slug | **WARNING sev 6** (forced in the check) |
| `enqueued_scripts_size` / `enqueued_styles_size` | performance | over 293 KB enqueued on a page (runtime) | WARNING |
| `enqueued_scripts_scope` / `enqueued_styles_scope` | performance | assets loaded on every page (runtime) | WARNING |
| `non_blocking_scripts` | performance | no async or defer loading strategy | WARNING |

The class `Security/Nonce_Verification_Check` (`PluginCheck.Security.VerifyNonce`) exists in source but is **not registered** in `Default_Check_Repository` on trunk. Its sniff may still run another way [UNVERIFIED]. The 2025 annual review lists nonce verification among PCP's new security checks.

Runtime checks (the enqueued_* size and scope checks) need an active plugin and a running site. Static checks do not.

### 3.3 Sniffs in `plugin_review_phpcs` (`phpcs-rulesets/plugin-check.ruleset.xml`)

Excludes `*/vendor/*`, `*/vendors/*`, `*/node_modules/*`, `tgm-plugin-activation`, `freemius`, `dompdf`, `cmb2`, `redux-framework`, `cherry-framework`, `titan-framework`, `guzzlehttp`, `plugin-update-checker`.

| Sniff | Type / severity in PCP |
|---|---|
| `WordPress.DB.PreparedSQL` | ERROR (WPCS); `.InterpolatedNotPrepared` downgraded to WARNING |
| `WordPress.DB.PreparedSQLPlaceholders` | ERROR (WPCS) |
| `WordPress.Security.NonceVerification` | **WARNING** |
| `WordPress.Security.ValidatedSanitizedInput` | **WARNING** |
| `Generic.PHP.BacktickOperator` | sev 7 |
| `PluginCheck.CodeAnalysis.Heredoc` | ERROR sev 7 |
| `PluginCheck.CodeAnalysis.ShortURL` | WARNING sev 6 |
| `Generic.PHP.DiscourageGoto.Found` | ERROR sev 7 |
| `WordPress.PHP.DevelopmentFunctions` (`error_log`, `var_dump`, `print_r`, `trigger_error`...) | WARNING |
| `Generic.PHP.DisallowShortOpenTag` (.Found and .EchoFound) and `DisallowAlternativePHPTags` | sev 7 |
| `WordPress.Security.PluginMenuSlug` (`__FILE__` as menu slug) | sev 6 |
| `WordPress.DB.RestrictedClasses` / `RestrictedFunctions` (`mysql_*`, `mysqli`, PDO) | sev 7 |
| `WordPress.WP.AlternativeFunctions` (curl, `file_get_contents`, `json_encode`, `parse_url`, `rand`, `strip_tags`, file system functions) | **ERROR** |
| `Generic.PHP.ForbiddenFunctions`: `move_uploaded_file, passthru, proc_open, create_function, eval, str_rot13, _cleanup_header_comment, _get_plugin_data_markup_translate, _transition_post_status, _wp_post_revision_fields, do_shortcode_tag, get_post_type_labels, wp_get_sidebars_widgets, wp_get_widget_defaults` | **ERROR sev 7** |
| `Squiz.PHP.DiscouragedFunctions`: `set_time_limit, ini_set, ini_alter, dl` | WARNING (Squiz default) |
| `WordPress.WP.DeprecatedClasses/Functions/Parameters`, `WordPress.DateTime.RestrictedFunctions` (`date_default_timezone_set`, `date()`) | WPCS defaults |
| `WordPress.WP.DiscouragedConstants` (`PLUGINDIR`, `STYLESHEETPATH`...) | ERROR sev 7 |
| `WordPress.WP.DiscouragedFunctions` (`query_posts`, `wp_reset_query`) | sev 6 |
| `WordPress.WP.DeprecatedParameterValues` | sev 7 |
| `Generic.Files.ByteOrderMark` | sev 7 |
| `PluginCheck.CodeAnalysis.RequiredFunctionParameters` | ERROR sev 7 |
| `PluginCheck.CodeAnalysis.DiscouragedFunctions` | message (type per call) |

Escape hatch: `// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- reason` is honoured by PCP. Reviewers do read these comments, and unjustified ignores get flagged [the reviewer behaviour is UNVERIFIED, but common in review emails].

### 3.4 Trademark list in PCP (`Trademarks_Check::TRADEMARK_SLUGS`, 112 entries)

A trailing `-` means the slug may not **begin** with that term. Entries without a dash are banned anywhere in the slug.

`adobe-, adsense-, advanced-custom-fields-, adwords-, akismet-, all-in-one-wp-migration, amazon-, android-, apple-, applenews-, applepay-, aws-, azon-, bbpress-, bing-, booking-com, bootstrap-, buddypress-, chatgpt-, chat-gpt-, cloudflare-, contact-form-7-, cpanel-, disqus-, divi-, dropbox-, easy-digital-downloads-, elementor-, envato-, fbook, facebook, fb-, fb-messenger, fedex-, feedburner, firefox-, fontawesome-, font-awesome-, ganalytics-, gberg, github-, givewp-, google-, googlebot-, googles-, gravity-form-, gravity-forms-, gravityforms-, gtmetrix-, gutenberg, guten-, hubspot-, ig-, insta-, instagram, internet-explorer-, ios-, jetpack-, macintosh-, macos-, mailchimp-, microsoft-, ninja-forms-, oculus, onlyfans-, only-fans-, opera-, paddle-, paypal-, pinterest-, plugin, skype-, stripe-, tiktok-, tik-tok-, trustpilot, twitch-, twitter-, tweet, ups-, usps-, vvhatsapp, vvcommerce, vva-, vvoo, wa-, webpush-vn, wh4tsapps, whatsapp, whats-app, watson, windows-, wocommerce, woocom-, woocommerce, -for-woocommerce, woocomerce, woo-commerce, woo-, wo-, wordpress, wordpess, wpress, wp (allowed but warns), wp-mail-smtp-, yandex-, yahoo-, yoast, youtube-, you-tube-`

- `woocommerce` is a "for-use exception": the slug may end in `-for-woocommerce`, as in "X for WooCommerce".
- `woo` is treated as a portmanteau.

The FAQ also bans "WordPress" and "plugin" in slugs, version numbers in slugs, and non-English letters. Workarounds such as "WuuCommerce" or "Face-Range" are rejected.

---

## 4. WordPress Coding Standards (PHPCS) via Composer

Source: https://github.com/WordPress/WordPress-Coding-Standards README [VERIFIED]; latest WPCS 3.4.1. PCP itself requires `wp-coding-standards/wpcs ^3.2` and `automattic/vipwpcs ^3`.

```bash
# project-local
composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
composer require --dev wp-coding-standards/wpcs:"^3.0"
# optional extras used by PCP / reviewers
composer require --dev automattic/vipwpcs:"^3.0" phpcompatibility/phpcompatibility-wp:"*"

# global
composer global config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
composer global require --dev wp-coding-standards/wpcs:"^3.0"

vendor/bin/phpcs -i                                   # list installed standards
vendor/bin/phpcs -ps . --standard=WordPress           # Core+Docs+Extra
vendor/bin/phpcs -ps . --standard=WordPress-Extra --extensions=php --ignore=vendor/*,node_modules/*
vendor/bin/phpcs --standard=WordPress --sniffs=WordPress.Security.EscapeOutput,WordPress.Security.NonceVerification,WordPress.Security.ValidatedSanitizedInput,WordPress.DB.PreparedSQL,WordPress.DB.PreparedSQLPlaceholders,WordPress.NamingConventions.PrefixAllGlobals,WordPress.WP.I18n,WordPress.Security.SafeRedirect,WordPress.WP.EnqueuedResources,WordPress.WP.AlternativeFunctions,WordPress.DB.DirectDatabaseQuery --runtime-set text_domain my-plugin --runtime-set prefixes my_plugin,MyPlugin --runtime-set minimum_wp_version 6.5 .
vendor/bin/phpcs --report=json ...                    # machine-readable
vendor/bin/phpcbf ...                                 # auto-fix formatting (not security)
```

Rulesets: `WordPress-Core`, `WordPress-Docs`, `WordPress-Extra` (includes Core), and `WordPress` (all three). The Security sniffs live in Extra.

Sample `phpcs.xml.dist`:
```xml
<?xml version="1.0"?>
<ruleset name="My Plugin">
  <file>.</file>
  <exclude-pattern>*/vendor/*</exclude-pattern>
  <exclude-pattern>*/node_modules/*</exclude-pattern>
  <exclude-pattern>*/build/*</exclude-pattern>
  <arg name="extensions" value="php"/>
  <arg value="ps"/>
  <rule ref="WordPress-Extra"/>
  <rule ref="WordPress.WP.I18n"><properties><property name="text_domain" type="array"><element value="my-plugin"/></property></properties></rule>
  <rule ref="WordPress.NamingConventions.PrefixAllGlobals"><properties><property name="prefixes" type="array"><element value="my_plugin"/><element value="MyPlugin"/></property></properties></rule>
  <config name="minimum_wp_version" value="6.5"/>
</ruleset>
```

Sniffs relevant to review:
- `WordPress.Security.EscapeOutput`: OutputNotEscaped, UnsafePrintingFunction (`_e`, `_ex`), ExceptionNotEscaped, UnsafeSearchQuery.
- `WordPress.Security.NonceVerification`: Missing, Recommended.
- `WordPress.Security.ValidatedSanitizedInput`: InputNotValidated (no `isset`), MissingUnslash (no `wp_unslash`), InputNotSanitized.
- `WordPress.Security.SafeRedirect` and `WordPress.Security.PluginMenuSlug`.
- `WordPress.DB.PreparedSQL` (NotPrepared, InterpolatedNotPrepared), `WordPress.DB.PreparedSQLPlaceholders`, `WordPress.DB.DirectDatabaseQuery` (DirectQuery, NoCaching, SchemaChange), `WordPress.DB.RestrictedFunctions`/`RestrictedClasses`, `WordPress.DB.SlowDBQuery`.
- `WordPress.NamingConventions.PrefixAllGlobals`: NonPrefixedFunctionFound, NonPrefixedClassFound, NonPrefixedVariableFound, NonPrefixedConstantFound, NonPrefixedHooknameFound, NonPrefixedNamespaceFound, ShortPrefixPassed (prefixes under 4 chars), DeprecatedWhitelistCommentFound.
- `WordPress.WP.I18n`: TextDomainMismatch, NonSingularStringLiteralText/Domain/Context, MissingTranslatorsComment, UnorderedPlaceholders, MissingArgDomain.
- `WordPress.WP.EnqueuedResources`, `WordPress.WP.EnqueuedResourceParameters`, `WordPress.WP.AlternativeFunctions`, `WordPress.WP.DiscouragedFunctions`/`DiscouragedConstants`, `WordPress.WP.DeprecatedFunctions`/`Classes`/`Parameters`, `WordPress.WP.GlobalVariablesOverride`.
- `WordPress.PHP.DevelopmentFunctions`, `WordPress.PHP.DiscouragedPHPFunctions` (`serialize`, `base64_decode`, `runtime_configuration`, `obfuscation`), `WordPress.PHP.RestrictedPHPFunctions`.
- `WordPress.DateTime.RestrictedFunctions` (`date_default_timezone_set`, `date`), `WordPress.DateTime.CurrentTimeTimestamp`.
- `WordPress.Security.EscapeOutput` with `customEscapingFunctions` / `customAutoEscapedFunctions` properties, for any custom escape helpers.

The sniff code names listed are standard WPCS 3.x [VERIFIED by usage in PCP for the families; individual sub-codes are from WPCS knowledge and UNVERIFIED for 3.4.1].

Tip for the skill: the WordPress.org `plugin-check` zip bundles its own `vendor/` (WPCS, VIPCS, PluginCheck sniffs). You can therefore approximate the review PHPCS run with `phpcs --standard=wp-content/plugins/plugin-check/phpcs-rulesets/plugin-review.xml <plugin-dir>`, using the bundled `vendor/bin/phpcs` [UNVERIFIED that the packaged zip includes the phpcs binary and installed paths; it does work from a git checkout after `composer install`].

---

## 5. readme.txt and plugin header requirements

### 5.1 readme.txt
Sources: https://developer.wordpress.org/plugins/wordpress-org/how-your-readme-txt-works/, https://wordpress.org/plugins/readme.txt, PCP `Plugin_Readme_Check.php` [VERIFIED]. Validator: https://wordpress.org/plugins/developers/readme-validator/ [URL is UNVERIFIED in this session but long-standing].

```
=== Plugin Name ===
Contributors: wporgusername1, wporgusername2
Donate link: https://example.com/
Tags: tag1, tag2
Requires at least: 6.5
Tested up to: 6.9
Stable tag: 1.0.0
Requires PHP: 7.4
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Short description, at most 150 characters, no markup.

== Description ==
== Installation ==
== Frequently Asked Questions ==
== Screenshots ==
== Changelog ==
== Upgrade Notice ==
```

| Field | Rule |
|---|---|
| `=== Plugin Name ===` | Required. PCP errors on `invalid_plugin_name`/`empty_plugin_name`, and warns `mismatched_plugin_name` if it differs from the header Plugin Name |
| Contributors | Case-sensitive, comma-separated **WordPress.org usernames** only. PCP warns `readme_invalid_contributors` and `readme_reserved_contributors`, and errors on `readme_restricted_contributors`. Unknown usernames are ignored (`contributor_ignored`) |
| Donate link | Optional. Must be a valid URL (`readme_invalid_donate_link`), and certain domains are discouraged (`readme_invalid_donate_link_domain`) |
| Tags | **1 to 5** terms; extras are ignored (`too_many_tags`). No competitor names. Some tags are not permitted (`ignored_tags`). Tags unique to your plugin aren't shown |
| Requires at least | Since WP 5.8 this is read from the main PHP file, not the readme. Keep both consistent (PCP `readme_mismatched_header_*` errors) |
| Tested up to | Major version only, such as `6.9` (an error on minor versions: `invalid_tested_upto_minor`). Numbers only. **Must be the current WP major**: an outdated value is an ERROR in new mode (warning in update mode), and a nonexistent version is an error. **Must not appear in the plugin PHP header** (`plugin_header_tested_up_to_not_allowed`, error) |
| Stable tag | Required (`no_stable_tag`). Must exactly equal the header `Version` (`stable_tag_mismatch`). `trunk` is prohibited for new plugins (`trunk_stable_tag`). Numbers and periods only, SemVer recommended |
| Requires PHP | Optional. Numbers only (`7.4`, not `PHP 7.4`) |
| License | Required (`no_license`). A valid GPL-compatible SPDX-ish identifier (`invalid_license`), identical to the header (`license_mismatch`) |
| License URI | Optional but recommended |
| Short description | **Max 150 characters**; it is truncated beyond that (`trimmed_short_description`, warning sev 6). No markup. If missing, an excerpt is generated (`no_short_description_present`) |
| Sections | `trimmed_section_*` warnings when a section exceeds the parser maximum (2,500 words, or 5,000 for changelog/FAQ, per the dotorg parser) [limits UNVERIFIED; the parser lives in a dependency not present in the clone] |
| Upgrade Notice | Max 300 characters per version (`upgrade_notice_limit`, warning) |
| Default text | Leaving template text in the readme is an error (`default_readme_text`) |
| Language | **English required** since July 2025. PCP errors on `readme_short_description_non_official_language` and `readme_description_non_official_language` |
| File | Must be `readme.txt` (`no_plugin_readme`); a readme.md alone is rejected. Keep it under about 10 KB and move old changelog entries to `changelog.txt` |
| External services | Document each service, what data is sent and when, and links to ToS and privacy policy (see 2.3) |
| Source for minified code | A public repo link and build instructions **in the readme** (see 2.3) |

### 5.2 Main plugin file header
Sources: https://developer.wordpress.org/plugins/plugin-basics/header-requirements/ [VERIFIED], PCP `Plugin_Header_Fields_Check.php` and `Plugin_Updater_Check.php` [VERIFIED].

```php
<?php
/**
 * Plugin Name:       My Plugin Name
 * Plugin URI:        https://example.com/my-plugin/
 * Description:       Short description (< 140 chars).
 * Version:           1.0.0
 * Requires at least: 6.5
 * Requires PHP:      7.4
 * Author:            Your Name
 * Author URI:        https://example.com/
 * License:           GPLv2 or later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       my-plugin-name
 * Domain Path:       /languages
 * Requires Plugins:  woocommerce
 */
```

| Header | Rule (WordPress.org and PCP) |
|---|---|
| Plugin Name | Required. Must contain at least 5 Latin letters or digits, because the initial slug is generated from it (`plugin_header_invalid_plugin_name`). Unsupported names (e.g. trademark-led) are an error in new mode (`plugin_header_unsupported_plugin_name`). Keep it under 5 words. Avoid "WordPress" or "Plugin". Must match the readme name |
| Plugin URI | Optional. Must be a valid, unique URL; a WordPress.org URL is not allowed, and some domains are discouraged (`plugin_header_invalid_plugin_uri_domain`). Don't share it between the free and pro versions |
| Description | Required by PCP (`plugin_header_missing_plugin_description`). No default text. Under 140 characters per the handbook |
| Version | Required (`plugin_header_missing_plugin_version`). Only digits, letters, periods and hyphens. Must equal the readme Stable tag. Mind `version_compare` ordering: 1.02 > 1.1 |
| Requires at least | A real WordPress version such as `6.5` (`plugin_header_invalid_requires_wp`, `plugin_header_nonexistent_requires_wp`). Functions used must exist in that version (`wp_functions_compatibility`) |
| Requires PHP | A PHP version such as `7.4` (`plugin_header_invalid_requires_php`) |
| Author / Author URI | Author URI must be a valid URL, and some domains are discouraged. Since Feb 2025 the author shown on the directory comes from the WordPress.org owner profile, not this header |
| License | Required (`plugin_header_no_license`). GPLv2-or-later-compatible (`plugin_header_invalid_license`). Must match the readme |
| License URI | Recommended |
| Text Domain | Lowercase letters, digits and hyphens (`textdomain_invalid_format`, error). **Must equal the slug** (`textdomain_mismatch`; the pre-submission gate blocks on "wrong text domain"). Optional since WP 4.6, but if present it must match |
| Domain Path | Must start with `/` and point to an existing folder (warnings) |
| Network | Only `true`, and only if the plugin is network-only. Otherwise omit it (`plugin_header_invalid_network`) |
| **Update URI** | **Not allowed on WordPress.org.** "Use of the Update URI header is not allowed in plugins hosted on WordPress.org" (`plugin_updater_detected`, error) |
| Requires Plugins | Comma-separated WordPress.org slugs (no `dir/file.php`). Each must exist on WordPress.org (`plugin_header_invalid_requires_plugins`, error; a not-found slug is a warning) |
| Tested up to | **Not allowed in the PHP header**; put it in the readme only |
| Placement | Headers belong in the main file only. Main file name must be `<slug>.php` |

---

## 6. Process changes 2024 to 2026

| Date | Change | Source |
|---|---|---|
| 2024-09-17 | Plugin Check (PCP) introduced. Automatic issue detection for new submissions began | https://make.wordpress.org/plugins/2024/09/17/introducing-plugin-check-pcp/ |
| 2024-09-09 | Guidance on plugins that install other plugins: "no-asking" installs are not allowed, and user consent and information are required | https://make.wordpress.org/plugins/2024/09/09/guidance-on-plugins-that-install-other-plugins/ |
| **2024-10-01** | **PCP pre-check is mandatory at upload.** The "Plugin Repo" category runs on every new submission, and any error-level item **blocks the submission** until fixed. Typical blockers: header Version vs Stable tag mismatch, wrong text domain, outdated or incorrect "Tested up to". **2FA required** for all plugin owners and committers and for submitting. The Security category was announced as a future additional gate. Plugins closed for security issues must pass the Security category to be reopened | https://make.wordpress.org/plugins/2024/10/01/plugin-check-and-2fa-now-mandatory-for-new-plugin-submissions/ |
| 2024-12-24 | PCP roadmap: post-SVN-commit checks, and retroactive checks on existing plugins | https://make.wordpress.org/plugins/2024/12/24/plugin-check-goals-roadmap/ |
| 2025-02-20 | The displayed author now comes from the owner's WordPress.org profile, not the header | https://make.wordpress.org/plugins/2025/02/20/plugin-author-now-linked-wp-profiles/ |
| 2025-05-21 | Submissions doubled (+87%). The internal scanner was upgraded, and PCP pre-submission review cut issues | https://make.wordpress.org/plugins/2025/05/21/the-wordpress-ecosystem-is-growing-new-plugin-submissions-have-doubled-in-2025/ |
| 2025-07-12 | Renamed to **Plugins Team**. **AI checks on plugin names** for trademark compliance. The internal Scanner runs **220+ automated checks** | https://make.wordpress.org/plugins/2025/07/12/team-name-change-to-plugins-team/ |
| **2025-07-28** | **readme.txt must be written in English** (translations go through translate.wordpress.org). PCP now errors on non-English descriptions | https://make.wordpress.org/plugins/2025/07/28/requiring-the-readme-to-be-written-in-english/ |
| 2025-08-11 | Opt-in phased releases / release confirmation (24-hour delay of auto-updates) | https://make.wordpress.org/plugins/2025/08/11/plugin-rollout-phased-releases/ |
| 2025-08-31 | **85.3% of first reviews were started by an automated AI-assisted system**. Queue under one week | https://make.wordpress.org/plugins/2025/08/31/stats-of-plugins-team-after-wordcamp-us/ |
| 2025-10-27/29 | PCP runs on **all plugin updates** (new and approved). Results are internal for now; emailed security reports are planned | https://make.wordpress.org/plugins/2025/10/29/plugin-check-plugin-now-creates-automatic-security-reports-update/ |
| 2026-01-07 | 2025 recap: 12,713 plugins reviewed and 58,000+ reviews (multiple rounds is normal). 69.5% approval rate. **38.7% of reviewed plugins got no author reply**, and engagement correlates with approval. The internal AI scanner flags issues, which reviewers confirm or dismiss. New PCP security checks: nonce verification, direct DB queries, forbidden functions, minified files, `wp_safe_redirect`. New licences accepted: ISC, MPL-2.0, Unlicense | https://make.wordpress.org/plugins/2026/01/07/a-year-in-the-plugins-team-2025/ |
| 2026-03-13 | More than 500 submissions per week; call for reviewers | https://make.wordpress.org/plugins/2026/03/13/contribute-to-the-plugins-team/ |
| 2026-03-20 | Plugin Directory MCP server (Meta x-post, no details read) | https://make.wordpress.org/plugins/2026/03/20/xpost-plugin-directory-mcp-server/ |
| 2026-06-05 | "Protect The Shire": every plugin release is held **up to 24 h** before distribution through auto-updates, for AI-assisted security review | https://wordpress.org/news/2026/06/pts/ |
| 2026-06-13 | Queue peaked around 1,050 in April and went back to near zero. About 700 submissions per week in May, with about 3,000 initial reviews that month. "These tools support reviewers; they don't replace them." | https://make.wordpress.org/plugins/2026/06/13/update-on-the-status-of-the-team-june-2026/ |
| **2026-09-09** | **Automated security review of every release.** A 6-hour cooldown (since June 5) while several AI models plus Jetpack Scan analyze the diff. High-risk releases are **blocked automatically**, and committers are emailed only on a block. Fix by publishing a new release, which is faster than an appeal. Common triggers: endpoints without capability checks ("a nonce alone is not authorization"), unprepared SQL, request-controlled file paths, uploads or includes, `unserialize` on untrusted data, options written from low-privilege or unauthenticated endpoints, runtime-fetched or eval'd code, obfuscation | https://make.wordpress.org/plugins/2026/09/09/automated-security-review-for-plugin-releases/ |
| 2026-10-02 | Support tooling moving from HelpScout to FreeScout (x-post) | https://make.wordpress.org/plugins/2026/10/02/xpost-heads-up-helpscout-to-freescout-migration/ |
| PCP 2.x (2026) | New checks: `ai_provider`, `react_usage` (React 19), `block_api_version_too_low` (apiVersion 3 for WP 7.0), `wp_functions_compatibility`, `menu_image_icon`, `external_admin_menu_links`. `file_type` now flags `.claude`, `.cursor`, `.github` and stray `.md` files. `--ai` flag for false-positive triage, and an AI "Namer" tool (Tools > Plugin Check Namer) for name and trademark evaluation | GitHub repo docs |

### Submission and review workflow (Plugin Developer FAQ, updated 2026-09-01)
Source: https://developer.wordpress.org/plugins/wordpress-org/plugin-developer-faq/ [VERIFIED]

- **Before submitting:** a WordPress.org account with 2FA and a monitored email, with `plugins@wordpress.org` whitelisted. A company plugin must come from the company's official account.
- **Upload:** the zip must be **under 10 MB** and production-ready, with no placeholders. The PCP Plugin Repo pre-check runs at upload and blocks on errors. You then get an automated confirmation email and the plugin enters the queue. Files can be updated from the submission page at any time during review.
- **Queue limit:** **one plugin under review at a time per author.** Authors with more than 1 million active installs can have up to 10. Secondary accounts used to get around the limit are suspended. No queue-jumping except for security or legal issues.
- **Review email:** subject **"[WordPress Plugin Directory] Review in Progress: {Plugin Name}"**, sent from plugins@wordpress.org (check spam). It lists issues, usually as Common Issues excerpts with file and line examples and often PCP or scanner output, and asks you to fix **all** occurrences, not just the examples given. The "fix all occurrences" convention is UNVERIFIED as quoted text but standard in review emails. Since 2025, many first reports are generated by the AI-assisted scanner and confirmed by a human reviewer.
- **How to respond:**
  - **Reply to the same email thread**, and don't open new threads.
  - Upload the corrected zip through the submission page ("Add your plugin"), then reply briefly saying what you changed. The team asks for a concise summary, not a full diff [summary phrasing UNVERIFIED].
  - **Do not resubmit** a plugin that was rejected for any reason other than the 3-month timeout. Just reply to the email.
  - No auto-replies. Auto-replies or routing to a ticket system can get the plugin closed (guideline 18).
- **Timing:** the team aims to reply within 7 to 10 business days. A small, clean plugin should be approved within 14 days of the initial review. Reviews stay open as long as there is progress, and the longest so far took 3 years. **No completion after 3 months means rejection**; the FAQ wording is inconsistent on whether the review stays open. After a 3-month rejection you may resubmit and reply to the old email.
- **Slug:** generated from the header Plugin Name. It can be changed **once** by you before approval (further changes go through the team) and **never after approval**. The team may change it for typos or trademark conflicts. A slug that collides with an existing WordPress.org plugin, or a significant non-WordPress.org product, produces an error. Banned: vulgarities, "wordpress" or "plugin" in the slug, version numbers, non-English letters, a trademark at the start (unless you are the owner), and evasions such as "WuuCommerce" or "Face-Range". A company's permission does **not** allow its trademark at the start of the permalink; only the official owner can use it. The display name must not imply official status: use "Connector to Frozbaz Service", not "Frozbaz".
- **Reasons for outright rejection:** no meaningful purpose; illegal or harmful use or black-hat SEO; arbitrary code insertion or execution (PHP or JS editors); downloading or running external code; installer-only plugins; framework or library plugins; copies of existing work; duplicating core.

---

## 7. Items I could not verify

- Readme section length limits (2,500 words, or 5,000 for changelog/FAQ). The parser is a WordPress.org dependency that isn't in the PCP clone.
- The exact list of restricted and reserved Contributors usernames, the not-permitted tags list, and the discouraged URI domains. The data lives in PCP and parser code paths I didn't open.
- What the `strict-*` output formats do. The docs list them without describing them.
- The exact wording of the current review email body. Only the subject line is documented. The body description in section 6 comes from Common Issues ("excerpts from the team's email messages") plus general knowledge.
- Whether WordPress.org's upload scanner treats trademarks as blocking errors. PCP reports them as warnings, but the FAQ says unacceptable slugs are auto-corrected or rejected.
- Whether the Security category is enforced at upload yet. It was announced as "will be", and no later post confirms a date. Its findings are certainly applied by human reviewers and by the release cooldown scanner.
- `Nonce_Verification_Check` exists in source but isn't registered in the default repository on trunk.
- The ruleset header says "compatible with PHP 5.2" (`testVersion 5.2-`). That looks stale, and PHPCompatibility isn't in the runtime requires, so I'm not sure it's enforced.
