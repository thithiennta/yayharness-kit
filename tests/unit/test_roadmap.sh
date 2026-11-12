# engine-independent
# roadmap: parse/list/get/set/add/move, sprint calendar, check, status, peers

_rrepo() { # repo with a two-sprint roadmap
  local r; r="$(mk_repo)"
  mkdir -p "$r/docs"
  cat > "$r/docs/roadmap.md" <<'EOF'
---
horizon: 2026-12-07
sprint_length: 2w
updated: 2026-11-01
---
# Roadmap: Fixture

## Sprint 1 (2026-11-10 → 2026-11-23)

Goal: checkout speed before BFCM.

### R-1 Express checkout buttons
- status: in-progress
- size: M
- why: fewer steps to pay

### R-2 Faster cart fragments
- status: shipped:1.4.0
- size: S

## Sprint 2 (2026-11-24 → 2026-12-07)

### R-3 Coupon UX
- status: planned
- size: L
- why: support tickets

```markdown
### R-0 Example inside a fence
- status: nonsense
```

## Later

### R-4 Import from URL
- status: planned-in:P-2
- size: M
EOF
  printf '%s\n' "$r"
}

test_sprints_calendar_truncates_at_until() {
  assert_eq "1	2026-11-10	2026-11-23
2	2026-11-24	2026-12-07
3	2026-12-08	2026-12-21
4	2026-12-22	2026-12-31" "$("$YAYH" roadmap sprints start=2026-11-10 length=2w until=2026-12-31)"
}

test_sprints_count_crosses_year_and_md() {
  assert_eq "## Sprint 5 (2026-12-28 → 2027-01-06)
## Sprint 6 (2027-01-07 → 2027-01-16)" "$("$YAYH" roadmap sprints start=2026-12-28 length=10d count=2 first=5 --md)"
  assert_exit 1 "$YAYH" roadmap sprints start=2026-11-10 length=2x count=1
  assert_exit 1 "$YAYH" roadmap sprints start=2026-11-10 length=2w
}

test_list_sections_and_filters() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "R-1	in-progress	M	1	Express checkout buttons
R-2	shipped:1.4.0	S	1	Faster cart fragments
R-3	planned	L	2	Coupon UX
R-4	planned-in:P-2	M	later	Import from URL" "$("$YAYH" roadmap list)"
  assert_eq "R-2" "$("$YAYH" roadmap list --status=shipped | cut -f1)"
  assert_eq "R-4" "$("$YAYH" roadmap list --sprint=later | cut -f1)"
}

test_get_and_set() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "support tickets" "$("$YAYH" roadmap get R-3 why)"
  assert_exit 3 "$YAYH" roadmap get R-2 why
  "$YAYH" roadmap set R-3 status in-progress >/dev/null
  "$YAYH" roadmap set R-2 why "cart loads faster" >/dev/null
  assert_eq "in-progress" "$("$YAYH" roadmap get R-3 status)"
  assert_eq "cart loads faster" "$("$YAYH" roadmap get R-2 why)"
  # the new bullet lands inside R-2, before R-3's heading
  assert_contains "$(cat "$YAY_REPO/docs/roadmap.md")" "- size: S
- why: cart loads faster

## Sprint 2"
  assert_eq "$(date +%Y-%m-%d)" "$("$YAYH" fm get "$YAY_REPO/docs/roadmap.md" updated)"
  assert_exit 1 "$YAYH" roadmap set R-3 status maybe
  assert_exit 1 "$YAYH" roadmap set R-3 status shipped:soon
  assert_exit 1 "$YAYH" roadmap set R-42 status planned
}

test_add_takes_next_id_and_lands_in_section() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "R-5" "$("$YAYH" roadmap add "Gift messages" sprint=2 size=S "why=merchants asked")"
  assert_eq "R-6" "$("$YAYH" roadmap add "Dark mode")"
  assert_eq "R-1 R-2 R-3 R-5 R-4 R-6" "$("$YAYH" roadmap list | cut -f1 | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "2	planned	S" "$("$YAYH" roadmap list | awk -F '\t' '$1=="R-5"{print $4"\t"$2"\t"$3}')"
  assert_exit 1 "$YAYH" roadmap add "Bad" size=XL
}

