# engine-independent
# artifact new/resolve/list/carry, plan tasks/tick/check, id conflicts, run, debug markers

FIX="${KIT%/plugins/yay}/tests/fixtures/build.sh"

_arepo() { # initialized fixture, harness merged into dev, on dev
  local d="$T_TMP/a.$RANDOM"
  "$FIX" bare "$d" >/dev/null
  git -C "$d" switch -q -c chore/yay-harness
  YAY_REPO="$d" "$YAYH" harness wipe --yes >/dev/null
  mkdir -p "$d/.yay"; YAY_REPO="$d" "$YAYH" harness detect 2>/dev/null > "$d/.yay/config.json"
  YAY_REPO="$d" "$YAYH" harness sync >/dev/null
  git -C "$d" add -A; git -C "$d" commit -qm "chore(harness): install" --no-verify
  git -C "$d" switch -q dev; git -C "$d" merge -q --ff-only chore/yay-harness
  printf '%s\n' "$d"
}

test_new_creates_each_type_with_ids_and_frontmatter() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local b p g l today; today="$(date +%Y-%m-%d)"
  b="$("$YAYH" artifact new brainstorm "Express checkout buttons" from=R-3)"
  p="$("$YAYH" artifact new plan "Express checkout buttons" from=BS-1 roadmap=R-3)"
  g="$("$YAYH" artifact new bug "Coupon field vanishes" severity=high)"
  l="$("$YAYH" artifact new backlog "Import from URL")"
  assert_eq "docs/brainstorms/$today-express-checkout-buttons.md" "$b"
  assert_eq "docs/plans/express-checkout-buttons.md" "$p"
  assert_eq "docs/bugs/$today-coupon-field-vanishes.md" "$g"
  assert_eq "docs/backlog/import-from-url.md" "$l"
  assert_eq "BS-1" "$("$YAYH" fm get "$YAY_REPO/$b" id)"
  assert_eq "R-3" "$("$YAYH" fm get "$YAY_REPO/$b" from)"
  assert_eq "P-1" "$("$YAYH" fm get "$YAY_REPO/$p" id)"
  assert_eq "draft" "$("$YAYH" fm get "$YAY_REPO/$p" status)"
  assert_eq "feat" "$("$YAYH" fm get "$YAY_REPO/$p" type)"
  assert_eq "[free]" "$("$YAYH" fm get "$YAY_REPO/$p" editions)"
  assert_eq "high" "$("$YAYH" fm get "$YAY_REPO/$g" severity)"
  assert_eq "B-1" "$("$YAYH" fm get "$YAY_REPO/$g" id)"
  assert_contains "$(cat "$YAY_REPO/$b")" "PHP 7.4+"
  assert_fails grep -q '{{' "$YAY_REPO/$b" "$YAY_REPO/$p" "$YAY_REPO/$g" "$YAY_REPO/$l"
  assert_eq "BS-2" "$("$YAYH" id next BS)"
}

test_new_rejects_bad_input_and_duplicates() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  assert_fails "$YAYH" artifact new idea "x"
  assert_fails "$YAYH" artifact new plan ""
  assert_fails "$YAYH" artifact new plan "X" type=wip
  assert_fails "$YAYH" artifact new bug "X" severity=urgent
  assert_fails "$YAYH" artifact new plan "X" color=red
  "$YAYH" artifact new plan "Same title" >/dev/null
  assert_fails "$YAYH" artifact new plan "Same title"
}

test_resolve_by_id_slug_path_and_list() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local p; p="$("$YAYH" artifact new plan "Express checkout")"
  "$YAYH" artifact new plan "Express shipping" >/dev/null
  assert_eq "$p" "$("$YAYH" artifact resolve P-1)"
  assert_eq "$p" "$("$YAYH" artifact resolve "$p")"
  assert_eq "$p" "$("$YAYH" artifact resolve "Express checkout")"
  assert_fails "$YAYH" artifact resolve express          # ambiguous
  assert_fails "$YAYH" artifact resolve P-9
  assert_eq "2" "$("$YAYH" artifact list plan | grep -c .)"
  "$YAYH" fm set "$YAY_REPO/$p" status ready
  assert_eq "P-1	ready	Express checkout	$p" "$("$YAYH" artifact list plan --status=ready)"
}

_plan_with_tasks() {
  local p; p="$("$YAYH" artifact new plan "Tasks plan")"
  python3 -I - "$YAY_REPO/$p" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("- [ ] T1 <what> — `path/to/file.php`", "- [ ] T1 Add the setting — `includes/Plugin.php`\n  - detail bullet\n- [ ] T2 Wire the UI (no files)\n- [ ] T10 Docs — `readme.txt`")
s=s.replace("## Verify\n<!-- Exact checks: the command or UI path, and the result that means it passed. -->\n-", "## Verify\n- Open Settings → see the toggle.")
open(p,'w').write(s)
PY
  printf '%s\n' "$p"
}

