# knowledge check / stale / stamp

_krepo() { # initialized, committed bare fixture on dev with harness merged
  local d; d="$(fixture_repo legacy-rich harnessed)" || return 1
  printf '%s\n' "$d"
}

_write_docs() { # repo
  local r="$1"
  cat > "$r/docs/knowledge/architecture.md" <<'MD'
---
area: architecture
updated:
updated_ref:
covers: [includes/, fixture-plugin.php]
---
# Architecture
> Update when: boot or storage changes.

Boot: `fixture-plugin.php` → `includes/Plugin.php` (`Plugin::boot()`, `Plugin.php:3`). Pro: `includes/Pro/ProServiceProvider.php`.
Generated: `assets/dist/admin/app.js`. Placeholder: `composer lint -- <files>`. Glob: `includes/*.php`.
See [known issues](known-issues.md) and [WC](https://woocommerce.com).
```
`includes/OnlyInFence.php`
```
MD
  cat > "$r/docs/knowledge/known-issues.md" <<'MD'
---
area: known-issues
updated:
updated_ref:
covers: [scripts/, package.json]
---
# Known issues
> Update when: a trap is found or fixed.

- `scripts/run.sh release` needs a version.
MD
  python3 -I - "$r/CLAUDE.md" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'(<!-- yay:project:start[^>]*-->\n).*?(\n<!-- yay:project:end -->)', r'\1## What this is\nFixture plugin. Boot in `includes/Plugin.php`.\n\n## Read when…\n- changing boot → [architecture](docs/knowledge/architecture.md)\2', s, flags=re.S)
open(p,'w').write(s)
PY
}

test_check_passes_on_good_docs_after_stamp() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  assert_exit 1 "$YAYH" knowledge check                      # unstamped CLAUDE.md
  "$YAYH" knowledge stamp CLAUDE.md >/dev/null
  "$YAYH" knowledge stamp docs/knowledge/architecture.md >/dev/null
  "$YAYH" knowledge stamp docs/knowledge/known-issues.md >/dev/null
  local out; out="$("$YAYH" knowledge check 2>&1)"
  assert_eq "" "$out"
  assert_ok "$YAYH" knowledge check
}

test_check_reports_missing_paths_links_and_frontmatter() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  printf 'Also `includes/Nope.php`, `Gone.php`, and [x](missing.md).\n' >> "$YAY_REPO/docs/knowledge/architecture.md"
  printf 'WooCommerce sits at `../woocommerce/woocommerce.php` and `/etc/hosts`.\n' >> "$YAY_REPO/docs/knowledge/architecture.md"
  printf -- '---\narea: x\n---\n# Bad\n' > "$YAY_REPO/docs/knowledge/bad.md"
  local out; out="$("$YAYH" knowledge check 2>&1)"
  assert_contains "$out" "path \`includes/Nope.php\` does not exist"
  assert_contains "$out" "file \`Gone.php\` is not in the repo"
  assert_contains "$out" "link target 'missing.md' does not exist"
  assert_contains "$out" "bad.md:1: front-matter is missing 'covers'"
  case "$out" in *woocommerce.php*|*/etc/hosts*|*OnlyInFence*|*app.js*|*'<files>'*|*'*.php'*|*Plugin.php:3*) _fail "false positive: $out";; *) _pass;; esac
}

test_check_flags_placeholder_and_budget() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  assert_contains "$("$YAYH" knowledge check CLAUDE.md 2>&1)" "still the placeholder"
  _write_docs "$YAY_REPO"
  python3 -I - "$YAY_REPO/CLAUDE.md" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("## Read when", "\n".join("- line %d" % i for i in range(95)) + "\n## Read when")
open(p,'w').write(s)
PY
  assert_contains "$("$YAYH" knowledge check CLAUDE.md 2>&1)" "budget is 90"
}

