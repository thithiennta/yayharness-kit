# R-20/R-21: merged work counts as done for its sprint; closing a sprint

_sprepo() { # git repo on main: Sprint 1 ended, Sprint 2 far ahead
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay" "$r/docs/plans"
  printf '{"git":{"baseBranch":"main"}}\n' > "$r/.yay/config.json"
  cat > "$r/docs/roadmap.md" <<'MD'
---
sprint_length: 2w
---
# Roadmap: Fixture

## Sprint 1 (2020-01-01 → 2020-01-14)

Goal: the first things.

### R-1 Merged thing
- status: in-progress
- size: S
- started: 2020-01-02

### R-2 Unfinished thing
- status: in-progress
- size: M

### R-3 Dropped thing
- status: dropped
- size: L

## Sprint 2 (2099-01-01 → 2099-01-14)

### R-4 Future thing
- status: todo
- size: M
MD
  printf -- '---\nid: P-1\ntitle: Merged\nstatus: done\nroadmap: R-1\n---\n' > "$r/docs/plans/merged.md"
  printf -- '---\nid: P-2\ntitle: Unfinished\nstatus: in-progress\nroadmap: R-2\n---\n' > "$r/docs/plans/unfinished.md"
  commit_all "$r" "chore: init"
  printf '%s\n' "$r"
}

test_done_is_not_slipped_and_counts_as_finished() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  "$YAYH" roadmap set R-1 status done >/dev/null
  assert_eq "$(date +%Y-%m-%d)" "$("$YAYH" roadmap get R-1 merged)"
  local out; out="$("$YAYH" roadmap check --today=2026-11-12 || true)"
  assert_not_contains "$out" "R-1 slipped"
  assert_contains "$out" "R-2 slipped"
  assert_contains "$("$YAYH" roadmap status --today=2026-11-12)" "Sprint 1	0	1	0	1	1"
  case "$("$YAYH" status 2>/dev/null)" in *"R-1"*) _fail "done item still in flight" ;; *) _pass ;; esac
}

test_sync_marks_items_done_once_their_plans_are_done_on_base() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  local day; day="$(git -C "$YAY_REPO" log -1 --format=%cs)"
  assert_contains "$("$YAYH" roadmap links)" "R-1	in-progress	done	P-1"
  assert_contains "$("$YAYH" roadmap links)" "R-2	in-progress	in-progress	P-2"
  assert_eq "R-1	in-progress	done	$day" "$("$YAYH" roadmap sync)"
  assert_eq "done" "$("$YAYH" roadmap get R-1 status)"
  assert_eq "$day" "$("$YAYH" roadmap get R-1 merged)"
  assert_eq "" "$("$YAYH" roadmap sync)"
  # done only on a branch, not on main yet: still in progress
  git -C "$YAY_REPO" switch -q -c feat/x
  python3 -I - "$YAY_REPO/docs/plans/unfinished.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read().replace("status: in-progress","status: done"); open(p,"w").write(s)
PY
  commit_all "$YAY_REPO" "docs(plan): complete P-2"
  assert_contains "$("$YAYH" roadmap links)" "R-2	in-progress	in-progress	P-2"
}

test_pace_measures_to_merged_over_built() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  "$YAYH" roadmap set R-1 built 2020-01-03 >/dev/null
  "$YAYH" roadmap set R-1 merged 2020-01-08 >/dev/null
  assert_contains "$("$YAYH" roadmap pace)" "item	R-1	S	1.5	5	2020-01-02	2020-01-08"
}

test_close_reports_writes_closed_line_and_velocity() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  "$YAYH" roadmap sync >/dev/null
  mkdir -p "$YAY_REPO/.yay/runs"
  printf '# Lessons\n\n- 2020-01-05 [hook] (P-1) commit hook blocked a scope\n- 2021-03-01 [env] (P-9) later lesson\n' > "$YAY_REPO/.yay/runs/lessons.md"
  assert_contains "$("$YAYH" roadmap check --today=2026-11-12 || true)" "Sprint 1 ended 2020-01-14 and isn't closed"
  local dry; dry="$("$YAYH" roadmap close 1 --dry-run --today=2020-01-15)"
  assert_contains "$dry" "item	R-1	done	S	done"
  assert_contains "$dry" "item	R-2	in-progress	M	open"
  assert_contains "$dry" "item	R-3	dropped	L	dropped"
  assert_contains "$dry" "total	5.5	1.5"
  assert_contains "$dry" "velocity	1.5	1.5	1"
  assert_contains "$dry" "lesson	2020-01-05	hook	P-1	commit hook blocked a scope"
  assert_not_contains "$dry" "later lesson"
  assert_not_contains "$(cat "$YAY_REPO/docs/roadmap.md")" "Closed:"
  "$YAYH" roadmap close 1 --today=2020-01-15 >/dev/null
  local rm; rm="$(cat "$YAY_REPO/docs/roadmap.md")"
  assert_contains "$rm" "Goal: the first things.

Closed: 2020-01-15 · 1.5/5.5 dev-days"
  assert_eq "[1.5]" "$(sed -n 's/^velocity: //p' "$YAY_REPO/docs/roadmap.md")"
  assert_eq "velocity	1.5	1.5	1" "$("$YAYH" roadmap velocity)"
  assert_exit 1 "$YAYH" roadmap close 1
  assert_not_contains "$("$YAYH" roadmap check --today=2026-11-12 || true)" "isn't closed"
  "$YAYH" roadmap check --today=2026-11-12 | grep -q '^error' && _fail "check errors after close" || _pass
  assert_contains "$("$YAYH" roadmap status --today=2026-11-12)" "velocity	1 closed sprints	last 1.5 dev-days done, average 1.5"
}

test_velocity_averages_the_last_three() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  python3 -I - "$YAY_REPO/docs/roadmap.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read().replace("sprint_length: 2w","sprint_length: 2w\nvelocity: [2, 8, 6, 7]",1); open(p,"w").write(s)
PY
  assert_eq "velocity	7	7	4" "$("$YAYH" roadmap velocity)"
}

test_split_index_shows_done() {
  export YAY_REPO; YAY_REPO="$(_sprepo)"
  "$YAYH" roadmap split >/dev/null
  "$YAYH" roadmap set R-1 status done >/dev/null
  assert_contains "$(cat "$YAY_REPO/docs/roadmap/README.md")" "| 3 (1 done, 0 shipped) |"
}
