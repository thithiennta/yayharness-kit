# shellcheck shell=bash
# Lessons: friction a run hit (a hook rejection, a review finding, a blocked item,
# a check that couldn't run), appended to .yay/runs/lessons.md (gitignored, per
# checkout). /yay:knowledge-update promotes the ones that repeat into docs/knowledge/,
# and lists the ones about the kit itself for the kit's maintainers.

YAY_LESSON_KINDS='hook review blocked env plan retry kit'

_yay_lessons_file() { printf '%s/.yay/runs/lessons.md\n' "$(yay_repo_root)"; }

# yay_lessons_add "<what happened>" [kind=…] [from=<id>]
yay_lessons_add() {
  local text="${1:-}" kind=plan from="-" kv f
  [ -n "$text" ] || yay_die "usage: yayh lessons add \"<what happened>\" [kind=$(echo $YAY_LESSON_KINDS | tr ' ' '|')] [from=<id>]"
  shift
  for kv in "$@"; do
    case "$kv" in kind=*) kind="${kv#kind=}" ;; from=*) from="${kv#from=}" ;; *) yay_die "unknown option '$kv'" ;; esac
  done
  yay_in_list "$kind" "$(printf '%s\n' $YAY_LESSON_KINDS)" || yay_die "kind must be one of: $YAY_LESSON_KINDS"
  case "$text" in *$'\n'*) yay_die "a lesson is one line" ;; esac
  f="$(_yay_lessons_file)"; mkdir -p "$(dirname "$f")"
  [ -f "$f" ] || printf '# Lessons (yayh lessons add; promoted by /yay:knowledge-update)\n\n' > "$f"
  printf -- '- %s [%s] (%s) %s\n' "$(yay_today)" "$kind" "$from" "$text" >> "$f"
  printf '%s\t%s\t%s\n' "$kind" "$from" "$text"
}

# yay_lessons_list [--kind=k] [--since=YYYY-MM-DD] -> TSV: date kind from text, then
# "count<TAB>kind<TAB>n" lines per kind (--counts only prints those)
yay_lessons_list() {
  local kind="" since="" counts=0 a f
  for a in "$@"; do
    case "$a" in --kind=*) kind="${a#--kind=}" ;; --since=*) since="${a#--since=}" ;; --counts) counts=1 ;; *) yay_die "usage: yayh lessons list [--kind=k] [--since=YYYY-MM-DD] [--counts]" ;; esac
  done
  f="$(_yay_lessons_file)"; [ -f "$f" ] || return 0
  sed -nE 's/^- ([0-9-]{10}) \[([a-z]+)\] \(([^)]*)\) (.*)$/\1\t\2\t\3\t\4/p' "$f" \
  | awk -F '\t' -v k="$kind" -v s="$since" -v c="$counts" '
      (k == "" || $2 == k) && (s == "" || $1 >= s) { n[$2]++; if (!c) print }
      END { for (x in n) printf "count\t%s\t%d\n", x, n[x] }'
}
