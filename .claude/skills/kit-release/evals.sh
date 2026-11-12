#!/usr/bin/env bash
# Run the eval cases the gate picked, once each, three at a time, and compare each
# with its last score in plugins/yay/evals/scores.tsv:
#   .claude/skills/kit-release/evals.sh <case>...
# A case that scores below its last score is re-run once with 2 runs, and the
# re-run's score counts (a single run is noisy). Prints one tab-separated line per case:
#   <case>  <last score|new>  <score>  <runs>  ok|new|lower|drop
# lower: below the last score by 0.25 or less. drop: by more than 0.25 (blocks the release).
# Then "cost <usd>". Changes nothing in the repo except evals/results/.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel)" || exit 2
[ $# -gt 0 ] || { echo "usage: evals.sh <case>..." >&2; exit 2; }
Y="$ROOT/plugins/yay"
OUT="$Y/evals/results/release-$(date +%Y%m%dT%H%M%S)"
mkdir -p "$OUT"
export ROOT Y OUT

_one() { # case runs -> runs the case into $OUT/<case>.<runs>
  PATH="$Y/bin:$PATH" claude plugin eval "$Y" --case "$1" --runs "$2" -j "$2" --judge-model sonnet \
    --ablation none --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish \
    --max-cost-usd 8 --threshold 0 --output-dir "$OUT/$1.$2" > "$OUT/$1.$2.log" 2>&1
}
_score() { python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
print("%.2f %.4f" % (d["cases"][0]["aggregates"]["score"], d.get("costUsd", 0)))' "$OUT/$1.$2/aggregate-result.json" 2>/dev/null; }
export -f _one

printf '%s\n' "$@" | xargs -P 3 -I{} bash -c '_one "$1" 1' _ {}

cost=0
for c in "$@"; do
  last="$(awk -F'\t' -v c="$c" '$1 == c { s = $3 } END { print s }' "$Y/evals/scores.tsv")"
  read -r s usd <<< "$(_score "$c" 1)"; cost="$(echo "$cost + ${usd:-0}" | bc)"; runs=1
  if [ -z "$s" ]; then printf '%s\t%s\t-\t1\terror (see %s)\n' "$c" "${last:-new}" "$OUT/$c.1.log"; continue; fi
  if [ -n "$last" ] && [ "$(echo "$s < $last" | bc)" = 1 ]; then
    _one "$c" 2; read -r s2 usd <<< "$(_score "$c" 2)"
    if [ -n "$s2" ]; then s="$s2"; runs=2; cost="$(echo "$cost + ${usd:-0}" | bc)"; fi
  fi
  if [ -z "$last" ]; then v=new
  elif [ "$(echo "$s >= $last" | bc)" = 1 ]; then v=ok
  elif [ "$(echo "$last - $s > 0.25" | bc)" = 1 ]; then v=drop
  else v=lower; fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$c" "${last:-new}" "$s" "$runs" "$v"
done
printf 'cost\t%s\n' "$cost"
echo "transcripts: $OUT" >&2
