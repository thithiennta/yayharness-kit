# versions, changelog, zip checks (per JSON engine: config reads + json_set)

_rrepo() { # legacy-rich fixture with config, on dev, tagged v1.2.3 + one feat commit after
  local d; d="$(fixture_repo legacy-rich configured)" || return 1
  printf '%s\n' "$d"
}
_c() { # repo message [body]
  echo "$RANDOM" >> "$1/includes/Plugin.php"; git -C "$1" add -A
  if [ -n "${3:-}" ]; then git -C "$1" commit -q -m "$2" -m "$3" --no-verify; else git -C "$1" commit -q -m "$2" --no-verify; fi
}

test_version_list_check_set() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "1.2.3" "$("$YAYH" version current)"
  assert_eq "1.2.3" "$("$YAYH" version check)"
  "$YAYH" version set 1.3.0 >/dev/null
  assert_eq "1.3.0" "$("$YAYH" version check)"
  assert_contains "$(cat "$YAY_REPO/fixture-plugin.php")" "define( 'FIXTURE_PLUGIN_VERSION', '1.3.0' );"
  assert_contains "$(cat "$YAY_REPO/readme.txt")" "Stable tag: 1.3.0"
  assert_contains "$(cat "$YAY_REPO/readme.txt")" "Requires PHP: 7.4"          # untouched
  sed -i.bak 's/Stable tag: 1.3.0/Stable tag: 1.2.9/' "$YAY_REPO/readme.txt"
  assert_exit 1 "$YAYH" version check
  assert_fails "$YAYH" version set banana
  assert_eq "$("$YAYH" version)" "$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$KIT/.claude-plugin/plugin.json")"  # bare = kit version
}

test_version_tested() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  "$YAYH" version tested wp=6.9 wc=10.3 >/dev/null
  assert_contains "$(cat "$YAY_REPO/readme.txt")" "Tested up to: 6.9"
  assert_contains "$(cat "$YAY_REPO/fixture-plugin.php")" "WC tested up to: 10.3"
  assert_eq "6.9" "$("$YAYH" config get tested.wp)"
  assert_eq "10.3" "$("$YAYH" config get tested.wc)"
  assert_eq "dev" "$("$YAYH" config get git.baseBranch)"                         # rest of config intact
}

test_changelog_collect_parses_commits() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  _c "$YAY_REPO" "fix(checkout): keep the coupon field (#41)" "Root cause here.

Fixes: B-7"
  _c "$YAY_REPO" "feat!: drop the legacy API" "Roadmap: R-3
Plan: P-2"
  _c "$YAY_REPO" "refactor: tidy" "BREAKING CHANGE: hooks renamed"
  _c "$YAY_REPO" "Updated stuff"
  local out; out="$("$YAYH" changelog collect)"
  assert_contains "$out" "	feat	core	0	add a change after the tag			"
  assert_contains "$out" "	fix	checkout	0	keep the coupon field	41	B-7		"
  assert_contains "$out" "	feat		1	drop the legacy API			R-3	P-2"
  assert_contains "$out" "	refactor		1	tidy"
  assert_contains "$out" "	other		0	Updated stuff"
  case "$out" in *"chore(harness)"*|*"	chore	harness	"*) _pass;; *) _fail "chore commit missing";; esac
  assert_eq "major" "$("$YAYH" changelog suggest)"
  assert_eq "5" "$("$YAYH" changelog collect --since=HEAD~5 | grep -c .)"
}

test_changelog_suggest_levels() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  git -C "$YAY_REPO" tag -a v1.3.0 -m x
  assert_eq "none" "$("$YAYH" changelog suggest)"
  _c "$YAY_REPO" "docs: readme"; assert_eq "none" "$("$YAYH" changelog suggest)"
  _c "$YAY_REPO" "fix: one"; assert_eq "patch" "$("$YAYH" changelog suggest)"
  _c "$YAY_REPO" "feat(core): two"; assert_eq "minor" "$("$YAYH" changelog suggest)"
}

test_changelog_style_detects_repo_conventions() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_contains "$("$YAYH" changelog style)" "heading	= {version} - {date} ="
  cat > "$YAY_REPO/readme.txt" <<'EOF'
=== X ===
Stable tag: 1.2.3

== Changelog ==

= 1.2.3 =
- New: a thing.
- Fix: a bug.

= 1.2.2 =
- Tweak: old.