test_plan_tasks_tick_and_untick() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local p; p="$(_plan_with_tasks)"
  assert_eq "T1	open	Add the setting — \`includes/Plugin.php\`
T2	open	Wire the UI (no files)
T10	open	Docs — \`readme.txt\`" "$("$YAYH" plan tasks P-1)"
  "$YAYH" plan tick P-1 T1 >/dev/null
  assert_contains "$("$YAYH" plan tasks P-1)" "T1	done"
  "$YAYH" plan tick P-1 T1 >/dev/null                    # idempotent
  assert_contains "$(cat "$YAY_REPO/$p")" "- [x] T1 Add the setting"
  "$YAYH" plan tick P-1 T1 --undo >/dev/null
  assert_contains "$("$YAYH" plan tasks P-1)" "T1	open"
  "$YAYH" plan tick P-1 T10 >/dev/null
  assert_contains "$("$YAYH" plan tasks P-1)" "T10	done"
  assert_contains "$("$YAYH" plan tasks P-1)" "T1	open"   # T1 not confused with T10
  assert_fails "$YAYH" plan tick P-1 T7
  assert_fails "$YAYH" plan tick P-1 seven
}

test_plan_check() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local p out; p="$(_plan_with_tasks)"
  out="$("$YAYH" plan check P-1)"; assert_eq "0" "$?"
  assert_contains "$out" "warn: task T10 is out of order (expected T3)"
  local q; q="$("$YAYH" artifact new plan "Empty plan")"     # template: Verify empty, placeholder task
  out="$("$YAYH" plan check P-2 2>&1)"
  assert_contains "$out" "error: '## Verify' is missing or empty"
  assert_exit 1 "$YAYH" plan check P-2
  sed -i.bak 's/^\*\*Tests:\*\* none$/**Tests:**/' "$YAY_REPO/$q"
  assert_contains "$("$YAYH" plan check P-2 2>&1)" "no '**Tests:** <tests or none>' line"
  "$YAYH" fm set "$YAY_REPO/$q" status shipped
  assert_contains "$("$YAYH" plan check P-2 2>&1)" "status 'shipped'"
}

test_carry_moves_untracked_into_worktree() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local b p wt; b="$("$YAYH" artifact new brainstorm "Carry me")"; p="$("$YAYH" artifact new plan "Carry me")"
  wt="$("$YAYH" git worktree feat/carry-me)"
  assert_eq "carried	$b
carried	$p" "$("$YAYH" artifact carry "$wt" "$b" "$p")"
  assert_file "$wt/$p"; assert_no_file "$YAY_REPO/$p"
  assert_eq "tracked	docs/roadmap.md" "$("$YAYH" artifact carry "$wt" docs/roadmap.md)"
  echo x >> "$YAY_REPO/docs/roadmap.md"
  assert_fails "$YAYH" artifact carry "$wt" docs/roadmap.md
}

test_id_next_sees_base_branch_and_conflicts_found() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  # A teammate's plan P-1 lands on dev while we are on an older branch.
  git -C "$YAY_REPO" switch -q -c feat/mine HEAD
  git -C "$YAY_REPO" switch -q dev
  "$YAYH" artifact new plan "Teammate plan" >/dev/null
  git -C "$YAY_REPO" add -A; git -C "$YAY_REPO" commit -qm "docs(plan): teammate" --no-verify
  git -C "$YAY_REPO" switch -q feat/mine
  assert_eq "P-2" "$("$YAYH" id next P)"                   # base already has P-1
  # Simulate an old collision: our branch hand-made P-1.
  mkdir -p "$YAY_REPO/docs/plans"; printf -- '---\nid: P-1\ntitle: mine\nstatus: draft\ncreated: 2026-11-10\n---\n' > "$YAY_REPO/docs/plans/mine.md"
  assert_contains "$("$YAYH" id conflicts)" "conflict	P-1	docs/plans/mine.md	docs/plans/teammate-plan.md"
  assert_exit 1 "$YAYH" id conflicts
  rm "$YAY_REPO/docs/plans/mine.md"
  assert_ok "$YAYH" id conflicts
}

test_run_fills_placeholders_and_passes_exit_code() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p))
c["commands"]["package"]="echo pkg {slug} {version} {edition}"; c["commands"]["lint"]="exit 4"
json.dump(c,open(p,"w"))
PY
  assert_eq "pkg fixture-plugin 1.3.0 free" "$("$YAYH" run package version=1.3.0 edition=free 2>/dev/null)"
  assert_exit 4 "$YAYH" run lint
  assert_fails "$YAYH" run package version=1.3.0            # {edition} left
  assert_fails "$YAYH" run nope
}

test_debug_markers_lists_only_code_markers() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  printf '<?php\nerror_log( 1 ); // yay:debug\n' > "$YAY_REPO/includes/A.php"
  printf 'console.log(1); /* yay:debug */\n' > "$YAY_REPO/a.js"
  printf 'Use `// yay:debug`.\n' > "$YAY_REPO/docs/note.md"
  local out; out="$("$YAYH" debug markers)"
  assert_contains "$out" "includes/A.php:2:"
  assert_contains "$out" "a.js:1:"
  case "$out" in *note.md*|*CLAUDE.md*|*yay-git.md*) _fail "markdown listed: $out";; *) _pass;; esac
}