test_move_between_sections() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  "$YAYH" roadmap move R-3 later >/dev/null
  "$YAYH" roadmap move R-4 1 >/dev/null
  assert_eq "R-1 1
R-2 1
R-4 1
R-3 later" "$("$YAYH" roadmap list | awk -F '\t' '{print $1, $4}')"
  assert_exit 1 "$YAYH" roadmap move R-1 9
  assert_ok "$YAYH" roadmap check --today=2026-11-12
  # the fenced example stays where it was
  assert_contains "$(cat "$YAY_REPO/docs/roadmap.md")" '### R-0 Example inside a fence'
}

test_move_creates_later_when_missing() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  "$YAYH" roadmap move R-4 1 >/dev/null
  sed -i.bak '/^## Later/d' "$YAY_REPO/docs/roadmap.md"
  "$YAYH" roadmap move R-3 later >/dev/null
  assert_eq "later" "$("$YAYH" roadmap list | awk -F '\t' '$1=="R-3"{print $4}')"
  assert_contains "$(cat "$YAY_REPO/docs/roadmap.md")" "## Later

### R-3 Coupon UX"
}

test_current_sprint() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "2	2026-11-24	2026-12-07" "$("$YAYH" roadmap current 2026-11-24)"
  assert_exit 3 "$YAYH" roadmap current 2027-01-01
}

test_check_ok_then_warnings_for_slipped_and_horizon() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  mkdir -p "$YAY_REPO/docs/plans"; printf -- '---\nid: P-2\n---\n' > "$YAY_REPO/docs/plans/import.md"
  assert_eq "" "$("$YAYH" roadmap check --today=2026-11-12)"
  local out; out="$("$YAYH" roadmap check --today=2026-12-10)"
  assert_contains "$out" "warn: R-1 slipped: Sprint 1 ended 2026-11-23 and it is still 'in-progress'"
  assert_contains "$out" "warn: R-3 slipped"
  assert_contains "$out" "warn: horizon 2026-12-07 has passed"
  case "$out" in *R-2*) _fail "shipped item reported as slipped" ;; *) _pass ;; esac
}

test_check_errors() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  cat >> "$YAY_REPO/docs/roadmap.md" <<'EOF'

## Sprint 3 (2026-12-01 → 2026-12-14)

### R-3 Duplicate
- status: someday
- size: XL

## Sprint 4

### R-7 No status
EOF
  local out; out="$("$YAYH" roadmap check --today=2026-11-12 || true)"
  assert_contains "$out" "error: R-3 appears twice"
  assert_contains "$out" "error: R-3 status 'someday'"
  assert_contains "$out" "error: R-3 size 'XL'"
  assert_contains "$out" "overlaps the previous sprint"
  assert_contains "$out" "sprint heading must be '## Sprint 4 (YYYY-MM-DD → YYYY-MM-DD)'"
  assert_contains "$out" "error: R-7 (line"
  assert_contains "$out" "warn: R-4 points at P-2"
  assert_exit 1 "$YAYH" roadmap check --today=2026-11-12
}

test_status_summary_with_bugs_and_plans() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  mkdir -p "$YAY_REPO/docs/bugs" "$YAY_REPO/docs/plans"
  printf -- '---\nid: B-1\ntitle: Coupon vanishes\nstatus: open\nseverity: high\n---\n' > "$YAY_REPO/docs/bugs/a.md"
  printf -- '---\nid: B-2\ntitle: Typo\nstatus: fixed\nseverity: critical\n---\n' > "$YAY_REPO/docs/bugs/b.md"
  printf -- '---\nid: B-3\ntitle: Crash\nstatus: root-caused\nseverity: critical\n---\n' > "$YAY_REPO/docs/bugs/c.md"
  printf -- '---\nid: P-2\ntitle: Import\nstatus: in-progress\n---\n' > "$YAY_REPO/docs/plans/import.md"
  local out; out="$("$YAYH" roadmap status --today=2026-11-30)"
  assert_contains "$out" "current	Sprint 2	2026-11-24 → 2026-12-07"
  assert_contains "$out" "Sprint 1	0	1	1	0"
  assert_contains "$out" "Sprint 2	1	0	0	0"
  assert_contains "$out" "later	1	0	0	0"
  assert_contains "$out" "slipped	R-1 slipped"
  assert_contains "$out" "bug	B-3	critical	root-caused	Crash
