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
