#!/usr/bin/env bash
# Run the kit's tests: ./tests/run.sh [file-filter] [--engines=jq,node,php,python3]
# Each tests/unit/*.sh file runs once per available JSON engine, because the
# config and manifest readers have one backend per engine.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export YAYH="$ROOT/plugins/yay/bin/yayh"
export KIT="$ROOT/plugins/yay"
FILTER=""
ENGINES=""
for a in "$@"; do
  case "$a" in
    --engines=*) ENGINES="${a#--engines=}" ;;
    *) FILTER="$a" ;;
  esac
done
if [ -z "$ENGINES" ]; then
  for e in jq node php python3; do command -v "$e" >/dev/null 2>&1 && ENGINES="$ENGINES${ENGINES:+,}$e"; done
fi

# Fixtures live outside the kit repo, in a root unique to this run, so a
# fixture git command that misfires can never reach the kit's own history,
# and parallel runs can't delete each other's fixtures.
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/yaykit-tests.XXXXXX")"
RUN_ROOT="$(cd "$RUN_ROOT" && pwd -P)"
export GIT_CEILING_DIRECTORIES="$(dirname "$RUN_ROOT")"
KIT_HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
trap 'rm -rf "$RUN_ROOT"' EXIT
total_fail=0; total_pass=0

for engine in $(printf '%s' "$ENGINES" | tr ',' ' '); do
  echo "== engine: $engine"
  for f in "$ROOT"/tests/unit/*.sh; do
    [ -n "$FILTER" ] && case "$f" in *"$FILTER"*) ;; *) continue;; esac
    # Engine-independent files run once, on the first engine only.
    if grep -q '^# engine-independent' "$f" && [ "$engine" != "${ENGINES%%,*}" ]; then continue; fi
    out="$(
      export YAY_JSON_ENGINE="$engine"
      T_TMP="$(mktemp -d "$RUN_ROOT/run.XXXXXX")"; export T_TMP
      . "$ROOT/tests/lib/assert.sh"
      . "$f"
      for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
        T_NAME="$(basename "$f" .sh):$t"
        ( unset YAY_REPO; cd "$T_TMP" && "$t" ) || true
      done
      rm -rf "$T_TMP"
    )"
    fails="$(printf '%s\n' "$out" | grep -c '^    FAIL' || true)"
    printf '%s\n' "$out" | grep '^    FAIL' || true
    printf '  %-28s %s\n' "$(basename "$f")" "$([ "$fails" = 0 ] && echo ok || echo "$fails failed")"
    total_fail=$((total_fail + fails))
  done
done

if [ "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)" != "$KIT_HEAD" ]; then
  echo "FATAL: the kit repo's HEAD moved during the tests (a fixture committed to it). Reset it." >&2
  exit 2
fi
if [ "$total_fail" -gt 0 ]; then echo "FAILED: $total_fail assertion(s)"; exit 1; fi
echo "all tests passed"