bug	B-1	high	open	Coupon vanishes"
  assert_contains "$out" "plan	P-2	in-progress	Import"
  case "$out" in *B-2*) _fail "fixed bug listed" ;; *) _pass ;; esac
}

test_peers_lists_sibling_plugins() {
  local parent="$T_TMP/plugins.$RANDOM"; mkdir -p "$parent/yayone/.yay" "$parent/other" "$parent/notaplugin"
  printf '{"plugin":{"name":"YayOne","slug":"yayone"}}\n' > "$parent/yayone/.yay/config.json"
  printf '<?php\n/**\n * Plugin Name: Other Thing\n */\n' > "$parent/other/other.php"
  printf 'hello\n' > "$parent/notaplugin/readme.txt"
  export YAY_REPO="$parent/yayone"
  local out; out="$("$YAYH" roadmap peers)"
  assert_contains "$out" "other	Other Thing	other	no	$parent/other"
  assert_contains "$out" "yayone	YayOne	yayone	yes	$parent/yayone"
  case "$out" in *notaplugin*) _fail "non-plugin folder listed" ;; *) _pass ;; esac
}

test_roadmap_scope_always_allowed() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  mkdir -p "$YAY_REPO/.yay"; printf '{"git":{"scopes":["core"]}}\n' > "$YAY_REPO/.yay/config.json"
  assert_ok "$YAYH" git commit-check "docs(roadmap): plan to 2026-12-31"
  assert_exit 1 "$YAYH" git commit-check "docs(admin): x"
}

test_links_suggest_status_from_brainstorms_and_plans() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  mkdir -p "$YAY_REPO/docs/plans" "$YAY_REPO/docs/brainstorms"
  printf -- '---\nid: BS-1\nstatus: decided\nfrom: R-3\n---\n' > "$YAY_REPO/docs/brainstorms/a.md"
  printf -- '---\nid: P-2\nstatus: ready\nfrom: BS-1\nroadmap: R-3\n---\n' > "$YAY_REPO/docs/plans/c.md"
  printf -- '---\nid: BS-2\nstatus: open\nfrom: R-4\n---\n' > "$YAY_REPO/docs/brainstorms/b.md"
  printf -- '---\nid: P-3\nstatus: done\nroadmap: R-2\n---\n' > "$YAY_REPO/docs/plans/d.md"
  assert_eq "R-2	shipped:1.4.0	shipped:1.4.0	P-3
R-3	planned	planned-in:P-2	P-2
R-4	planned-in:P-2	brainstorming:BS-2	BS-2" "$("$YAYH" roadmap links)"
}

_qrepo() { # roadmap with dependencies, a brainstorm and plans
  local r; r="$(mk_repo)"
  mkdir -p "$r/docs/plans" "$r/docs/brainstorms"
  cat > "$r/docs/roadmap.md" <<'EOT'
---
horizon: 2026-12-07
---
# Roadmap

## Sprint 1 (2026-11-10 → 2026-11-23)

### R-1 Express checkout
- status: planned
- size: M
- depends: R-3

### R-2 Cart speed
- status: shipped:1.4.0
- size: S

### R-3 Coupon UX
- status: planned
- size: L
- depends: R-2, yayreturns:R-9

### R-4 Import
- status: planned
- size: M
- depends: R-7

### R-5 Gift wrap
- status: planned
- size: S

## Later

### R-6 Wishlist
- status: planned-in:P-3
- size: M
EOT
  printf -- '---\nid: BS-1\ntitle: Coupons\nstatus: open\nfrom: R-3\n---\n' > "$r/docs/brainstorms/2026-11-01-coupons.md"
  printf -- '---\nid: P-1\ntitle: Gift wrap\nstatus: ready\nroadmap: R-5\nfrom: BS-9\n---\n' > "$r/docs/plans/gift-wrap.md"
  printf -- '---\nid: P-2\ntitle: Loose plan\nstatus: ready\nroadmap:\n---\n' > "$r/docs/plans/loose-plan.md"
  printf -- '---\nid: P-3\ntitle: Wishlist\nstatus: in-progress\nroadmap: R-6\n---\n' > "$r/docs/plans/wishlist.md"
  commit_all "$r"
  printf '%s\n' "$r"
}

