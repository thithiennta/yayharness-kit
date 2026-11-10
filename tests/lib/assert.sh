# shellcheck shell=bash
# Minimal assertions. Each test file defines test_* functions; run.sh calls them.

T_FAILS=0
T_PASSES=0

_fail() { T_FAILS=$((T_FAILS + 1)); printf '    FAIL %s: %s\n' "${T_NAME:-?}" "$*"; }
_pass() { T_PASSES=$((T_PASSES + 1)); }

assert_eq() { # expected actual [msg]
  if [ "$1" = "$2" ]; then _pass; else _fail "${3:-} expected [$1] got [$2]"; fi
}
assert_contains() { # haystack needle [msg]
  case "$1" in *"$2"*) _pass ;; *) _fail "${3:-} [$2] not in [$1]" ;; esac
}
assert_ok() { # cmd...
  if "$@" >/dev/null 2>&1; then _pass; else _fail "expected success: $*"; fi
}
assert_fails() { # cmd...
  if "$@" >/dev/null 2>&1; then _fail "expected failure: $*"; else _pass; fi
}
assert_exit() { # code cmd...
  local want="$1"; shift
  local got=0; "$@" >/dev/null 2>&1 || got=$?
  assert_eq "$want" "$got" "exit code of: $*"
}
assert_file() { if [ -e "$1" ]; then _pass; else _fail "missing file $1"; fi; }
assert_no_file() { if [ -e "$1" ]; then _fail "file should not exist: $1"; else _pass; fi; }

# A throwaway git repo with an identity, under tests/.tmp.
mk_repo() {
  local d
  d="$(mktemp -d "${T_TMP:?}/repo.XXXXXX")"
  git -C "$d" init -q -b main
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name test
  git -C "$d" config commit.gpgsign false
  git -C "$d" config tag.gpgsign false
  printf '%s\n' "$d"
}
commit_all() { git -C "$1" add -A && git -C "$1" commit -q -m "${2:-chore: init}" --no-verify; }
