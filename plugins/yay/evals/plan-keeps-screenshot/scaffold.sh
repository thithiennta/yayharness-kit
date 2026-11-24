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
- status: todo
- size: S
- why: shoppers can't see how the card will look

## Later

### R-3 Scheduled delivery date
- status: todo
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
# The screenshot the developer attaches: outside docs/, untracked, like a file dragged in from the Desktop.
mkdir -p shots
printf '%s' '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' | base64 --decode > shots/preview-overlap.png
printf 'shots/\n' >> .git/info/exclude
