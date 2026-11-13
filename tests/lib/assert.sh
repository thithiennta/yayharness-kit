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
assert_not_contains() { # haystack needle [msg]
  case "$1" in *"$2"*) _fail "${3:-} [$2] should not be in [$1]" ;; *) _pass ;; esac
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

# A throwaway git repo with an identity, under this run's temp root (outside the kit repo).
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

# fixture_repo <kind> [state] -> path of a fresh copy of a fixture repo (tests/fixtures/build.sh <kind>).
# Each kind+state is built once per run and JSON engine, then copied (a copy is ~30x cheaper).
#   raw         as build.sh leaves it, on dev
#   configured  + .yay/config.json from harness detect, committed on dev
#   harnessed   + harness wipe, detect and sync, committed on chore/yay-harness
#   merged      harnessed, with dev fast-forwarded to it; on dev
fixture_repo() {
  local kind="$1" state="${2:-raw}" root c d
  root="${YAY_FIXTURE_CACHE:-$T_TMP/.fixtures}/${YAY_JSON_ENGINE:-default}"
  c="$root/$kind.$state"
  mkdir -p "$root"
  if [ ! -d "$c" ]; then
    # One builder per kind+state across parallel test files; the others wait for it.
    until mkdir "$c.lock" 2>/dev/null; do sleep 0.1; done
    [ -d "$c" ] || { _fixture_build "$kind" "$state" "$c.tmp" && mv "$c.tmp" "$c"; }
    rm -rf "$c.tmp"; rmdir "$c.lock"
  fi
  [ -d "$c" ] || { echo "fixture_repo: could not build $kind $state" >&2; return 1; }
  d="$(mktemp -d "${T_TMP:?}/fx.XXXXXX")/repo"
  cp -R "$c" "$d"
  printf '%s\n' "$d"
}

_fixture_build() { # kind state dest
  local fix="${KIT%/plugins/yay}/tests/fixtures/build.sh"
  "$fix" "$1" "$3" >/dev/null || return 1
  case "$2" in
    raw) ;;
    configured)
      mkdir -p "$3/.yay"; YAY_REPO="$3" "$YAYH" harness detect 2>/dev/null > "$3/.yay/config.json"
      commit_all "$3" "chore(harness): config" ;;
    harnessed|merged)
      git -C "$3" switch -q -c chore/yay-harness
      YAY_REPO="$3" "$YAYH" harness wipe --yes >/dev/null
      mkdir -p "$3/.yay"; YAY_REPO="$3" "$YAYH" harness detect 2>/dev/null > "$3/.yay/config.json"
      YAY_REPO="$3" "$YAYH" harness sync >/dev/null
      commit_all "$3" "chore(harness): install"
      [ "$2" = harnessed ] || { git -C "$3" switch -q dev && git -C "$3" merge -q --ff-only chore/yay-harness; } ;;
    *) echo "fixture_repo: unknown state $2" >&2; return 1 ;;
  esac
}

# A fake docker that's installed but not running, first on PATH, and a fake e2e
# setup (wp-env and Playwright "installed"), so the UI site gets past its first check.
_ui_no_docker() { # repo -> PATH to use
  local bin="$T_TMP/nodocker.$RANDOM"; mkdir -p "$bin"
  printf '#!/bin/sh\nexit 1\n' > "$bin/docker"; chmod +x "$bin/docker"
  mkdir -p "$1/tests/e2e/node_modules/.bin"; echo '{}' > "$1/tests/e2e/.wp-env.json"
  printf '#!/bin/sh\nexit 0\n' > "$1/tests/e2e/node_modules/.bin/wp-env"
  cp "$1/tests/e2e/node_modules/.bin/wp-env" "$1/tests/e2e/node_modules/.bin/playwright"
  chmod +x "$1/tests/e2e/node_modules/.bin/"*
  printf '%s:%s\n' "$bin" "$PATH"
}
