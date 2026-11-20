# Theme Directory checklist: one ID per rule

Every finding `/yay:wporg-theme` reports and every fix commit it makes (`fix(theme): X2 bundle the icon font`) uses the IDs below. They follow the sections of the Themes Team's **required items** page, so a reviewer's ticket comment maps back to an ID by its section name.

Sources, read 2026-11-20 (re-read them when a rule looks out of date, and update this file with the date):
- **[REQ]** https://make.wordpress.org/themes/handbook/review/required/ (page last modified 2026-06-09)
- **[REC]** https://make.wordpress.org/themes/handbook/review/recommended/ (2021-08-11)
- **[FILES]** https://developer.wordpress.org/themes/releasing-your-theme/required-theme-files/ (2026-06-24)
- **[PROC]** https://make.wordpress.org/themes/handbook/review/ (2020-11-11)
- **[TC]** https://github.com/WordPress/theme-check (README) and https://make.wordpress.org/themes/handbook/review/required/theme-check-plugin/ (2020, says it may be out of date)

**Checked by:**
- `precheck:<check>`: `scripts/precheck.py` on the zip, which prints the ID next to each check name
- `site:<ID>`: `yayh wporg theme-site` on the throwaway site with the zip, one `site.tsv` line per check
- `tc`: Theme Check's own result, run by `yayh wporg theme-site` as `TC`
- `ui`: `yayh release ui` (the themes-page walk with screenshots)
- `manual`: the reviewer pass (`manual-review.md`, section given in **Where**)

**Severity** is the default tag in the report:
- `[gate]`: Theme Check REQUIRED results. Themes "have to pass the Theme Check plugin without errors" [TC]. Whether the upload form itself runs it is not stated on the pages read, so the report says "fix before upload", not "the upload refuses it".
- `[required]`: a required item [REQ]. The reviewer lists it in the ticket. **Three or more distinct required issues may close the ticket as not-approved** [REQ], so the count matters, not only each issue.
- `[recommended]`: [REC] items. They never block approval; report them in a short list at the end.

## Index

