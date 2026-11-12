#!/usr/bin/env bash
# What a kit release has to run. Prints two tab-separated lines:
#   tests  skip|run  <why>
#   evals  skip|run  <why>   (then the changed files, indented, at most 10)
# Run from anywhere inside the kit repo. Changes nothing.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel)" || exit 2
LOG="$ROOT/plugins/yay/evals/README.md"

if t="$("$ROOT/tests/run.sh" --tested)"; then
  set -- $t
  printf 'tests\tskip\tthe kit code is unchanged since the green full run on %s (%s)\n' "$3" "$4"
else
  printf 'tests\trun\tno green full run on this machine has tested the kit code as it is now\n'
fi

# The last kit version the eval suite scored: the last score-log row with Runs above 0.
scored="$(awk -F'|' '/^\| *[0-9]+\.[0-9]+\.[0-9]+ *\|/ { v=$2; r=$3; gsub(/ /, "", v); gsub(/ /, "", r); if (r + 0 > 0) last = v } END { print last }' "$LOG")"
commit=""
[ -z "$scored" ] || commit="$(git -C "$ROOT" log --format=%H -1 --grep="^chore(release): yay kit $scored\$")"
if [ -z "$commit" ]; then
  printf 'evals\trun\tno scored kit version with a release commit in the score log\n'
  exit 0
fi
changed="$(git -C "$ROOT" diff --name-only "$commit" -- \
  plugins/yay/skills plugins/yay/agents plugins/yay/reference plugins/yay/templates \
  plugins/yay/workflows plugins/yay/evals ':(exclude)plugins/yay/evals/README.md')"
if [ -z "$changed" ]; then
  printf 'evals\tskip\tno skill, agent, reference, template, workflow or eval case changed since %s, the last scored version\n' "$scored"
else
  printf 'evals\trun\t%s files of skill text changed since %s, the last scored version\n' "$(printf '%s\n' "$changed" | grep -c .)" "$scored"
  printf '%s\n' "$changed" | sed -n '1,10s/^/  /p'
fi