== Upgrade Notice ==
EOF
  local s; s="$("$YAYH" changelog style)"
  assert_contains "$s" "heading	= {version} ="
  assert_contains "$s" "bullet	-"
  assert_contains "$s" "labels	New, Fix, Tweak"
  assert_contains "$s" "entries	2"
}

test_changelog_write_insert_refuse_replace_entry() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local b="$T_TMP/b.$RANDOM"; printf '* New: express buttons.\n* Fix: coupon field.\n' > "$b"
  "$YAYH" changelog write 1.3.0 "$b" --date=2026-11-24 >/dev/null
  local r; r="$(cat "$YAY_REPO/readme.txt")"
  assert_contains "$r" "== Changelog ==

= 1.3.0 - 2026-11-24 =
* New: express buttons.
* Fix: coupon field.

= 1.2.3 - 2026-10-01 ="
  assert_fails "$YAYH" changelog write 1.3.0 "$b"
  printf '* Fix: only this.\n' > "$b"
  "$YAYH" changelog write 1.3.0 "$b" --date=2026-11-25 --replace >/dev/null
  assert_eq "1" "$(grep -c '^= 1.3.0' "$YAY_REPO/readme.txt")"
  assert_eq "* Fix: only this." "$("$YAYH" changelog entry 1.3.0)"
  assert_eq "* Fix: something." "$("$YAYH" changelog entry 1.2.3)"
}

_zip() { # repo topfolder [extra-file...] -> zip path
  local r="$1" top="$2"; shift 2
  local stage="$T_TMP/stage.$RANDOM"; mkdir -p "$stage/$top"
  (cd "$r" && cp -R fixture-plugin.php readme.txt includes "$stage/$top/")
  local f; for f in "$@"; do mkdir -p "$(dirname "$stage/$top/$f")"; echo x > "$stage/$top/$f"; done
  mkdir -p "$r/release"; local z="$r/release/fixture-plugin-$RANDOM.zip"
  (cd "$stage" && zip -qr "$z" "$top")
  printf '%s\n' "$z"
}

test_zip_check_pass_and_warn() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  rm -rf "$YAY_REPO/includes/Pro"
  local z; z="$(_zip "$YAY_REPO" fixture-plugin composer.json)"
  local out; out="$("$YAYH" build check "$z" edition=free version=1.2.3)"; local rc=$?
  assert_eq 0 "$rc" "exit"
  assert_contains "$out" "PASS	folder	single top folder fixture-plugin/"
  assert_contains "$out" "PASS	dev-files"
  assert_contains "$out" "WARN	dev-files	usually not shipped: composer.json"
  assert_contains "$out" "PASS	edition	no includes/Pro/ in the free zip"
  assert_contains "$out" "PASS	version	fixture-plugin.php Version: 1.2.3"
  assert_contains "$out" "PASS	php-syntax"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["package"]["allow"]=["composer.json"]; json.dump(c,open(p,"w"))
PY
  case "$("$YAYH" build check "$z" edition=free)" in *WARN*) _fail "allow ignored";; *) _pass;; esac
}

test_zip_check_failures() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local z out
  z="$(_zip "$YAY_REPO" fixture-plugin .claude/settings.json CLAUDE.md)"     # includes/Pro is in the fixture
  out="$("$YAYH" build check "$z" edition=free version=9.9.9)"
  assert_exit 1 "$YAYH" build check "$z" edition=free
  assert_contains "$out" "FAIL	dev-files"
  assert_contains "$out" "FAIL	edition	free zip contains forbidden paths: includes/Pro/"
  assert_contains "$out" "FAIL	version	fixture-plugin.php header says 1.2.3, expected 9.9.9"
  assert_contains "$out" "FAIL	stable-tag"
  case "$("$YAYH" build check "$z" edition=pro)" in *"FAIL	edition"*) _fail "pro has no forbidden list";; *) _pass;; esac
  z="$(_zip "$YAY_REPO" wrong-name)"
  assert_contains "$("$YAYH" build check "$z")" "WARN	folder	top folder is wrong-name/"
  printf '<?php\nfunction ( {\n' > "$YAY_REPO/includes/Broken.php"
  z="$(_zip "$YAY_REPO" fixture-plugin)"
  assert_contains "$("$YAYH" build check "$z")" "FAIL	php-syntax"
}