test_queue_sprint_orders_by_depends_and_sets_stages() {
  export YAY_REPO; YAY_REPO="$(_qrepo)"
  assert_eq "R-2	done	-	-	-	Cart speed
R-3	decide	BS-1	-	yayreturns:R-9	Coupon UX
R-1	brainstorm	-	R-3	-	Express checkout
R-4	brainstorm	-	-	R-7	Import
R-5	implement	P-1	-	-	Gift wrap" "$("$YAYH" roadmap queue --sprint=1)"
}

test_queue_plans_ready_and_continue() {
  export YAY_REPO; YAY_REPO="$(_qrepo)"
  assert_eq "R-5	implement	P-1	-	-	Gift wrap
P-2	implement	P-2	-	-	Loose plan" "$("$YAYH" roadmap queue --ready)"
  assert_eq "R-6	continue	P-3	-	-	Wishlist" "$("$YAYH" roadmap queue P-3)"
  assert_exit 1 "$YAYH" roadmap queue P-99
  assert_exit 1 "$YAYH" roadmap queue
}

test_queue_sees_plans_carried_into_worktrees_and_cycles_fail() {
  export YAY_REPO; YAY_REPO="$(_qrepo)"
  git -C "$YAY_REPO" worktree add -q "$YAY_REPO/.claude/worktrees/gift" -b feat/gift-wrap
  git -C "$YAY_REPO" rm -q docs/plans/gift-wrap.md
  assert_eq "R-5	implement	P-1	-	-	Gift wrap" "$("$YAYH" roadmap queue R-5)"
  "$YAYH" roadmap set R-3 depends R-1 >/dev/null
  assert_exit 1 "$YAYH" roadmap queue R-1 R-3
}

test_queue_reviews_a_plan_an_interrupted_run_built() {
  export YAY_REPO; YAY_REPO="$(_qrepo)"
  local p="$YAY_REPO/docs/plans/gift-wrap.md"
  "$YAYH" fm set "$p" status done >/dev/null
  assert_eq "R-5	done	P-1	-	-	Gift wrap" "$("$YAYH" roadmap queue R-5)"
  "$YAYH" fm set "$p" reviewed pending >/dev/null
  assert_eq "R-5	review	P-1	-	-	Gift wrap" "$("$YAYH" roadmap queue R-5)"
  assert_eq "/yay:autopilot R-5" "$("$YAYH" next R-5)"
  "$YAYH" fm set "$p" reviewed yes >/dev/null
  assert_eq "R-5	done	P-1	-	-	Gift wrap" "$("$YAYH" roadmap queue R-5)"
}

test_target_add_list_set_and_queue() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  assert_eq "R-5" "$("$YAYH" roadmap add "Gift messages" sprint=2 size=S target=1.5.0 "why=merchants asked")"
  assert_eq "R-6" "$("$YAYH" roadmap add "Dark mode" target=1.6.0)"
  "$YAYH" roadmap set R-3 target 1.5.0 >/dev/null
  assert_eq "1.5.0" "$("$YAYH" roadmap get R-5 target)"
  assert_eq "R-3 R-5" "$("$YAYH" roadmap list --target=1.5.0 | cut -f1 | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "R-6" "$("$YAYH" roadmap list --target=1.6.0 --sprint=later | cut -f1)"
  assert_eq "" "$("$YAYH" roadmap list --target=9.9.9)"
  # queue builds what a version needs
  assert_eq "R-3 R-5" "$("$YAYH" roadmap queue --target=1.5.0 | cut -f1 | tr '\n' ' ' | sed 's/ $//')"
  # bad targets are refused; none clears
  assert_exit 1 "$YAYH" roadmap add "Bad" target=soon
  assert_exit 1 "$YAYH" roadmap set R-3 target v1.5
  assert_eq "R-3	target	none" "$("$YAYH" roadmap set R-3 target none)"
  assert_exit 3 "$YAYH" roadmap get R-3 target
  assert_not_contains "$(cat "$YAY_REPO/docs/roadmap.md")" "- target: 
