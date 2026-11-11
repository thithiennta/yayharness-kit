# engine-independent
# backlog notes: artifact new backlog kind=decision|deferred, backlog open/settle, plan check warnings

_brepo() { # initialized fixture on dev, with plan P-1 for roadmap item R-3
  local d; d="$(fixture_repo bare merged)" || return 1
  YAY_REPO="$d" "$YAYH" artifact new plan "Express checkout" roadmap=R-3 >/dev/null
  printf '%s\n' "$d"
}

test_new_notes_have_kind_status_and_default() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local d f i
  d="$("$YAYH" artifact new backlog "Refund email wording" kind=decision from=P-1 default="reuse the order email copy")"
  f="$("$YAYH" artifact new backlog "Apple Pay button" kind=deferred from=P-1 affects="R-3,P-9")"
  i="$("$YAYH" artifact new backlog "Import layouts")"
  assert_eq "decision" "$("$YAYH" fm get "$YAY_REPO/$d" kind)"
  assert_eq "open" "$("$YAYH" fm get "$YAY_REPO/$d" status)"
  assert_eq "reuse the order email copy" "$("$YAYH" fm get "$YAY_REPO/$d" default)"
  assert_eq "[R-3, P-9]" "$("$YAYH" fm get "$YAY_REPO/$f" affects)"
  assert_eq "idea" "$("$YAYH" fm get "$YAY_REPO/$i" kind)"
  assert_eq "idea" "$("$YAYH" fm get "$YAY_REPO/$i" status)"
  assert_fails grep -q '{{' "$YAY_REPO/$d" "$YAY_REPO/$f" "$YAY_REPO/$i"
}

test_new_rejects_bad_notes() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  assert_fails "$YAYH" artifact new backlog "No default" kind=decision
  assert_fails "$YAYH" artifact new backlog "Bad kind" kind=blocker
  assert_fails "$YAYH" artifact new backlog "Hash" kind=decision default="a #b"
  assert_fails "$YAYH" artifact new plan "Not backlog" kind=decision default=x
}

test_open_matches_the_plan_its_roadmap_item_and_kind() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  "$YAYH" artifact new backlog "Refund email wording" kind=decision from=P-1 default="order copy" >/dev/null   # BL-1
  "$YAYH" artifact new backlog "Apple Pay button" kind=deferred from=P-7 affects=R-3 >/dev/null             # BL-2
  "$YAYH" artifact new backlog "Other item" kind=deferred from=P-7 affects=R-8 >/dev/null                   # BL-3
  "$YAYH" artifact new backlog "Just an idea" >/dev/null                                                    # BL-4
  local out
  out="$("$YAYH" backlog open --for=P-1)"
  assert_eq "BL-1 BL-2" "$(printf '%s\n' "$out" | cut -f1 | paste -sd' ' -)"
  assert_eq "BL-1	decision	P-1	-	order copy	Refund email wording	docs/backlog/refund-email-wording.md" "$(printf '%s\n' "$out" | sed -n 1p)"
  assert_eq "BL-1 BL-2" "$("$YAYH" backlog open --for=R-3 | cut -f1 | paste -sd' ' -)"
  assert_eq "BL-2 BL-3" "$("$YAYH" backlog open --kind=deferred | cut -f1 | paste -sd' ' -)"
  assert_eq "BL-1 BL-2 BL-3" "$("$YAYH" backlog open | cut -f1 | paste -sd' ' -)"
}

test_settle_closes_notes() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  "$YAYH" artifact new backlog "Refund email wording" kind=decision from=P-1 default="order copy" >/dev/null
  "$YAYH" artifact new backlog "Apple Pay button" kind=deferred from=P-1 >/dev/null
  "$YAYH" artifact new backlog "Gift wrap" kind=deferred from=P-1 >/dev/null
  "$YAYH" artifact new backlog "Tests in worktrees" kind=deferred >/dev/null
  assert_fails "$YAYH" backlog settle BL-2 decided "x"
  assert_fails "$YAYH" backlog settle BL-1 done "abc1234"
  assert_fails "$YAYH" backlog settle BL-2 planned R-3
  assert_ok "$YAYH" backlog settle BL-1 decided "custom refund copy"
  assert_ok "$YAYH" backlog settle BL-2 planned P-1
  assert_ok "$YAYH" backlog settle BL-3 dropped "not worth it"
  assert_ok "$YAYH" backlog settle BL-4 done "fix(tests): run from a worktree (b7fc2df)"
  assert_eq "done" "$("$YAYH" fm get "$YAY_REPO/docs/backlog/tests-in-worktrees.md" status)"
  local f="$YAY_REPO/docs/backlog/refund-email-wording.md"
  assert_eq "decided" "$("$YAYH" fm get "$f" status)"
  assert_eq "custom refund copy" "$("$YAYH" fm get "$f" decision)"
  assert_eq "$(date +%Y-%m-%d)" "$("$YAYH" fm get "$f" settled)"
  assert_eq "planned:P-1" "$("$YAYH" fm get "$YAY_REPO/docs/backlog/apple-pay-button.md" status)"
  assert_eq "" "$("$YAYH" backlog open)"
}

test_open_sees_notes_in_other_worktrees() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local wt="$T_TMP/wt.$RANDOM"
  git -C "$YAY_REPO" worktree add -q -b feat/express "$wt" dev
  YAY_REPO="$wt" "$YAYH" artifact new backlog "Found while building" kind=deferred from=P-1 >/dev/null
  assert_eq "BL-1" "$("$YAYH" backlog open --for=P-1 | cut -f1)"
  assert_fails "$YAYH" backlog settle BL-1 dropped "x"   # lives on the other branch
}

test_plan_check_warns_about_open_notes() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  "$YAYH" artifact new backlog "Refund email wording" kind=decision from=P-1 default="order copy" >/dev/null
  "$YAYH" artifact new backlog "Apple Pay button" kind=deferred affects=R-3 >/dev/null
  local out; out="$("$YAYH" plan check P-1 2>&1 || true)"
  assert_contains "$out" 'warn: open decision BL-1 (Refund email wording) affects this plan; it follows the default "order copy"'
  assert_contains "$out" "warn: deferred work BL-2 (Apple Pay button) affects this plan"
  "$YAYH" backlog settle BL-1 decided "custom copy" >/dev/null
  out="$("$YAYH" plan check P-1 2>&1 || true)"
  case "$out" in *BL-1*) _fail "settled note still warned: $out" ;; *) _pass ;; esac
  # a plan that answers a note with a Settles: line isn't warned about it either
  printf '\n## Risks\n- Settles: BL-2 planned P-1\n' >> "$YAY_REPO/$("$YAYH" artifact resolve P-1)"
  out="$("$YAYH" plan check P-1 2>&1 || true)"
  case "$out" in *BL-2*) _fail "note answered by a Settles: line still warned: $out" ;; *) _pass ;; esac
}