test_zip_check_runs_repo_checks_and_finds_zip() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["checks"]=["test -f {zip}", "unzip -l {zip} | grep -q nothing-like-this"]
c["package"]["output"]="release/{slug}-*.zip"; json.dump(c,open(p,"w"))
PY
  local z; z="$(_zip "$YAY_REPO" fixture-plugin)"
  local out; out="$("$YAYH" build check "$z")"
  assert_contains "$out" "PASS	check	test -f $z"
  assert_contains "$out" "FAIL	check	unzip -l $z"
  assert_eq "$z" "$YAY_REPO/$("$YAYH" build zip)"
}

test_baseline_without_tags_and_per_edition_output() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  git -C "$YAY_REPO" tag -d v1.2.3 >/dev/null
  local first; first="$(git -C "$YAY_REPO" log --format=%h --reverse | sed -n 1p)"
  assert_eq "$first	first-appearance" "$("$YAYH" changelog baseline)"
  assert_eq "2" "$("$YAYH" changelog collect | grep -c .)"       # the commits after the one that introduced 1.2.3
  _c "$YAY_REPO" "chore(release): 1.2.3"
  assert_eq "$(git -C "$YAY_REPO" rev-parse --short HEAD)	release-commit" "$("$YAYH" changelog baseline)"
  git -C "$YAY_REPO" tag -a v1.2.3 -m x "$first"
  assert_eq "v1.2.3	tag" "$("$YAYH" changelog baseline)"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["package"]["output"]={"pro":"release/{slug}-{version}.zip","free":"release/{slug}-free-{version}.zip"}; json.dump(c,open(p,"w"))
PY
  mkdir -p "$YAY_REPO/release"; touch "$YAY_REPO/release/fixture-plugin-1.3.0.zip" "$YAY_REPO/release/fixture-plugin-free-1.3.0.zip"
  assert_eq "release/fixture-plugin-1.3.0.zip" "$("$YAYH" build zip edition=pro version=1.3.0)"
  assert_eq "release/fixture-plugin-free-1.3.0.zip" "$("$YAYH" build zip edition=free version=1.3.0)"
  assert_fails "$YAYH" build zip edition=lite version=1.3.0
}

test_forbidden_follows_edition_names_and_validate_guards() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq '["includes/Pro/"]' "$(jq -c .package.forbidden.free "$YAY_REPO/.yay/config.json")"
  assert_ok "$YAYH" config validate
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["editions"]=["pro","lite"]; json.dump(c,open(p,"w"))
PY
  assert_contains "$("$YAYH" config validate 2>&1)" "package.forbidden has key 'free', which is not in editions"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["package"]["forbidden"]={}; json.dump(c,open(p,"w"))
PY
  assert_contains "$("$YAYH" config validate 2>&1)" "includes/Pro exists but package.forbidden"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["package"]["forbidden"]={"lite":["includes/Pro/"]}; json.dump(c,open(p,"w"))
PY
  assert_ok "$YAYH" config validate
}

test_merged_worktrees() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local a b; a="$("$YAYH" git worktree feat/merged-one)"; b="$("$YAYH" git worktree feat/open-one)"
  echo x > "$a/x.txt"; git -C "$a" add -A; git -C "$a" commit -qm "feat: x" --no-verify
  echo y > "$b/y.txt"; git -C "$b" add -A; git -C "$b" commit -qm "feat: y" --no-verify
  git -C "$YAY_REPO" merge -q --no-ff feat/merged-one -m "merge"
  assert_eq "$a	feat/merged-one" "$("$YAYH" git merged-worktrees)"
}

