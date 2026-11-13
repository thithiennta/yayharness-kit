#!/usr/bin/env bash
# Run the kit's tests:
#   ./tests/run.sh [filter...] [--engines=jq,node,php,python3] [--all-engines] [-j N] [--changed[=<ref>]] [--quick]
# The JSON helpers have one backend per engine. Files marked `# per-engine`
# (the JSON helpers, the config and manifest readers) run on every available
# engine; every other file runs once, on the first engine. Every test function
# is its own job, run in parallel, slowest first.
#   --all-engines    run every file on every engine (the old matrix; slow, rarely needed)
#   filter...        only files whose path contains one of these
#   -j N, --jobs=N   parallel jobs (default: CPU count)
#   --changed[=ref]  only the files that cover what changed vs ref (default: the working tree vs HEAD)
#   --quick          --changed on the first engine only: the edit loop. Run the full suite before committing.
#   --tested         don't run anything: exit 0 when a full green run (no filter, no --changed) already
#                    tested the kit code as it is now, 1 when not. Green full runs are stamped in tests/.passed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
export YAYH="$ROOT/plugins/yay/bin/yayh"
export KIT="$ROOT/plugins/yay"
FILTERS=""; ENGINES=""; JOBS=""; CHANGED=""; CHANGED_REF=""; QUICK=""; TESTED=""; ALL_ENGINES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --engines=*) ENGINES="${1#--engines=}" ;;
    -j) shift; JOBS="${1:-}" ;;
    -j*) JOBS="${1#-j}" ;;
    --jobs=*) JOBS="${1#--jobs=}" ;;
    --changed) CHANGED=1 ;;
    --changed=*) CHANGED=1; CHANGED_REF="${1#--changed=}" ;;
    --quick) CHANGED=1; QUICK=1 ;;
    --tested) TESTED=1 ;;
    --all-engines) ALL_ENGINES=1 ;;
    -h|--help) sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
    *) FILTERS="$FILTERS $1" ;;
  esac
  shift
done
if [ -z "$ENGINES" ]; then
  for e in jq node php python3; do command -v "$e" >/dev/null 2>&1 && ENGINES="$ENGINES${ENGINES:+,}$e"; done
fi
[ -z "$QUICK" ] || ENGINES="${ENGINES%%,*}"
[ -n "$JOBS" ] || JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
case "$JOBS" in ''|*[!0-9]*|0) echo "-j needs a positive number" >&2; exit 2 ;; esac

