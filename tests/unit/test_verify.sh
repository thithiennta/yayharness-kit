# verify: a plan's command checks run and pass or fail

_vplan() { # plan P-1 with a mix of command and manual checks
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  mkdir -p "$YAY_REPO/docs/plans"
  printf 'ok-file\n' > "$YAY_REPO/a.txt"
  cat > "$YAY_REPO/docs/plans/p.md" <<'MD'
---
id: P-1
title: Verify me
status: in-progress
---
## Tasks
- [x] T1 x — `a.txt`

## Verify
<!-- exact checks -->
- `cat a.txt` → ok-file
- `test -f a.txt` → exit 0 (the file exists)
- `test -f missing.txt` -> exit 1
- `grep -c ok a.txt` → "1"
- Open Settings → Gift and see the new field.
1. `true` → exit 0
MD
  git -C "$YAY_REPO" add -A; git -C "$YAY_REPO" commit -qm init
}

test_verify_lists_command_and_manual_checks() {
  _vplan
  local out; out="$("$YAYH" verify P-1)"
  assert_eq "1	cmd	cat a.txt	ok-file
2	cmd	test -f a.txt	exit 0
3	cmd	test -f missing.txt	exit 1
4	cmd	grep -c ok a.txt	1
5	manual
6	cmd	true	exit 0" "$(printf '%s\n' "$out" | cut -f1-4 | sed 's/	-	-$//')"
}

test_verify_run_passes_and_fails() {
  _vplan
  local out; out="$("$YAYH" verify P-1 --run)"; assert_eq 0 $?
  assert_eq "pass pass pass pass manual pass" "$(printf '%s\n' "$out" | cut -f2 | tr '\n' ' ' | sed 's/ $//')"
  printf 'changed\n' > "$YAY_REPO/a.txt"
  out="$("$YAYH" verify P-1 --run)"; assert_eq 1 $?
  assert_contains "$(printf '%s\n' "$out" | sed -n 1p)" "1	fail	cat a.txt	ok-file	exit 0; output lacks the expected text: changed"
  assert_exit 1 "$YAYH" verify
  assert_exit 1 "$YAYH" verify P-9
}

test_verify_reads_marked_items() {
  _vplan
  local before check_before; before="$("$YAYH" verify P-1)"; check_before="$("$YAYH" plan check P-1 2>&1)"
  sed -i.bak -e 's/^- `cat/- ✅ `cat/' -e 's/^- `test -f a/- ❌ `test -f a/' -e 's/^- `test -f m/- ⚠️ `test -f m/' \
    -e 's/^- `grep/- ⏭️ `grep/' -e 's/^- Open/- ⬜ Open/' -e 's/^1\. `true/1. ✅ `true/' "$YAY_REPO/docs/plans/p.md"
  rm -f "$YAY_REPO/docs/plans/p.md.bak"
  assert_contains "$(cat "$YAY_REPO/docs/plans/p.md")" "- ✅ \`cat a.txt\`"
  assert_eq "$before" "$("$YAYH" verify P-1)"
  assert_eq "$check_before" "$("$YAYH" plan check P-1 2>&1)"
}

test_verify_mark_writes_icons() {
  _vplan
  local f="$YAY_REPO/docs/plans/p.md" head
  sed -i.bak 's/^- Open/- ⬜ Open/' "$f"; rm -f "$f.bak"
  head="$(sed -n '1,/^## Verify/p' "$f")"
  assert_exit 1 "$YAYH" verify P-1 --mark
  "$YAYH" verify P-1 --run --mark >/dev/null; assert_eq 0 $?
  assert_contains "$(cat "$f")" "- ✅ \`cat a.txt\` → ok-file"
  assert_contains "$(cat "$f")" "1. ✅ \`true\` → exit 0"
  assert_contains "$(cat "$f")" "- ⬜ Open Settings"
  assert_contains "$(cat "$f")" "<!-- exact checks -->"
  assert_eq "$head" "$(sed -n '1,/^## Verify/p' "$f")"
  printf 'changed\n' > "$YAY_REPO/a.txt"
  "$YAYH" verify P-1 --run --mark >/dev/null; assert_eq 1 $?
  assert_contains "$(cat "$f")" "- ❌ \`cat a.txt\` → ok-file"
  assert_eq 0 "$(grep -c '✅ ❌\|❌ ✅' "$f")"
  assert_eq "1	cmd	cat a.txt	ok-file" "$("$YAYH" verify P-1 | sed -n 1p | cut -f1-4)"
}
