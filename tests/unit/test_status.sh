# engine-independent
# status / next: work in flight across roadmap, plans, brainstorms, bugs and worktrees

_srepo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/docs/plans" "$r/docs/brainstorms" "$r/docs/bugs"
  cat > "$r/docs/roadmap.md" <<'EOT'
---
horizon: 2026-12-07
sprint_length: 2w
---
# Roadmap

## Sprint 1 (2026-10-27 → 2026-11-09)

### R-1 Old item
- status: planned
- size: S

## Sprint 2 (2026-11-10 → 2026-11-23)

### R-2 Coupons
- status: planned
- size: M

### R-3 Gift wrap
- status: brainstorming:BS-1
- size: S

### R-4 Coupon report
- status: planned
- size: S
- depends: R-2

### R-8 Shipped one
- status: shipped:1.0.0
- size: S

## Later

### R-5 Wishlist
- status: in-progress
- size: M

### R-6 Someday
- status: planned
- size: L
EOT
  printf -- '---\nid: BS-1\ntitle: Gift wrap\nstatus: decided\nfrom: R-3\n---\n' > "$r/docs/brainstorms/gift-wrap.md"
  printf -- '---\nid: BS-2\ntitle: Loose idea\nstatus: open\nfrom:\n---\n' > "$r/docs/brainstorms/loose.md"
  printf -- '---\nid: P-2\ntitle: Wishlist\nstatus: in-progress\nroadmap: R-5\nbranch: feat/wishlist\n---\n## Tasks\n- [x] T1 a\n- [ ] T2 b\n- [ ] T3 c\n' > "$r/docs/plans/a-wishlist.md"
  printf -- '---\nid: P-3\ntitle: Loose plan\nstatus: ready\nroadmap:\n---\n' > "$r/docs/plans/b-loose.md"
  printf -- '---\nid: P-4\ntitle: Totals fix\nstatus: draft\nfrom: B-3\n---\n' > "$r/docs/plans/c-totals.md"
  printf -- '---\nid: B-1\ntitle: Crash\nstatus: open\nseverity: high\n---\n' > "$r/docs/bugs/b1.md"
  printf -- '---\nid: B-2\ntitle: Typo\nstatus: root-caused\nseverity: low\n---\n' > "$r/docs/bugs/b2.md"
  printf -- '---\nid: B-3\ntitle: Totals\nstatus: root-caused\nseverity: medium\n---\n' > "$r/docs/bugs/b3.md"
  printf -- '---\nid: B-4\ntitle: Done\nstatus: fixed\nseverity: critical\n---\n' > "$r/docs/bugs/b4.md"
  commit_all "$r"
  printf '%s\n' "$r"
}

test_status_orders_work_by_urgency() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  assert_eq "active	R-5	continue	/yay:implement P-2 --continue	Wishlist · 1/3 tasks
slipped	R-1	brainstorm	/yay:brainstorm --from=R-1	Old item
bug	B-1	debug	/yay:debug B-1	Crash (high)
sprint	R-2	brainstorm	/yay:brainstorm --from=R-2	Coupons
sprint	R-3	plan	/yay:plan --from=BS-1	Gift wrap
sprint	R-4	brainstorm	/yay:brainstorm --from=R-4	Coupon report (after R-2)
bug	B-2	fix	/yay:fix B-2	Typo (low)
plan	P-3	implement	/yay:implement P-3	Loose plan
plan	P-4	implement	/yay:implement P-4	Totals fix
brainstorm	BS-2	decide	/yay:plan --from=BS-2	Loose idea" "$("$YAYH" status --today=2026-11-12)"
}

test_status_puts_this_branch_first_and_sees_worktrees() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  git -C "$YAY_REPO" switch -q -c feat/wishlist
  local out; out="$("$YAYH" status --today=2026-11-12)"
  assert_eq "here	P-2	in-progress	/yay:implement P-2 --continue	Wishlist · 1/3 tasks" "$(printf '%s\n' "$out" | sed -n 1p)"
  case "$out" in *"active	R-5"*) _fail "R-5 listed twice" ;; *) _pass ;; esac
  assert_eq "/yay:implement P-2 --continue" "$("$YAYH" next --today=2026-11-12)"
  # a plan carried into another worktree is still seen, at its most advanced copy
  git -C "$YAY_REPO" switch -q main
  git -C "$YAY_REPO" worktree add -q "$YAY_REPO/.claude/worktrees/loose" -b feat/loose
  "$YAYH" fm set "$YAY_REPO/.claude/worktrees/loose/docs/plans/b-loose.md" status in-progress >/dev/null
  assert_contains "$("$YAYH" status --today=2026-11-12)" "plan	P-3	continue	/yay:implement P-3 --continue"
}

test_status_finished_branch_suggests_the_pr() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  git -C "$YAY_REPO" switch -q -c feat/wishlist
  "$YAYH" fm set "$YAY_REPO/docs/plans/a-wishlist.md" status done >/dev/null
  assert_contains "$("$YAYH" status --today=2026-11-12 | sed -n 1p)" "here	P-2	finished	git push -u origin feat/wishlist && gh pr create"
  "$YAYH" fm set "$YAY_REPO/docs/plans/a-wishlist.md" pr 12 >/dev/null
  assert_contains "$("$YAYH" status --today=2026-11-12 | sed -n 1p)" "here	P-2	in-review	gh pr view 12"
}

test_next_follows_each_chain() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  local t=--today=2026-11-12
  assert_eq "/yay:plan --from=BS-1" "$("$YAYH" next R-3 $t)"
  assert_eq "/yay:plan --from=BS-1" "$("$YAYH" next BS-1 $t)"
  assert_eq "/yay:brainstorm --from=R-6" "$("$YAYH" next R-6 $t)"
  assert_eq "/yay:implement P-4" "$("$YAYH" next B-3 $t)"
  assert_eq "/yay:fix B-2" "$("$YAYH" next B-2 $t)"
  assert_eq "/yay:debug B-1" "$("$YAYH" next B-1 $t)"
  assert_eq "/yay:plan --from=UX-1" "$("$YAYH" next UX-1 $t)"
  # a finished chain falls through to the most urgent other work
  "$YAYH" fm set "$YAY_REPO/docs/plans/b-loose.md" status done >/dev/null
  assert_eq "/yay:implement P-2 --continue" "$("$YAYH" next P-3 $t)"
  assert_eq "/yay:implement P-2 --continue" "$("$YAYH" next $t)"
  assert_exit 1 "$YAYH" next X-1
  assert_exit 1 "$YAYH" next P-99
}

test_status_before_the_first_sprint_shows_the_next_one() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  local out; out="$("$YAYH" status --today=2026-10-20)"
  # Sprint 1 starts 2026-10-27: its item is the current sprint's, not slipped
  assert_contains "$out" "sprint	R-1	brainstorm	/yay:brainstorm --from=R-1	Old item"
  case "$out" in *"sprint	R-2"*) _fail "Sprint 2 shown before Sprint 1 started" ;; *) _pass ;; esac
}

test_status_without_roadmap_and_nothing_to_do() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  git -C "$YAY_REPO" commit -q --allow-empty -m init
  assert_eq "" "$("$YAYH" status)"
  assert_exit 3 "$YAYH" next
  mkdir -p "$YAY_REPO/docs/bugs"
  printf -- '---\nid: B-1\ntitle: Crash\nstatus: open\n---\n' > "$YAY_REPO/docs/bugs/b1.md"
  assert_eq "bug	B-1	debug	/yay:debug B-1	Crash" "$("$YAYH" status)"
}
