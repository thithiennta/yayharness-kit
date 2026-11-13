# WordPress.org checklist: one ID per rule

Every finding `/yay:wporg` reports, every fix commit it makes (`fix(security): S12 escape stored HTML`) and every review-email heading it maps uses the IDs below. The S, G, B, Q, R, T and U IDs are the partner team's (`YayCommerce/YayAutomation@develop:.claude/docs/context-wporg-release-checklist.md`), so both teams say the same thing by the same name. N (name, trademarks, ownership) and Z (zip structure), Q14 and G8 fill the gaps that list didn't cover.

**Checked by** says where the result comes from:
- `precheck:<check>`: `scripts/precheck.py`, which prints the ID next to each check name
- `site:<ID>`: `yayh wporg site` on the throwaway site with the built zip, one `site.tsv` line per check
- `pcp`: Plugin Check's own result, run by `yayh wporg site` as `T1`
- `build`: `yayh build check` on the zip
- `manual`: the reviewer pass (`manual-review.md`, section given in **Where**)

**Severity** is the default tag in the report: `[blocks upload]` when Plugin Check's `plugin_repo` category errors on it (the zip is refused at upload), `[review]` when it only shows up in the email.

## Index

| ID | Rule | Checked by | Severity | Where |
|---|---|---|---|---|
| S1 | Data-changing handlers check a nonce **and** `current_user_can()` | `precheck:ajax_nonce`, `ajax_capability`, `nonce_missing`; manual | review | manual-review §1 |
| S2 | Every REST route has a real `permission_callback`; `__return_true` only for public read-only data, justified in the reply | `precheck:rest_permission`, `rest_public_write`; manual | review | manual-review §1 |
| S3 | Input sanitized early: `wp_unslash()` then a type sanitizer; only the keys you need | `precheck:unsanitized_input`, `whole_input`, `filter_*`, `setting_sanitization` | review | manual-review §1 |
| S4 | Output escaped late, at the echo | `precheck:unescaped_output`, `unescaped_e`, `echo_gettext`, `printf_gettext`, `echo_sanitize`, `esc_url_raw_output`, `heredoc`, `short_*_tag` | review | rules §2.1 |
| S5 | Shortcode, `render_callback` and content-filter callbacks escape what they return | manual (precheck inventory `output_callbacks`) | review | manual-review §1 |
| S6 | No JSON flags that bypass escaping (`JSON_UNESCAPED_*` on any JSON that reaches the page, even next to `JSON_HEX_*`) | `precheck:echo_json_flags`, `json_unescaped_flags`, `echo_json_encode` | review | rules §2.5 |
| S7 | User values that go into markup (class names, block comments) are allow-listed | manual | review | manual-review §1 |
| S8 | SQL goes through `$wpdb->prepare()`; no raw mysqli/PDO | `precheck:direct_db`, `mysql` | review | manual-review §1 |
| S9 | `ABSPATH` guard in every PHP file that runs code at load | `precheck:direct_file_access` | review | manual-review §10 |
| S10 | No forbidden or dangerous functions (`eval`, `exec`, `unserialize` on input, `move_uploaded_file`) | `precheck:eval`, `create_function`, `forbidden_exec`, `str_rot13`, `base64_decode`, `goto_backtick`, `unserialize`, `move_uploaded_file`, `unfiltered_uploads` | blocks upload | rules §2.4 |
| S11 | JSON passed to an inline script uses `JSON_HEX_TAG \| JSON_HEX_AMP` | `precheck:inline_script_json_hex` | review | manual-review §1 |
| S12 | HTML held in a variable is escaped when echoed; `phpcs:ignore` doesn't pass review | manual (`precheck:unescaped_output` finds the echoes) | review | manual-review §1 |
| S13 | Block comment attributes built with `serialize_block_attributes()` | `precheck:block_comment_markup`; manual | review | manual-review §1 |
| G1 | No updater, license client or `Update URI` in the free zip (vendor copies count) | `precheck:updater`, `plugin_updater_detected` | blocks upload | manual-review §3 |
| G2 | No remote JS or CSS (fonts are fine), no remote code | `precheck:offloading_files` | blocks upload | manual-review §3 |
| G3 | No tracking or external calls without opt-in; each service documented in the readme | `precheck:external_services`, `ai_provider`; manual | review | manual-review §3 |
| G4 | No locked, trial or license-gated features in the free zip | manual (precheck inventory `pro_license_gates`) | review | manual-review §2 |
| G5 | Notices limited to the plugin's own screens, and say how to fix what they report | manual (precheck inventory `admin_notices`) | review | manual-review §5 |
| G6 | No front-end credit links unless opted in | manual | review | rules §1 |
| G7 | Everything GPL-compatible: code, libraries, fonts, images | manual | review | manual-review §6 |
| G8 | The purpose itself is allowed (no arbitrary code boxes, including a plain custom CSS setting, no installer-only or storefront-only plugin) | `precheck:custom_code_setting`; manual | review | manual-review §9 |
| B1 | Every minified or built file has public source, and the link works logged out | `precheck:no_public_source`; manual | review | manual-review §6 |
| B2 | Build steps documented; a clean clone rebuilds the same files | `precheck:no_build_instructions`, `missing_composer_json_file`; manual | review | manual-review §6 |
| B3 | Bundled third-party libraries credited (name, version, URL) | manual | review | manual-review §6 |
| B4 | No dev files, hidden files or local URLs in the zip | `build` dev-files; `precheck:file_type`, `unneeded_folders`, `localhost` | blocks upload | manual-review §10 |
| Q1 | Every `ob_start()` closed in the same function, on every path | `precheck:unclosed_ob_start` | review | manual-review §10 |
| Q2 | One unique prefix (4+ characters) or namespace on every global name | `precheck:prefixing` | review | manual-review §4 |
| Q3 | Assets load only where they're used; `admin_body_class` and CSS don't leak into WordPress screens | `precheck:enqueue_scope`, `admin_body_class`, `direct_tags`; manual | review | manual-review §5 |
| Q4 | No `load_plugin_textdomain()` (not needed since WordPress 4.6) | `precheck:load_textdomain` | review | rules §2.5 |
| Q5 | Strings translatable with the literal slug as text domain | `precheck:i18n_textdomain_mismatch`, `i18n_variable_domain` | blocks upload | rules §2.2 |
| Q6 | No PHP notices, warnings or debug leftovers with `WP_DEBUG` on | `site:Q6` (debug.log); `precheck:dev_functions` | review | manual-review §10 |
| Q7 | Clean activate, deactivate and uninstall; `uninstall.php` checks `WP_UNINSTALL_PLUGIN` | `site:Q7`; `precheck:uninstall_missing_constant_check` | review | manual-review §10 |
| Q8 | Uses the libraries WordPress ships (jQuery, React, lodash…) | `precheck:library_core_files` | blocks upload | manual-review §6 |
| Q9 | Post type keys are 20 characters or fewer | `precheck:post_type_key_length` | review | manual-review §10 |
| Q10 | Requirements (WordPress, PHP, required plugins) checked at runtime, with a notice and a stop | `site:Q10`; `precheck:change_plugins` | review | manual-review §10 |
| Q11 | Activation prints nothing, logs nothing and contacts nothing | `site:Q11` | review | manual-review §10 |
| Q12 | Query and render cost is bounded | manual (method in manual-review §10) | review | manual-review §10 |
| Q13 | Product queries respect catalog visibility (WooCommerce) | `precheck:product_query_visibility` | review | manual-review §10 |
| Q14 | WordPress APIs instead of raw PHP (HTTP API, `wp_date`, `wp_safe_redirect`, `wp_upload_dir`, no `wp-load.php`) | `precheck:curl`, `file_get_contents_url`, `timezone`, `error_reporting`, `global_ini`, `json_encode`, `wp_redirect`, `wp_load`, `write_file`, `query_posts`, `plugindir`, `short_url` | review | rules §2.2 |
| R1 | readme.txt valid: English, a short description of 150 characters or fewer, usernames as contributors, no template text | `precheck:readme`, `no_plugin_readme`, `readme_*`, `*_short_description*`, `default_readme_text`, `mismatched_plugin_name` | blocks upload | rules §5.1 |
| R2 | `Version`, `Stable tag` and the version constant agree; `Tested up to` is the current major | `precheck:stable_tag_mismatch`, `no_stable_tag`, `trunk_stable_tag`, `*tested_up*`; `build` version, stable-tag | blocks upload | rules §5.1 |
| R3 | `Requires at least`, `Requires PHP` and `Requires Plugins` are true and match the header | `precheck:readme_mismatched_header` | blocks upload | rules §5.2 |
| R4 | Header complete: Plugin Name, Description, Version, Author, License, Text Domain = slug; no `Tested up to` or `Update URI` in it | `precheck:plugin_header`, `textdomain_mismatch`, `plugin_header_tested_up_to_not_allowed`, `no_license`, `license_mismatch` | blocks upload | rules §5.2 |
| R5 | At most 5 tags, no competitor tags | `precheck:too_many_tags` | review | manual-review §7 |
| R6 | Disclosures present when they apply: `== External services ==` for each service; a source-code section when built or minified files ship | `precheck:external_services`, `no_public_source`; manual | review | manual-review §7 |
| T1 | Plugin Check: no `plugin_repo` errors; read every warning | `site:T1` (`pcp`) | blocks upload | rules §3 |
| T2 | PHPCS (WordPress standard) security sniffs pass | manual (skip when T1 ran: Plugin Check includes them) | review | rules §4 |
| T3 | Works on a clean install of the latest WordPress (blocks `apiVersion` 3, React 19) | `site:` all; `precheck:block_api_version_too_low`, `react_removed` | blocks upload | rules §2.4 |
| U1 | The real zip was installed and smoke-tested, and it also activates in WordPress Playground (the review email links a Playground blueprint for the submitted zip, and reviewers use it) | `site:` all (it installs the built zip) | review | SKILL step 2 |
| U2 | Slug confirmed: it can't change after approval | manual | review | manual-review §8 |
| U3 | The reply is short, in the same thread, and lists no changes; false positives answered with an example | manual (`--email`) | review | SKILL `--email` |
| U4 | Every occurrence of each reported issue fixed, not only the examples | manual (`--email`) | review | SKILL `--email` |
| N1 | Name and slug don't start with someone else's trademark or project name (`<Brand> <function> for <Project>`) | `precheck:trademarks`, `plugin_name`, `slug` | blocks upload | manual-review §8 |
| N2 | Slug, folder, main file name and Text Domain are the same string | `precheck:main_file_name`; `build` folder | review | manual-review §8 |
| N3 | Ownership is provable: Plugin URI and Author URI on the submitting account's domain | `precheck:ownership`; manual | review | manual-review §8 |
| Z1 | One top folder in the zip, named after the slug | `precheck:zip_structure`; `build` folder | blocks upload | rules §2.3 |
| Z2 | Zip under 10 MB | `precheck:zip_size` | blocks upload | rules §2.3 |
| Z3 | No `__MACOSX/` and no unsafe paths in the zip | `precheck:zip_macosx`, `zip_unsafe_path` | blocks upload | rules §2.3 |

