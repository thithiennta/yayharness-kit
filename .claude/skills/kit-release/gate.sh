#!/usr/bin/env bash
# What a kit release has to run. Prints two tab-separated lines:
#   tests  skip|run  <why>
#   evals  skip|run  <n of N cases: names>   (then one indented line per case: why)
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

# Evals, case by case. A case covers its own directory, the skills and agents its
# tags name (skills/<tag>/, agents/<tag>.md), and every reference or agent those
# files mention. It runs when one of them changed since the kit version that last
# scored it (evals/scores.tsv), or when it has never been scored.
SCORES="$ROOT/plugins/yay/evals/scores.tsv"
Y="$ROOT/plugins/yay"
_covers() { # case -> covered paths, repo-relative
  local c="$1" tags t f b
  printf 'plugins/yay/evals/%s\n' "$c"
  tags="$(sed -n 's/^tags: *\[\(.*\)\]/\1/p' "$Y/evals/$c/case.yaml" | tr ',' ' ')"
  for t in $tags; do
    for f in "$Y/skills/$t/SKILL.md" "$Y/agents/$t.md"; do
      [ -f "$f" ] || continue
      printf '%s\n' "${f#$ROOT/}"; [ "${f##*/}" = SKILL.md ] && printf '%s\n' "plugins/yay/skills/$t"
      for b in "$Y"/reference/* "$Y"/agents/*.md; do
        grep -qF "$(basename "$b" .md)" "$f" && printf '%s\n' "${b#$ROOT/}"
      done
    done
  done | sort -u
}
run=""; why=""; n=0
for d in "$Y"/evals/*/case.yaml; do
  c="$(basename "$(dirname "$d")")"
  v="$(awk -F'\t' -v c="$c" '$1 == c { v = $2 } END { print v }' "$SCORES" 2>/dev/null)"
  commit=""
  [ -z "$v" ] || commit="$(git -C "$ROOT" log --format=%H -1 --grep="^chore(release): yay kit $v\$")"
  if [ -z "$commit" ]; then
    run="$run $c"; why="$why  $c: never scored${v:+ (no release commit for $v)}
"; continue
  fi
  changed="$(_covers "$c" | (cd "$ROOT" && xargs git diff --name-only "$commit" --) | sed -n '1,3p' | tr '\n' ' ')"
  [ -n "$changed" ] || continue
  run="$run $c"; why="$why  $c: changed since $v: $changed
"
done
if [ -z "$run" ]; then
  printf 'evals\tskip\tno case covers skill text that changed since its last score\n'
else
  printf 'evals\trun\t%s\n' "$(printf '%s\n' $run | grep -c .) of $(ls "$Y"/evals/*/case.yaml | wc -l | tr -d ' ') cases:$run"
  printf '%s' "$why"
fi