| ID | Rule | Checked by | Severity | Where |
|---|---|---|---|---|
| TC | Theme Check passes with no REQUIRED results | `tc` | gate | [TC] |
| L1 | Code, data and images are GPL or GPL-compatible ("GPLv2 or later" recommended) | manual | required | manual-review §1 |
| L2 | The theme states its copyright | `precheck:no_copyright`; manual | required | [REQ] Licensing |
| L3 | Every bundled resource (images, fonts, icons, libraries) has its license, copyright and source, listed in one file (readme.txt `== Resources ==`); public-domain assets excepted | `precheck:no_resources_section`; manual | required | manual-review §1 |
| L4 | No cloned designs | manual | required | [REQ] Licensing |
| L5 | Front-end copyright shows only the site owner's copyright, not the author's | manual | required | manual-review §6 |
| P1 | Tracking and data collection are off by default and opt-in | manual (precheck inventory `remote_calls`) | required | manual-review §3 |
| P2 | Data use is documented in readme.txt, ideally with a privacy policy | manual | required | [REQ] Privacy |
| A1 | A skip link, when there is something to skip: first focusable element, visible on focus, moves focus to main content (block themes get it from core on `<main>`) | `ui`; manual | required | manual-review §5 |
| A2 | Visible keyboard focus on menus, form fields, submit buttons and text links | `ui`; manual | required | manual-review §5 |
| A3 | Everything usable by mouse is usable by keyboard | manual | required | manual-review §5 |
| A4 | With the `accessibility-ready` tag: the extra accessibility checks | manual | required | handbook /review/accessibility/ |
| C1 | No PHP or JS errors, warnings or notices | `site:C1`; manual | required | [REQ] Code |
| C2 | Input validated and sanitized, output escaped | manual | required | manual-review §2 |
| C3 | No deprecated functions or constants | `tc`; `precheck:wp_title` | required | [REQ] Code |
| C4 | Everything in the public namespace prefixed, at least four letters: options, functions, globals, constants, post meta, script and style handles, image sizes, `wp_script_add_data` keys, new pattern category slugs. Not needed: third-party handles, menu locations, sidebar IDs | manual | required | manual-review §2 |
| F1 | Doesn't manipulate the WordPress.org preview | manual | required | [REQ] Functionality |
| F2 | Admin notices use `admin_notices`, are dismissible and look like core | manual (precheck inventory `admin_notices`) | required | manual-review §4 |
| F3 | No WordPress feature behind a paywall | manual (precheck inventory `upsell_links`) | required | manual-review §4 |
| F4 | Doesn't remove, hide or block the admin bar | `precheck:hides_admin_bar` | required | [REQ] Functionality |
| F5 | No redirect on activation, no change to the activation process | `precheck:redirect_on_activation`; `site:F5` | required | [REQ] Functionality |
| F6 | Doesn't remove non-presentational hooks (`wp_generator`, `feed_links`, `rsd_link`, `rel_canonical`, …) | `precheck:removes_core_hook` | required | [REQ] Functionality |
| F7 | No plugin territory: custom post types, taxonomies, custom blocks, roles, user contact methods, mime types, shortcodes, or anything not about design and presentation (analytics, SEO, contact forms, non-design meta boxes, caching, social buttons, sessions) | `precheck:plugin_territory_*`; manual | required | manual-review §3 |
| W1 | Only plugins hosted on WordPress.org are recommended | `precheck:bundled_plugin_source`; manual (inventory `plugin_recommendations`) | required | manual-review §3 |
| W2 | Plugins are installed only by the user's action | manual | required | manual-review §3 |
| W3 | No plugin zips or plugin folders in the theme, no automatic plugin downloads | `precheck:disallowed_file`, `bundled_plugin_source` | required | [REQ] Plugins |
| N1 | The name doesn't use "WordPress", "Theme" or "Twenty*" | `precheck:reserved_word_in_name` | required | [REQ] Naming |
| N2 | "WordPress" is spelled that way | `precheck:wordpress_spelling` | required | [REQ] Naming |
| N3 | No trademark, and no third-party project name used as if it were the theme's own (see below) | `precheck:third_party_name`; manual | required | manual-review §7 |
| N4 | The logo and banner don't include the WordPress logo | manual | required | [REQ] Naming |
| I1 | Every string translatable with gettext (text inside HTML templates excepted) | manual | required | manual-review §2 |
| I2 | Text domain = theme slug = folder name, and it's in style.css | `precheck:text_domain_mismatch` | required | [REQ] Language |
| I3 | At most two text domains in all (a framework's plus the theme's) | `precheck:other_text_domains` | required | [REQ] Language |
| X1 | The zip is complete and clean: one top folder, no `.git`/`.svn`/`.hg`/`.bzr`, no hidden files, none of the banned files (`thumbs.db`, `desktop.ini`, `php.ini`, `error_log`, `web.config`, `favicon.ico`, `.sql`, `.sh`, `.zip`, `__MACOSX`, `.xml` other than `wpml-config.xml`/`loco.xml`/`phpcs.xml`, …) | `precheck:zip_structure`, `vcs_dir`, `hidden_file`, `disallowed_file` | required | [REQ] Files |
| X2 | No remote resources without the user's consent: scripts, styles, images, video and fonts ship in the zip. The only exception is Google Fonts. No CDNs | `precheck:remote_asset`, `remote_css_import`, `remote_font`, `remote_image`; manual | required | manual-review §3 |
| X3 | Minified files ship with their originals | `precheck:minified_without_source` | required | [REQ] Files |
| X4 | No copies of libraries WordPress ships (jQuery, Masonry, imagesLoaded, Underscore, …) | `precheck:bundled_core_library` | required | [REQ] Files |
| X5 | No images promoting hate or violence, or showing children with recognizable features | manual | required | [REQ] Files |
| X6 | Screenshot: at most 1200×900, 4:3, not an advertisement | `precheck:screenshot_*` | required | [REQ] Files, [FILES] |
| X7 | style.css headers: Theme Name, Author, Description, Version (X.X or X.X.X), Requires at least, Tested up to, Requires PHP (numbers only), License, License URI, Text Domain. A Theme URI is about this theme and isn't wordpress.org; Tags come from the Theme Tag List | `precheck:style_*`, `theme_uri_reserved`; manual (tags) | required | [REQ] Files |
| X8 | A valid readme.txt: `=== Name ===`, Contributors, Requires at least, Tested up to, Requires PHP, License, License URI; short description ≤ 150 characters; Upgrade Notice ≤ 300 | `precheck:readme_*`, `missing_readme`; manual (lengths) | required | [REQ] Files |
| X9 | One line-ending type | `precheck:mixed_line_endings` | required | [REQ] Files |
| K1 | Classic theme files: `index.php`, `comments.php` (threaded comments), `style.css`, screenshot | `precheck:missing_index_php`, `missing_comments_php` | required | [FILES] |
| K2 | Classic theme hooks: valid DOCTYPE, `language_attributes()`, `wp_head()`, `body_class()`, `wp_body_open()`, `wp_footer()`, `post_class()`, `wp_link_pages()`, `title-tag` and `automatic-feed-links` support | `precheck:missing_*` | required | [REQ] Classic themes |
| K3 | Classic templates load with `get_template_part()`/`locate_template()`, and `header.php`, `footer.php`, `sidebar.php`, `searchform.php` with `get_header()` and friends; the front-page setting is honoured; options use `edit_theme_options` | manual; `precheck:wp_title` | required | [REQ] Classic themes |
| B1 | Block theme files: `style.css`, `readme.txt`, `theme.json`, `templates/index.html` | `precheck:missing_theme_json` | required | [REQ] Block themes |
| B2 | Block templates are complete: no missing or wrong closing block comments | `tc`; manual | required | manual-review §8 |
| O1 | Settings pages and onboarding: messages through `admin_notices`, one-time or permanently dismissible, no popup on activation | manual | required | manual-review §4 |
| O2 | An Appearance sub-page uses core UI, loads its assets only on its own screen (`admin_enqueue_scripts` + `$hook_suffix`) and checks capabilities | manual (inventory `admin_pages`) | required | manual-review §4 |
| O3 | Settings use the Settings and Options APIs in one option named after the theme slug (an array for several); core front-end options (logo, front page) only with notice and consent; everything sanitized | manual (inventory `options_written`) | required | manual-review §4 |
| O4 | No demo imports, external calls, tracking or affiliate links in admin or onboarding; `wp_insert_post`/`wp_update_post` only with consent | manual | required | manual-review §4 |
| S1 | At most one front-end credit link (to the Theme URI or Author URI), plus one to WordPress.org | manual | required | manual-review §6 |
| S2 | No obtrusive upselling, and none on the front end | manual (inventory `upsell_links`) | required | manual-review §6 |
| S3 | Every affiliate link disclosed | manual | required | manual-review §6 |
| S4 | No spam: competitor tags, keyword stuffing, black-hat SEO in the theme, readme, starter content or translations | manual | required | manual-review §6 |
| U1 | One new theme in the queue at a time, across all of the author's accounts (all accounts disclosed to themes@wordpress.org) | manual (ask) | required | [REQ] Author restrictions, [PROC] |