# --changed: map changed paths to the test files that cover them.
_cover() { # path -> test file basenames, or ALL
  case "$1" in
    tests/unit/test_*.sh) basename "$1" ;;
    tests/lib/*|tests/run.sh|tests/fixtures/*|plugins/yay/bin/yayh) echo ALL ;;
    plugins/yay/lib/common.sh|plugins/yay/lib/config.sh|plugins/yay/lib/frontmatter.sh|plugins/yay/lib/git.sh|plugins/yay/lib/manifest.sh|plugins/yay/lib/harness.sh) echo ALL ;;
    plugins/yay/lib/artifact.sh) printf '%s\n' test_artifact.sh test_backlog.sh test_design.sh test_roadmap.sh test_model.sh ;;
    plugins/yay/lib/model.sh) printf '%s\n' test_model.sh test_artifact.sh ;;
    plugins/yay/lib/backlog.sh) printf '%s\n' test_backlog.sh test_artifact.sh ;;
    plugins/yay/lib/bundle.sh) printf '%s\n' test_release.sh test_wporg.sh ;;
    plugins/yay/lib/release.sh) printf '%s\n' test_release.sh test_json.sh ;;
    plugins/yay/lib/*.sh) echo "test_$(basename "$1")" ;;
    plugins/yay/hooks/*) echo test_hooks.sh ;;
    plugins/yay/skills/wporg/scripts/*) echo test_wporg.sh ;;
    plugins/yay/templates/artifacts/*) printf '%s\n' test_artifact.sh test_backlog.sh test_design.sh ;;
    plugins/yay/templates/tests/*) echo test_tests.sh ;;
    plugins/yay/templates/e2e/*) echo test_e2e.sh ;;
    plugins/yay/templates/*) echo test_harness.sh ;;
  esac
}

# The kit code the suite covers, as one hash of the working tree's files: what a
# green full run proves. Skills, docs, the changelog and the version files aren't in it.
PASSED="$ROOT/tests/.passed"   # one line per green full run: <code hash> <date> <engines>
_code_hash() {
  local list; list="$(mktemp)"
  git -C "$ROOT" ls-files -co --exclude-standard | while IFS= read -r p; do
    [ -f "$ROOT/$p" ] && [ -n "$(_cover "$p")" ] && printf '%s\n' "$p"
  done | sort > "$list"
  (cd "$ROOT" && paste -d' ' "$list" <(git hash-object --stdin-paths < "$list")) | git hash-object --stdin
  rm -f "$list"
}
FULL=""; [ -n "$FILTERS$CHANGED" ] || FULL=1
CODE_HASH="$(_code_hash)"
if [ -n "$TESTED" ]; then
  hit="$(awk -v h="$CODE_HASH" '$1 == h' "$PASSED" 2>/dev/null | tail -1)"
  if [ -n "$hit" ]; then echo "tested $hit"; exit 0; fi
  echo "untested $CODE_HASH"; exit 1
fi
if [ -n "$CHANGED" ]; then
  paths="$( { git -C "$ROOT" status --porcelain --untracked-files=all | cut -c4- | sed 's/.* -> //'
              [ -z "$CHANGED_REF" ] || git -C "$ROOT" diff --name-only "$CHANGED_REF"...HEAD; } | sort -u)"
  covered="$(printf '%s\n' "$paths" | while IFS= read -r p; do [ -n "$p" ] && _cover "$p"; done | sort -u)"
  if [ -z "$covered" ]; then echo "no kit code changed${CHANGED_REF:+ since $CHANGED_REF}; nothing to test"; exit 0; fi
  if ! printf '%s\n' "$covered" | grep -qx ALL; then
    for c in $covered; do [ -f "$ROOT/tests/unit/$c" ] && FILTERS="$FILTERS /$c"; done
    [ -n "$FILTERS" ] || { echo "the changed files have no unit tests"; exit 0; }
  fi
fi

# Fixtures live outside the kit repo, in a root unique to this run, so a
# fixture git command that misfires can never reach the kit's own history,
# and parallel runs can't delete each other's fixtures.
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/yaykit-tests.XXXXXX")"
RUN_ROOT="$(cd "$RUN_ROOT" && pwd -P)"
export RUN_ROOT
export GIT_CEILING_DIRECTORIES="$(dirname "$RUN_ROOT")"
export YAY_FIXTURE_CACHE="$RUN_ROOT/fixtures"
KIT_HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
trap 'rm -rf "$RUN_ROOT"' EXIT
TIMES="$ROOT/tests/.times"   # last run's seconds per engine, file and test, to start the slowest first

# One job: one test_* function of one file on one engine. Writes FAIL lines, then
# "RESULT <fails> <seconds>", to $RUN_ROOT/out/<engine>.<file>.<test>.
run_one() {
  local engine="$1" f="$2" t="$3" out="$RUN_ROOT/out/$1.$(basename "$2").$3" start
  start="$(date +%s)"
  (
    export YAY_JSON_ENGINE="$engine"
    T_TMP="$(mktemp -d "$RUN_ROOT/run.XXXXXX")"; export T_TMP
    . "$ROOT/tests/lib/assert.sh"
    . "$f"
    T_NAME="$(basename "$f" .sh):$t"
    ( unset YAY_REPO; cd "$T_TMP" && "$t" ) || true
    rm -rf "$T_TMP"
  ) > "$out.log" 2>&1
  # A typo'd assertion or helper in the test file itself is a failure, not a silent pass.
  grep -F "$f: line " "$out.log" | grep ': command not found$' | sed "s|^|    FAIL $(basename "$f" .sh):$t: |" >> "$out.log" || true
  grep '^    FAIL' "$out.log" > "$out" || true
  printf 'RESULT %s %s\n' "$(grep -c '^    FAIL' "$out.log" || true)" "$(( $(date +%s) - start ))" >> "$out"
}
export -f run_one

mkdir -p "$RUN_ROOT/out"
first="${ENGINES%%,*}"
jobs=""
for engine in $(printf '%s' "$ENGINES" | tr ',' ' '); do
  for f in "$ROOT"/tests/unit/*.sh; do
    if [ -n "$FILTERS" ]; then
      hit=""; for x in $FILTERS; do case "$f" in *"$x"*) hit=1 ;; esac; done
      [ -n "$hit" ] || continue
    fi
    # Only `# per-engine` files run past the first engine (unless --all-engines).
    if [ -z "$ALL_ENGINES" ] && [ "$engine" != "$first" ] && ! grep -q '^# per-engine' "$f"; then continue; fi
    for t in $(sed -nE 's/^(test_[A-Za-z0-9_]+)\(\).*/\1/p' "$f"); do
      w="$(awk -v k="$engine $(basename "$f") $t" '$1 " " $2 " " $3 == k { print $4 }' "$TIMES" 2>/dev/null)"
      jobs="$jobs${w:-1} $engine $f $t
