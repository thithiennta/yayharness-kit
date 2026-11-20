# Manual review: reading a theme like a Themes Team reviewer

Work through the unpacked zip with the precheck inventory as the map. Each section names the IDs it covers (`checklist.md`). Every finding needs a `file:line` (or the file, for a whole-file problem) and a fix. Call an area clean only when you read all of it.

## 1. Licensing (L1, L3)
- Open every image, font, icon set, CSS framework and JS library in the zip. For each, find its license and source in readme.txt's `== Resources ==` (or the theme's resources file). Missing → L3, with the exact line to add: `<Name>, Copyright <year> <holder>, License: <license>, Source: <url>`.
- Images and fonts are where rounds come from: stock photos in patterns and screenshots must be CC0 or GPL-compatible, with their source page (not a download URL). The team has long treated the Pexels and Unsplash licenses as not GPL-compatible (from memory, not on the pages read: check the current guidance before you report it); suggest CC0 sources (e.g. Openverse with a CC0 filter) or the author's own photos.
- A font's license (`OFL-1.1` is fine) goes in Resources too.

## 2. Code (C2, C4, I1)
- Escape late (`esc_html`, `esc_attr`, `esc_url`, `wp_kses_post`) at every echo in PHP templates and patterns; sanitize every saved setting (Customizer `sanitize_callback`, `register_setting`).
- Prefix (at least four letters, usually the slug): functions, classes, globals, constants, options, post meta, script and style handles, image sizes, `wp_script_add_data` keys and new pattern category slugs. Third-party library handles, menu locations and sidebar IDs need none. List each unprefixed name.
- i18n: every user-facing string in PHP, patterns (`patterns/*.php`), and JS (`wp.i18n`) uses the theme's text domain. Strings inside `templates/*.html` and `parts/*.html` can't be translated: move translatable text into a pattern (`patterns/*.php`) and reference it with `<!-- wp:pattern {"slug":"<slug>/<name>"} /-->`.

## 3. Plugin territory, plugins, privacy, remote resources (F7, W1–W2, P1, X2)
- Anything that keeps working or keeps data after the user switches themes is plugin territory: CPTs, taxonomies, shortcodes, custom blocks (`register_block_type`, `block.json`), roles, SEO meta, analytics, contact forms, social sharing, non-design meta boxes, caching. Block styles (`register_block_style`), block patterns, and block variations that only change presentation are fine.
- A companion plugin is the fix: "move <feature> to a plugin and recommend it from WordPress.org" (W1). Recommending needs the plugin to be on WordPress.org; TGMPA-style installers are fine only if the user clicks to install (W2), and `source` must point at WordPress.org.
- Every `wp_remote_*` call (inventory `remote_calls`): who is called, when, with what data, and is it behind an explicit opt-in (P1)? Docs in readme.txt (P2).
- Patterns and starter content: images must be in the theme (`get_theme_file_uri( 'assets/images/…' )`), not hot-linked from a CDN or the author's site (X2). Google Fonts is the only allowed remote resource; bundling fonts locally is still better for privacy and worth recommending.

## 4. Admin screens, notices, options, onboarding (F2, F3, O1–O4)
- Read every admin page (inventory `admin_pages`) and notice (`admin_notices`). Notices: dismissible, permanent once dismissed, shown only where useful, no popup or redirect on activation.
- One option, named after the slug, as an array (O3). List each extra `update_option`/`add_option` name.
- Demo importers, "install recommended plugins" walls, and remote calls in the onboarding screen are not allowed (O4).
- A WordPress feature (e.g. the site editor, a core block) locked behind "Pro" is F3.

## 5. Accessibility (A1–A3)
- Load the front page with the keyboard only (the `yayh release ui` screenshots help): Tab once shows the skip link? Every link and button gets a visible focus style? The menu opens with the keyboard? Note the selector that lacks a focus style.
- `outline: none` / `outline: 0` without a replacement `:focus-visible` style is the usual A2 finding: grep the CSS for it.

## 6. Credits, upsells, copyright (L5, S1–S4)
- Footer: at most one credit link to the Theme URI or Author URI, plus one to WordPress.org. A copyright line must be the site owner's (`© <year> <site name>`), never the theme author's.
- Upsell: an upgrade link in the Customizer or on the theme's own admin page is fine if not obtrusive; nothing on the front end (S2). Affiliate links disclosed (S3).
- Readme and tags: no keyword stuffing or competitor names (S4); tags from the Theme Tag List (X7).

## 7. Name (N1–N4)
- Apply `checklist.md` "Names (N3)" to every distinctive word of the Theme Name and slug. Search the Theme Directory for the name: a near-duplicate gets flagged too.

## 8. Block theme specifics (B1, B2)
- `theme.json` has a `version` and valid schema; templates and parts close every block comment they open. A broken template shows as a "Theme Check" REQUIRED or as a block recovery prompt in the Site Editor screenshot from `yayh release ui`.
- `templates/index.html` exists; other templates (`single`, `page`, `archive`, `404`, `search`) are recommended. Templates reference parts that exist.

## 9. Classic theme specifics (K1–K3)
- The hooks list in K2 is required; precheck confirms each exists somewhere, so open `header.php`/`footer.php` to confirm they're in the right place (`wp_head()` before `</head>`, `wp_body_open()` right after `<body>`, `wp_footer()` before `</body>`).
- The Customizer: every setting has a `sanitize_callback`; `edit_theme_options` for permissions.