## Names (N3)

The Plugins Team flagged "Shadcn" (a UI library) in a 2026 plugin review although it is in no trademark list, and the Themes Team's rule is the same: "no trademark violations" [REQ]. Check every distinctive word of the theme name, not only a trademark list. When a word names someone else's project (**WPShadcn**: "Shadcn"), flag it `[required]` and offer 2–3 names that lead with the theme's own brand and keep the project out of the name (mention it in the description instead, e.g. "styled after shadcn/ui"); the team decides. "WP" itself is fine: the WordPress Foundation's trademark policy says the abbreviation isn't covered (from the policy at https://wordpressfoundation.org/trademark-policy/; re-check it before you rely on it).

## Ticket section map

Reviewers comment on the Trac ticket using the required-items section names. Map each comment to IDs by its section:

| Section in the ticket | IDs |
|---|---|
| Accessibility | A1–A4 |
| Code | C1–C4 |
| Core functionality and features / Functionality | F1–F7 |
| Plugins | W1–W3 |
| Naming, spelling and trademarks | N1–N4 |
| Language / Translation | I1–I3 |
| Licensing, copyright | L1–L5 |
| Privacy | P1–P2 |
| Files / Stylesheets and scripts / Screenshot / Documentation | X1–X9 |
| Templates (classic) | K1–K3 |
| Block themes | B1–B2 |
| Theme settings, options, onboarding | O1–O4 |
| Selling, credits and links / Spam | S1–S4 |
| Theme Check | TC |

A comment that fits none: map it by its text, add the row here in the fix branch, and say so.