test_stamp_sets_frontmatter_and_marker() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  local head; head="$(git -C "$YAY_REPO" rev-parse --short HEAD)"
  "$YAYH" knowledge stamp docs/knowledge/architecture.md >/dev/null
  assert_eq "$head" "$("$YAYH" fm get "$YAY_REPO/docs/knowledge/architecture.md" updated_ref)"
  "$YAYH" knowledge stamp CLAUDE.md >/dev/null
  assert_contains "$(cat "$YAY_REPO/CLAUDE.md")" "<!-- yay:project:start ref=$head updated="
  assert_ok "$YAYH" harness sync --check                         # managed block untouched
  assert_fails "$YAYH" knowledge stamp CLAUDE.md deadbeef
}

test_stale_tracks_covers_project_watch_and_uncovered() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  for d in CLAUDE.md docs/knowledge/architecture.md docs/knowledge/known-issues.md; do "$YAYH" knowledge stamp "$d" >/dev/null; done
  git -C "$YAY_REPO" add -A; git -C "$YAY_REPO" commit -qm "docs(knowledge): write" --no-verify
  # Docs commit itself and generated output must not make anything stale.
  mkdir -p "$YAY_REPO/assets/dist"; echo x > "$YAY_REPO/assets/dist/new.js"; git -C "$YAY_REPO" add -f assets/dist/new.js
  git -C "$YAY_REPO" commit -qm "build: assets" --no-verify
  assert_ok "$YAYH" knowledge stale
  # Code change under covers -> architecture stale only.
  echo "// x" >> "$YAY_REPO/includes/Plugin.php"; git -C "$YAY_REPO" commit -qam "fix(core): x" --no-verify
  local out; out="$("$YAYH" knowledge stale)"
  assert_contains "$out" "stale	docs/knowledge/architecture.md	includes/Plugin.php"
  assert_contains "$out" "fresh	docs/knowledge/known-issues.md"
  assert_contains "$out" "fresh	CLAUDE.md"
  # composer.json is watched by the project block; a new top dir is uncovered.
  echo '{}' > "$YAY_REPO/composer.json"; mkdir -p "$YAY_REPO/src"; echo x > "$YAY_REPO/src/New.php"
  git -C "$YAY_REPO" add -A; git -C "$YAY_REPO" commit -qm "feat: new area" --no-verify
  out="$("$YAYH" knowledge stale)"
  assert_contains "$out" "stale	CLAUDE.md	composer.json"
  assert_contains "$out" "uncovered	src/New.php"
  assert_exit 1 "$YAYH" knowledge stale
  # Restamp clears it.
  "$YAYH" knowledge stamp docs/knowledge/architecture.md >/dev/null; "$YAYH" knowledge stamp CLAUDE.md >/dev/null
  assert_contains "$("$YAYH" knowledge stale)" "fresh	docs/knowledge/architecture.md"
}

test_stale_never_badref_and_since() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  local out; out="$("$YAYH" knowledge stale)"
  assert_contains "$out" "never	docs/knowledge/architecture.md"
  "$YAYH" fm set "$YAY_REPO/docs/knowledge/architecture.md" updated_ref 0000000
  assert_contains "$("$YAYH" knowledge stale)" "bad-ref	docs/knowledge/architecture.md	0000000"
  out="$("$YAYH" knowledge stale --since=v1.2.3)"
  assert_contains "$out" "stale	CLAUDE.md	.yay/config.json"        # harness commit is after the tag
  assert_contains "$out" "fresh	docs/knowledge/known-issues.md"     # nothing under its covers changed
  assert_fails "$YAYH" knowledge stale --since=nope-ref
}

test_check_skips_paths_outside_the_repo() {
  export YAY_REPO; YAY_REPO="$(_krepo)"
  _write_docs "$YAY_REPO"
  printf 'Theme overrides of `myaccount/orders.php` drop it; but `includes/Typo.php` must exist.\n' >> "$YAY_REPO/docs/knowledge/architecture.md"
  local out; out="$("$YAYH" knowledge check docs/knowledge/architecture.md 2>&1)"
  case "$out" in *myaccount*) _fail "external path flagged: $out";; *) _pass;; esac
  assert_contains "$out" "includes/Typo.php"
}
