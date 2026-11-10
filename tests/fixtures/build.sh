#!/usr/bin/env bash
# Build a fixture plugin repo: tests/fixtures/build.sh <kind> <dest>
#   legacy-rich      yaycheckout-like: CLAUDE.md, .claude/{skills,rules,hooks}, docs/*, Free/Pro
#   legacy-notibar   Notibar-like: no CLAUDE.md, docs/journals + PDR, .claude/agent-memory
#   legacy-currency  YayCurrency-like: .claude/CLAUDE.md, .claude/docs, w* skills
#   bare             a plugin with no harness at all
# Every repo also has untracked/personal files the wipe must keep.
set -euo pipefail
kind="${1:?kind}"; dest="${2:?dest}"
mkdir -p "$dest"; cd "$dest"
git init -q -b dev
git config user.email test@example.invalid; git config user.name test
git config commit.gpgsign false; git config tag.gpgsign false

slug="fixture-plugin"
w() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

w "$slug.php" <<EOF
<?php
/**
 * Plugin Name: Fixture Plugin
 * Version: 1.2.3
 * Text Domain: $slug
 * Requires PHP: 7.4
 * WC tested up to: 9.4
 */
define( 'FIXTURE_PLUGIN_VERSION', '1.2.3' );
EOF
w readme.txt <<'EOF'
=== Fixture Plugin ===
Stable tag: 1.2.3
Tested up to: 6.7
Requires PHP: 7.4

== Changelog ==

= 1.2.3 - 2026-10-01 =
* Fix: something.
EOF
w composer.json <<'EOF'
{ "name": "yaycommerce/fixture-plugin", "require": { "php": ">=7.4" }, "scripts": { "lint": "phpcs", "test": "phpunit" } }
EOF
w includes/Plugin.php <<'EOF'
<?php
namespace Fixture;
class Plugin { public function boot() {} }
EOF
w .gitignore <<'EOF'
vendor/
node_modules/
release/
EOF

case "$kind" in
  legacy-rich)
    w package.json <<'EOF'
{ "name": "fixture-plugin", "private": true, "packageManager": "pnpm@11.0.0", "scripts": { "build": "vite build", "lint": "eslint ." } }
EOF
    w includes/Pro/ProServiceProvider.php <<'EOF'
<?php
namespace Fixture\Pro;
class ProServiceProvider {}
EOF
    w scripts/run.sh <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  dev) echo dev ;;
  build) echo build ;;
  release) echo "release $*" ;;
esac
EOF
    chmod +x scripts/run.sh
    w CLAUDE.md <<'EOF'
# Fixture Plugin
Old harness CLAUDE.md. Hard rule: never edit assets/dist/.
EOF
    w .claude/settings.json <<'EOF'
{ "hooks": { "PreToolUse": [ { "matcher": "Edit", "hooks": [ { "type": "command", "command": ".claude/hooks/guard-generated-paths.sh" } ] } ] } }
EOF
    w .claude/hooks/guard-generated-paths.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    w .claude/rules/php-standards.md <<< '# PHP standards (old)'
    w .claude/rules/release.md <<< '# Release (old)'
    w .claude/skills/yayplan/SKILL.md <<'EOF'
---
name: yayplan
description: old plan skill
---
old
EOF
    w .claude/skills/yayrelease/SKILL.md <<'EOF'
---
name: yayrelease
description: old release skill
---
old
EOF
    w docs/architecture.md <<< '# Architecture (old)'
    w docs/known-issues.md <<< '# Known issues (old)'
    w docs/decisions/0001-free-pro.md <<< '# ADR 1'
    w docs/plans/old-plan.md <<< '# Old plan'
    w docs/backlog/idea.md <<< '# Idea'
    w AGENTS.md <<< '# Agents (old)'
    w assets/dist/admin/app.js <<< 'console.log(1)'
    ;;
  legacy-notibar)
    w package.json <<'EOF'
{ "name": "notibar-fixture", "private": true, "scripts": { "build": "wp-scripts build" } }
EOF
    w .claude/agent-memory/notes.md <<< 'memory'
    w .claude/skills/yaychangelog/SKILL.md <<'EOF'
---
name: yaychangelog
description: old changelog
---
old
EOF
    w docs/project-overview-pdr.md <<< '# PDR'
    w docs/project-roadmap.md <<< '# Roadmap (old)'
    w docs/journals/2026-10-01.md <<< '# Journal'
    w docs/code-standards.md <<< '# Code standards'
    ;;
  legacy-currency)
    w package.json <<'EOF'
{ "name": "currency-fixture", "private": true, "scripts": { "build": "webpack" } }
EOF
    w .claude/CLAUDE.md <<< '# Currency (old, inside .claude)'
    w .claude/docs/setup.md <<< '# setup'
    w .claude/hooks/stop-check.sh <<< 'exit 0'
    w .claude/skills/wplan/SKILL.md <<'EOF'
---
name: wplan
description: old
---
old
EOF
    w .claude/settings.json <<< '{}'
    w .cursorrules <<< 'cursor rules'
    ;;
  bare) ;;
  *) echo "unknown fixture kind: $kind" >&2; exit 2 ;;
esac

git add -A
git commit -q -m "chore: fixture $kind" --no-verify
git tag -a v1.2.3 -m v1.2.3
w src-change.txt <<< 'change after tag'
git add -A; git commit -q -m "feat(core): add a change after the tag" --no-verify

# Personal / untracked files the wipe must never touch.
w .claude/settings.local.json <<< '{ "permissions": { "allow": [] } }'
w .claude/worktrees/feature-x/README <<< 'worktree placeholder'
w CLAUDE.local.md <<< 'personal notes'
w docs/untracked-notes.md <<< 'not committed'
echo "$dest"