Partner rules changed here:
- **R6** asked for a "Privacy" section and a "Source code" section in every readme. The directory asks for neither: a source section only when built or minified files ship, and a services section only when the plugin calls out.
- **G5** asked for every notice to be dismissible. The team's rule is about where notices show and whether they nag: limit them to the plugin's screens, and make upsells and review requests dismissible for good.
- **Q4** offered "move it to `init`" as a fix. The fix is to remove it; `init` is only for plugins that still support WordPress before 4.6.

## Review-email headings → IDs

Find each heading of the email, then check every ID listed, across the whole plugin. A heading that isn't here: map it by its text, add a row in the same fix branch, and say so in the report.

| Heading in the review email | IDs |
|---|---|
| Have you read the guidelines and this plugin complies with them? | the guideline bullets below |
| Plugins must not restrict or lock functionality / Trialware / locked features | G4 |
| Developers must provide public, maintained access to their source code / Guidelines 1, 4 | B1, B2, B3 |
| The source code of your plugin should be publicly accessible | B1, B2, B3, R6 |
| Attempting to process custom CSS/JS/PHP / Allowing arbitrary script insertion | G8 |
| No publicly documented resource for your generated/compressed content | B1, B2, R6 |
| Plugins should not hijack the admin dashboard / Guideline 11 | G5, Q3 |
| Is the name of this plugin descriptive and distinctive…trademarks | N1, N2, U2 |
| Are you the rightful owner of this plugin? | N3 |
| Nonces and user permissions before processing requests | S1, S2 |
| Check permission_callback in REST API Route | S2 |
| Proper escaping of outputs | S4, S6, S7 |
| Variables and options must be escaped when echo'd | S4, S6, S11, S12, S13 |
| Callback calls to a function/method whose return values are output must be properly escaped | S5, S7 |
| Sanitize, validate and escape / Data must be sanitized | S3 |
| Processing the whole input | S3 |
| Use $wpdb->prepare / Unprepared SQL | S8 |
| Allowing direct file access to plugin files | S9 |
| Calling files remotely / Offloading files | G2 |
| Including an update checker / Update URI | G1 |
| Undocumented use of a 3rd Party / external service | G3, R6 |
| Tracking / phoning home without consent | G3 |
| Not permitted files / unneeded folders | B4, Z3 |
| Including libraries already in WordPress core | Q8 |
| Generic function/class/define/namespace/option names | Q2, Q9, U3 |
| Unclosed ob_start() | Q1 |
| load_plugin_textdomain() is not needed | Q4 |
| Internationalization: text domain does not match / variables in translation functions | Q5 |
| The plugin has problems when it is activated | Q3, Q10, Q11, G3 |
| Use wp_enqueue commands | Q3 |
| Changing active plugins | Q10 |
| Use the HTTP API / Don't change PHP settings / wp-load.php / Saving data in the plugin folder | Q14 |
| Other possible issues (AI-detected) | Q12, U3, U4 |
| Readme / Stable tag / Tested up to / Version mismatch | R1, R2, R3 |
| Plugin header: Tested up to declared in the main file | R4 |
| Incorrect or missing license | R4, G7 |