test_release_check_gates_version_stable_tag_changelog_notes() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local out
  out="$("$YAYH" release check 1.2.3)"; assert_exit 1 "$YAYH" release check 1.2.3
  assert_contains "$out" "FAIL	newer	1.2.3 is not newer than the last release 1.2.3"
  "$YAYH" version set 1.3.0 >/dev/null
  out="$("$YAYH" release check 1.3.0 || true)"
  assert_contains "$out" "PASS	version	every version file says 1.3.0"
  assert_contains "$out" "PASS	stable-tag	Stable tag: 1.3.0"
  assert_contains "$out" "FAIL	changelog	no changelog entry for 1.3.0"
  assert_contains "$out" "FAIL	notes	no docs/releases/1.3.0.md"
  printf '* Fix: TODO write this.\n' > "$T_TMP/b.txt"; "$YAYH" changelog write 1.3.0 "$T_TMP/b.txt" >/dev/null
  assert_contains "$("$YAYH" release check 1.3.0 || true)" "FAIL	changelog	the 1.3.0 entry has placeholder text"
  printf '* Fix: the coupon field stays after a shipping change.\n' > "$T_TMP/b.txt"; "$YAYH" changelog write 1.3.0 "$T_TMP/b.txt" --replace >/dev/null
  mkdir -p "$YAY_REPO/docs/releases"; printf -- '---\nversion: 1.3.0\n---\n' > "$YAY_REPO/docs/releases/1.3.0.md"
  assert_ok "$YAYH" release check 1.3.0
  sed -i.bak 's/^Stable tag: .*/Stable tag: trunk/' "$YAY_REPO/readme.txt"
  assert_contains "$("$YAYH" release check 1.3.0 || true)" "FAIL	stable-tag	Stable tag is trunk, expected 1.3.0"
  sed -i.bak 's/^Stable tag: .*/Stable tag: 1.3.0/' "$YAY_REPO/readme.txt"
  "$YAYH" version set 1.3.0-rc.1 >/dev/null
  out="$("$YAYH" release check 1.3.0-rc.1 --rc || true)"
  assert_contains "$out" "PASS	version	every version file says 1.3.0-rc.1"
  assert_contains "$out" "PASS	newer	1.3.0-rc.1 is newer than the last release 1.2.3"
  assert_contains "$out" "(not checked for a test bundle)"
}

test_release_size_compares_with_recorded_baseline_and_records() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local z out
  z="$(_zip "$YAY_REPO" fixture-plugin)"
  mkdir -p "$YAY_REPO/docs/releases"
  printf -- '---\nversion: 1.2.0\n---\n' > "$YAY_REPO/docs/releases/1.2.0.md"
  printf -- '---\nversion: 1.4.0\n---\n' > "$YAY_REPO/docs/releases/1.4.0.md"
  out="$("$YAYH" release size "$z" edition=free version=1.3.0)"
  assert_contains "$out" "WARN	baseline	no earlier release recorded its free zip size"
  "$YAYH" release size "$z" edition=free version=1.2.0 --record=docs/releases/1.2.0.md >/dev/null
  "$YAYH" fm set "$YAY_REPO/docs/releases/1.4.0.md" zip_bytes_free 1 >/dev/null   # newer than 1.3.0: never the baseline
  out="$("$YAYH" release size "$z" edition=free version=1.3.0)"
  assert_contains "$out" "OK	size-change	+0% (0 B) vs 1.2.0"
  assert_contains "$out" "OK	file-count	+0 files vs 1.2.0"
  local st="$T_TMP/big.$RANDOM"; mkdir -p "$st/fixture-plugin"
  (cd "$YAY_REPO" && cp -R fixture-plugin.php readme.txt includes "$st/fixture-plugin/")
  head -c 3000000 /dev/urandom > "$st/fixture-plugin/big.bin"
  z="$YAY_REPO/release/big-$RANDOM.zip"; (cd "$st" && zip -qr "$z" fixture-plugin)
  out="$("$YAYH" release size "$z" edition=free version=1.3.0)"
  assert_contains "$out" "UNUSUAL	size-change"
  assert_contains "$out" "UNUSUAL	large-file	fixture-plugin/big.bin (2.9 MB)"
}

test_release_next_rc_and_bundle_manifest() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local z d
  z="$(_zip "$YAY_REPO" fixture-plugin)"
  assert_eq "1.3.0-rc.1" "$("$YAYH" release next-rc 1.3.0)"
  d="$("$YAYH" release bundle 1.3.0-rc.1 free="$z" 2>/dev/null)"
  assert_eq "$YAY_REPO/release/bundles/fixture-plugin-1.3.0-rc.1" "$d"
  assert_file "$d/$(basename "$z")"
  assert_contains "$(cat "$d/MANIFEST.txt")" "free	$(basename "$z")	$(wc -c < "$z" | tr -d ' ')"
  assert_contains "$(cat "$d/files-free.txt")" "fixture-plugin/fixture-plugin.php"
  assert_eq "1.3.0-rc.2" "$("$YAYH" release next-rc 1.3.0)"
  assert_exit 1 "$YAYH" release bundle 1.3.0-rc.1 free="$z"
  assert_ok "$YAYH" release bundle 1.3.0-rc.1 free="$z" --replace
  assert_fails "$YAYH" release next-rc 1.3
}