"
  assert_ok "$YAYH" roadmap check --today=2026-11-12
}

test_target_status_counts_and_check_warns_on_released() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  mkdir -p "$YAY_REPO/.yay" "$YAY_REPO/docs/plans"
  printf -- '---\nid: P-2\n---\n' > "$YAY_REPO/docs/plans/import.md"
  printf '{ "schemaVersion": 1, "versionFiles": [ { "file": "p.php", "pattern": "Version: *(.+)" } ] }\n' > "$YAY_REPO/.yay/config.json"
  printf '<?php\n/*\n * Version: 1.5.0\n */\n' > "$YAY_REPO/p.php"
  "$YAYH" roadmap set R-1 target 1.10.0 >/dev/null
  "$YAYH" roadmap set R-2 target 1.5.0 >/dev/null
  "$YAYH" roadmap set R-3 target 1.5.0 >/dev/null
  local out; out="$("$YAYH" roadmap status --today=2026-11-12)"
  # versions sort numerically: 1.5.0 before 1.10.0
  assert_contains "$out" "target	open	in-progress	shipped	dropped
1.5.0	1	0	1	0
1.10.0	0	1	0	0"
  out="$("$YAYH" roadmap check --today=2026-11-12)"
  assert_contains "$out" "warn: R-3 targets 1.5.0, but 1.5.0 is already out and it is still 'planned'"
  assert_not_contains "$out" "R-2 targets"
  assert_not_contains "$out" "R-1 targets"
  printf '\n### R-9 Broken\n- status: planned\n- size: S\n- target: next\n' >> "$YAY_REPO/docs/roadmap.md"
  assert_contains "$("$YAYH" roadmap check --today=2026-11-12 || true)" "error: R-9 target 'next' must be a version"
}

# ---------- split layout: docs/roadmap/ ----------

_rsplit() { # the fixture roadmap, split into docs/roadmap/
  local r; r="$(_rrepo)"
  YAY_REPO="$r" "$YAYH" roadmap split >/dev/null
  printf '%s\n' "$r"
}

test_split_keeps_every_item_and_writes_one_file_per_section() {
  export YAY_REPO; YAY_REPO="$(_rrepo)"
  local before; before="$("$YAYH" roadmap list)"
  assert_eq "single" "$("$YAYH" roadmap layout)"
  assert_contains "$("$YAYH" roadmap split)" "removed	docs/roadmap.md"
  assert_eq "split" "$("$YAYH" roadmap layout)"
  assert_eq "docs/roadmap/README.md" "$("$YAYH" roadmap file)"
  assert_eq "$before" "$("$YAYH" roadmap list)"
  assert_exit 1 test -f "$YAY_REPO/docs/roadmap.md"
  local d="$YAY_REPO/docs/roadmap"
  assert_eq "later.md README.md sprint-1.md sprint-2.md" "$(ls "$d" | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "## Sprint 1 (2026-11-10 → 2026-11-23)" "$(sed -n 1p "$d/sprint-1.md")"
  assert_contains "$(cat "$d/sprint-2.md")" '### R-0 Example inside a fence'
  assert_eq "2026-12-07" "$("$YAYH" fm get "$d/README.md" horizon)"
  assert_contains "$(cat "$d/README.md")" "| [Sprint 1](sprint-1.md) | 2026-11-10 → 2026-11-23 | checkout speed before BFCM. | 2 (1 shipped) | 5.5 |"
  # ids: the sprint files still hold the headings, the index never claims one
  assert_eq "R-5" "$("$YAYH" id next R)"
  assert_eq "docs/roadmap/sprint-2.md" "$("$YAYH" artifact resolve R-3)"
  assert_eq "" "$("$YAYH" roadmap check --today=2026-11-12 | grep -v 'points at P-2' || true)"
  assert_exit 1 "$YAYH" roadmap split
}