"
    done
  done
done
[ -n "$jobs" ] || { echo "no test files match:$FILTERS"; exit 1; }
n="$(printf '%s' "$jobs" | grep -c .)"
echo "running $n tests on ${ENGINES//,/, } with $JOBS jobs"
t0="$(date +%s)"
printf '%s' "$jobs" | sort -rn | cut -d' ' -f2- | xargs -P "$JOBS" -n 3 bash -c 'run_one "$1" "$2" "$3"' _

total_fail=0
newtimes=""
for engine in $(printf '%s' "$ENGINES" | tr ',' ' '); do
  header=""
  for f in "$ROOT"/tests/unit/*.sh; do
    b="$(basename "$f")"; ran=""; fails=0; secs=0
    for o in "$RUN_ROOT/out/$engine.$b".test_*; do
      case "$o" in *.log) continue ;; esac
      [ -f "$o" ] || continue
      ran=1
      grep '^    FAIL' "$o" || true
      set -- $(grep '^RESULT' "$o"); fails=$((fails + ${2:-1})); secs=$((secs + ${3:-0}))
      newtimes="$newtimes$engine $b ${o##*.} ${3:-0}
"
    done
    [ -n "$ran" ] || continue
    [ -n "$header" ] || { echo "== engine: $engine"; header=1; }
    printf '  %-28s %-10s %3ss\n' "$b" "$([ "$fails" = 0 ] && echo ok || echo "$fails failed")" "$secs"
    total_fail=$((total_fail + fails))
  done
done
# Keep the times of files this run skipped.
printf '%s' "$newtimes" > "$RUN_ROOT/times"
if [ -f "$TIMES" ]; then
  awk 'NR == FNR { seen[$1 " " $2 " " $3] = 1; next } NF == 4 && !(($1 " " $2 " " $3) in seen)' "$RUN_ROOT/times" "$TIMES" >> "$RUN_ROOT/times"
fi
sort "$RUN_ROOT/times" > "$TIMES" 2>/dev/null || true
echo "done in $(( $(date +%s) - t0 ))s (per-file times are the sum of their tests)"

if [ "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)" != "$KIT_HEAD" ]; then
  echo "FATAL: the kit repo's HEAD moved during the tests (a fixture committed to it). Reset it." >&2
  exit 2
fi
if [ "$total_fail" -gt 0 ]; then echo "FAILED: $total_fail assertion(s)"; exit 1; fi
echo "all tests passed"
# Stamp a green full run, unless the code changed while it ran.
if [ -n "$FULL" ] && [ "$(_code_hash)" = "$CODE_HASH" ]; then
  printf '%s %s %s\n' "$CODE_HASH" "$(date +%Y-%m-%d)" "$ENGINES" >> "$PASSED"
fi
