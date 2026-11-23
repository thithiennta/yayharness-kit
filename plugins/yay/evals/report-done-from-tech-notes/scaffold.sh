#!/usr/bin/env bash
set -euo pipefail
git init -q -b dev .
git config user.email eval@example.invalid; git config user.name eval; git config commit.gpgsign false
mkdir -p .yay includes
cat > .yay/config.json <<'JSON'
{ "schemaVersion": 1,
  "plugin": { "name": "Giftly", "slug": "giftly", "mainFile": "giftly.php", "textDomain": "giftly", "wporgSlug": null },
  "editions": ["free"], "requires": { "php": "7.4", "wp": "6.5", "wc": "9.0" },
  "git": { "baseBranch": "dev" },
  "commands": { "test": "php tests/run.php" },
  "versionFiles": [ { "file": "giftly.php", "pattern": "Version: *([0-9][^[:space:]]*)" } ] }
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

    public static function clean( string $text ): string {
        $text = trim( $text );
        return mb_strlen( $text ) > self::MAX ? mb_substr( $text, 0, self::MAX ) : $text;
    }
}
PHP
git add -A && git commit -q -m "feat(checkout): gift messages" --no-verify
