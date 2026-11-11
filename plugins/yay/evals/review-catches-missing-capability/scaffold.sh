#!/usr/bin/env bash
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay docs/bugs docs/plans docs/brainstorms docs/backlog docs/knowledge includes
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Giftly", "slug": "giftly", "mainFile": "giftly.php", "textDomain": "giftly", "wporgSlug": null },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "6.5", "wc": "9.0" },
  "git": { "baseBranch": "dev" },
  "commands": { "test": "php tests/run.php" },
  "versionFiles": [ { "file": "giftly.php", "pattern": "Version: *([0-9][^[:space:]]*)" }, { "file": "readme.txt", "pattern": "^Stable tag: *([0-9][^[:space:]]*)" } ] }
JSON
cat > giftly.php <<'PHP'
<?php
/**
 * Plugin Name: Giftly
 * Version: 1.2.0
 * Text Domain: giftly
 */
defined( 'ABSPATH' ) || exit;
require __DIR__ . '/includes/GiftMessage.php';
PHP
cat > includes/GiftMessage.php <<'PHP'
<?php
namespace Giftly;

/** Gift messages typed at checkout. */
final class GiftMessage {
    const MAX = 200;

    /** Trim and cap a message; messages of exactly MAX characters are allowed. */
    public static function clean( string $text ): string {
        $text = trim( $text );
        return strlen( $text ) >= self::MAX ? substr( $text, 0, self::MAX - 1 ) : $text;
    }
}
PHP
mkdir -p tests
cat > tests/run.php <<'PHP'
<?php
define( 'ABSPATH', __DIR__ );
require __DIR__ . '/../includes/GiftMessage.php';
$ok = Giftly\GiftMessage::clean( '  hi  ' ) === 'hi';
echo $ok ? "ok
" : "FAIL
"; exit( $ok ? 0 : 1 );
PHP
cat > readme.txt <<'TXT'
=== Giftly ===
Stable tag: 1.2.0

== Changelog ==

= 1.2.0 - 2026-10-01 =
* New: Gift messages at checkout.
TXT
cat > docs/roadmap.md <<'MD'
---
horizon: 2026-12-31
sprint_length: 2w
updated: 2026-10-20
---
# Roadmap: Giftly

## Sprint 1 (2026-10-20 → 2026-11-02)

### R-1 Gift wrap option
- status: in-progress
- size: M
- why: most-requested feature in the support forum

## Sprint 2 (2026-11-03 → 2026-11-16)

### R-2 Gift message preview
- status: planned
- size: S
- why: shoppers can't see how the card will look

## Later

### R-3 Scheduled delivery date
- status: planned
- size: L
MD
cat > docs/bugs/2026-11-05-checkout-crash-on-emoji.md <<'MD'
---
id: B-1
title: Checkout crashes when the gift message has an emoji
status: root-caused
severity: high
editions: [free]
found_in: 1.2.0
fixed_in:
branch:
pr:
created: 2026-11-05
---
# B-1 Checkout crashes when the gift message has an emoji
MD
git add -A && git commit -qm "chore: fixture"
# The branch under review: a settings save handler with no nonce and no capability check.
git switch -q -c feat/gift-settings
cat > includes/Settings.php <<'PHP'
<?php
namespace Giftly;

/** Stores the gift message settings. */
final class Settings {
    const OPTION = 'giftly_settings';

    public static function init() {
        add_action( 'admin_post_giftly_save', array( __CLASS__, 'save' ) );
    }

    /** Saves the settings form. */
    public static function save() {
        $max = isset( $_POST['max_length'] ) ? absint( $_POST['max_length'] ) : GiftMessage::MAX;
        update_option( self::OPTION, array( 'max_length' => $max ) );
        wp_safe_redirect( admin_url( 'admin.php?page=giftly' ) );
        exit;
    }
}
PHP
printf "require __DIR__ . '/includes/Settings.php';\nGiftly\\\\Settings::init();\n" >> giftly.php
git add -A && git commit -qm "feat(settings): save the gift message max length"