test_site_wppath_derived_and_local_override() {
  local wp="$T_TMP/wp.$RANDOM"; mkdir -p "$wp/wp-content/plugins"
  "$FIX" bare "$wp/wp-content/plugins/fixture-plugin" >/dev/null
  export YAY_REPO="$wp/wp-content/plugins/fixture-plugin"
  mkdir -p "$YAY_REPO/.yay"; "$YAYH" harness detect 2>/dev/null > "$YAY_REPO/.yay/config.json"
  assert_fails grep -q wpPath "$YAY_REPO/.yay/config.json"          # never in shared config
  assert_eq "$wp" "$("$YAYH" config get site.wpPath)"
  assert_eq "$wp/wp-content/debug.log" "$("$YAYH" config get site.debugLog)"
  echo '{"site":{"wpPath":"/srv/wp"}}' > "$YAY_REPO/.yay/local.json"
  assert_eq "/srv/wp" "$("$YAYH" config get site.wpPath)"
  assert_eq "/srv/wp/wp-content/debug.log" "$("$YAYH" config get site.debugLog)"
  export YAY_REPO; YAY_REPO="$(_arepo)"
  assert_exit 1 "$YAYH" config get site.wpPath
}

test_run_uses_nvmrc_through_nvm() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local fake="$T_TMP/nvm.$RANDOM"; mkdir -p "$fake"
  printf 'nvm() { echo "NVM $*" > "%s/called"; }\n' "$fake" > "$fake/nvm.sh"
  echo "v99" > "$YAY_REPO/.nvmrc"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["commands"]["build"]="echo built"; json.dump(c,open(p,"w"))
PY
  local err; err="$(NVM_DIR="$fake" "$YAYH" run build 2>&1 >/dev/null)"
  assert_contains "$err" "(nvm use 99)"
  assert_eq "NVM use 99" "$(cat "$fake/called" 2>/dev/null)"
  rm "$YAY_REPO/.nvmrc"; rm -f "$fake/called"
  NVM_DIR="$fake" "$YAYH" run build >/dev/null 2>&1
  assert_no_file "$fake/called"
}

test_help_flag_never_creates_an_artifact() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  assert_contains "$("$YAYH" artifact new bug --help)" "yayh <command>"
  assert_exit 1 "$YAYH" artifact new bug -x
  assert_eq "" "$(cd "$YAY_REPO" && git status --porcelain -- docs/)"
}

test_plan_check_reuse_lines() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local q; q="$("$YAYH" artifact new plan "Reuse plan")"
  python3 -I - "$YAY_REPO/$q" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
tasks="""## Tasks
- [ ] T1 Show the fee — `includes/Checkout.php`
  - Reuse: Format::price() in includes/Support/Format.php
- [ ] T2 Add a setting — `includes/Settings.php`
- [ ] T3 New helper — `includes/Fee.php` (new)
  - Reuse: none, new Fee::total()
- [ ] T4 Another helper — `includes/Wrap.php` (new)
  - Reuse: none, new Wrap::cost() because Format only formats
- [ ] T5 Docs (no files)
  - Reuse: n/a
- [ ] T6 Forgot the paths
  - Reuse: n/a
"""
s=re.sub(r"## Tasks\n.*?\n\n", tasks+"\n", s, flags=re.S)
open(p,"w").write(s)
PY
  local out; out="$("$YAYH" plan check P-1 2>&1 || true)"
  assert_contains "$out" "warn: task T2 has no 'Reuse:' line"
  assert_contains "$out" "warn: task T3 adds new code ('Reuse: none') without saying why"
  assert_contains "$out" "warn: task T6 names no files"
  case "$out" in *"task T1 has no"*|*"task T4 "*|*"task T5 has no"*) _fail "false reuse warning: $out" ;; *) _pass ;; esac
}

test_id_next_counts_worktrees_and_parallel_new_never_collides() {
  export YAY_REPO; YAY_REPO="$(_arepo)"
  local p wt i
  p="$("$YAYH" artifact new plan "Carried away")"
  wt="$("$YAYH" git worktree feat/carried-away)"
  "$YAYH" artifact carry "$wt" "$p" >/dev/null
  assert_eq "P-2" "$("$YAYH" id next P)"
  for i in 1 2 3 4 5 6; do "$YAYH" artifact new plan "Parallel $i" >/dev/null & done
  wait
  assert_eq "P-2
P-3
P-4
P-5
P-6
P-7" "$(grep -h '^id:' "$YAY_REPO"/docs/plans/parallel-*.md | sed 's/^id: //' | sort -t- -k2 -n)"
}