test_split_writes_go_to_the_right_file_and_regenerate_versions() {
  export YAY_REPO; YAY_REPO="$(_rsplit)"
  local d="$YAY_REPO/docs/roadmap"
  "$YAYH" roadmap set R-3 target 1.5.0 >/dev/null
  assert_contains "$(cat "$d/sprint-2.md")" "- target: 1.5.0"
  assert_eq "R-5" "$("$YAYH" roadmap add "Gift | wrap" sprint=1 size=S target=1.5.0)"
  assert_contains "$(cat "$d/sprint-1.md")" "### R-5 Gift | wrap"
  assert_contains "$(cat "$d/v1.5.0.md")" "2 items: 2 open, 0 in progress, 0 shipped, 0 dropped."
  assert_contains "$(cat "$d/v1.5.0.md")" "| R-5 | Gift \| wrap | planned | S | [Sprint 1](sprint-1.md) |"
  assert_contains "$(cat "$d/v1.5.0.md")" "The last open item is in [Sprint 2](sprint-2.md), ends 2026-12-07"
  assert_contains "$(cat "$d/README.md")" "| [1.5.0](v1.5.0.md) | 2 items:"
  "$YAYH" roadmap move R-4 1 >/dev/null
  assert_contains "$(cat "$d/sprint-1.md")" "### R-4 Import from URL"
  assert_not_contains "$(cat "$d/later.md")" "R-4"
  # a version nobody targets any more loses its file; hand-written files stay
  printf 'notes\n' > "$d/notes.md"
  "$YAYH" roadmap set R-3 target none >/dev/null
  "$YAYH" roadmap set R-5 target 1.6.0 >/dev/null
  assert_exit 1 test -f "$d/v1.5.0.md"
  assert_ok test -f "$d/v1.6.0.md"
  assert_ok test -f "$d/notes.md"
  assert_eq "$(date +%Y-%m-%d)" "$("$YAYH" fm get "$d/README.md" updated)"
  assert_eq "" "$("$YAYH" roadmap check --today=2026-11-12 | grep -v 'points at P-2' || true)"
}

test_split_reads_hand_edits_and_render_refreshes_the_index() {
  export YAY_REPO; YAY_REPO="$(_rsplit)"
  local d="$YAY_REPO/docs/roadmap"
  printf '\n### R-9 Hand added\n- status: planned\n- size: S\n- target: 2.0.0\n' >> "$d/later.md"
  assert_eq "R-9	planned	S	later	Hand added" "$("$YAYH" roadmap list | tail -1)"
  assert_contains "$("$YAYH" roadmap check --today=2026-11-12)" "warn: docs/roadmap/ index or version lists are out of date"
  assert_exit 1 "$YAYH" roadmap render --check
  assert_contains "$("$YAYH" roadmap render)" "write	docs/roadmap/v2.0.0.md"
  assert_ok "$YAYH" roadmap render --check
  assert_eq "unchanged	docs/roadmap/" "$("$YAYH" roadmap render)"
  # errors name the sprint file and its line
  printf '## Sprint 3 (2026-12-01 → 2026-12-14)\n\n### R-10 Bad\n- status: nope\n- size: S\n' > "$d/sprint-3.md"
  local out; out="$("$YAYH" roadmap check --today=2026-11-12 || true)"
  assert_contains "$out" "error: docs/roadmap/sprint-3.md:1: Sprint 3 overlaps the previous sprint"
  assert_contains "$out" "error: R-10 status 'nope'"
  # a leftover single file is reported, not read
  printf -- '---\n---\n## Later\n\n### R-20 Ghost\n- status: planned\n- size: S\n' > "$YAY_REPO/docs/roadmap.md"
  assert_contains "$("$YAYH" roadmap check --today=2026-11-12 || true)" "warn: docs/roadmap.md is ignored while docs/roadmap/ exists"
  assert_not_contains "$("$YAYH" roadmap list)" "R-20"
}

test_split_status_and_queue_work() {
  export YAY_REPO; YAY_REPO="$(_rsplit)"
  assert_contains "$("$YAYH" roadmap status --today=2026-11-12)" "roadmap	docs/roadmap/README.md	horizon=2026-12-07"
  assert_eq "R-3" "$("$YAYH" roadmap queue --sprint=2 | cut -f1)"
  assert_contains "$("$YAYH" status --today=2026-11-12)" "R-1"
}
