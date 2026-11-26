# shellcheck shell=bash
# `yayh verify <plan> [--run]`: a plan's Verify items that are commands get run,
# so "done" is checked by the machine rather than asserted by the implementer.
# An item is a command check when it reads: - `<command>` → <expected>
#   expected: `exit N` (the exit code), or text the output must contain
#   (backticks or quotes around it are stripped). `->` works as the arrow too.
# Every other item is a manual check.

# _yay_verify_items <file> -> TSV: n kind(cmd|manual) command expected text
_yay_verify_items() {
  awk '
    /^## / { on = ($0 ~ /^## Verify/); next }
    !on || /^<!--/ { next }
    /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+[^[:space:]]/ {
      line = $0; sub(/^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+/, "", line)
      sub(/^(✅|❌|⚠️|⚠|⏭️|⏭|⬜)[[:space:]]+/, "", line)
      n++; kind = "manual"; cmd = ""; want = ""
      if (substr(line, 1, 1) == "`" && match(line, /^`[^`]+`[[:space:]]*(→|->)[[:space:]]*/)) {
        head = substr(line, 1, RLENGTH); rest = substr(line, RLENGTH + 1)
        cmd = head; sub(/^`/, "", cmd); sub(/`[[:space:]]*(→|->)[[:space:]]*$/, "", cmd)
        want = rest; sub(/[[:space:]]+(\(|—|--).*$/, "", want)
        gsub(/^[`"'\'']+|[`"'\'']+$/, "", want)
        kind = "cmd"
      }
      gsub(/\t/, " ", line)
      printf "%d\t%s\t%s\t%s\t%s\n", n, kind, (cmd == "" ? "-" : cmd), (want == "" ? "-" : want), line
    }' "$1"
}

# _yay_verify_mark <file> <marks: "n<TAB>icon" lines; "*<TAB>icon" = every unmarked item>
# rewrites the icon at the start of those Verify items; returns 1 when nothing changed
_yay_verify_mark() {
  local tmp; tmp="$(mktemp)"
  YAY_MARKS="$2" awk '
    BEGIN { k = split(ENVIRON["YAY_MARKS"], L, "\n"); for (i = 1; i <= k; i++) if (split(L[i], P, "\t") == 2) m[P[1]] = P[2]
            icon = "^(✅|❌|⚠️|⚠|⏭️|⏭|⬜)[[:space:]]+" }
    /^## / { on = ($0 ~ /^## Verify/); print; next }
    !on || /^<!--/ { print; next }
    match($0, /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+/) && substr($0, RLENGTH + 1) ~ /^[^[:space:]]/ {
      n++; pre = substr($0, 1, RLENGTH); rest = substr($0, RLENGTH + 1)
      if (n in m) { sub(icon, "", rest); $0 = pre m[n] " " rest }
      else if (("*" in m) && rest !~ icon) $0 = pre m["*"] " " rest
    }
    { print }' "$1" > "$tmp" || { rm -f "$tmp"; return 2; }
  if cmp -s "$1" "$tmp"; then rm -f "$tmp"; return 1; fi
  cat "$tmp" > "$1"; rm -f "$tmp"
}

# yay_verify <plan> [--run [--mark]] -> TSV: n status command expected detail
#   without --run: status is cmd | manual (what would run)
#   with --run:    status is pass | fail | manual; exit 1 when any command check fails
#   --mark (with --run) writes ✅ or ❌ at the start of each command item in the plan
yay_verify() {
  local plan="" run=0 mark=0 marks="" a rel f root n kind cmd exp text out code fails=0 status detail
  for a in "$@"; do case "$a" in --run) run=1 ;; --mark) mark=1 ;; -*) yay_die "usage: yayh verify <plan> [--run [--mark]]" ;; *) plan="$a" ;; esac; done
  [ -n "$plan" ] || yay_die "usage: yayh verify <plan> [--run [--mark]]"
  [ "$mark" = 0 ] || [ "$run" = 1 ] || yay_die "--mark needs --run"
  root="$(yay_repo_root)"
  rel="$(yay_artifact_resolve "$plan")" || yay_die "no plan '$plan'"
  f="$root/$rel"
  while IFS="$YAY_TAB" read -r n kind cmd exp text; do
    [ -n "$n" ] || continue
    if [ "$kind" = manual ]; then printf '%s\tmanual\t-\t-\t%s\n' "$n" "$text"; continue; fi
    if [ "$run" = 0 ]; then printf '%s\tcmd\t%s\t%s\t%s\n' "$n" "$cmd" "$exp" "$text"; continue; fi
    code=0; out="$(cd "$root" && bash -c "$cmd" </dev/null 2>&1)" || code=$?
    case "$exp" in
      'exit '[0-9]*) if [ "$code" = "${exp#exit }" ]; then status=pass; else status=fail; fi
                     detail="exit $code" ;;
      -) if [ "$code" = 0 ]; then status=pass; else status=fail; fi; detail="exit $code" ;;
      *) case "$out" in *"$exp"*) status=pass ;; *) status=fail ;; esac
         detail="exit $code; output $( [ "$status" = pass ] && echo contains || echo lacks ) the expected text" ;;
    esac
    [ "$status" = pass ] || detail="$detail: $(printf '%s' "$out" | tail -n 3 | tr '\t\n' '  ' | cut -c1-200)"
    [ "$status" = pass ] || fails=$((fails + 1))
    marks="$marks$n$YAY_TAB$([ "$status" = pass ] && echo ✅ || echo ❌)
"
    printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$status" "$cmd" "$exp" "$detail"
  done <<EOT
$(_yay_verify_items "$f")
EOT
  [ "$mark" = 0 ] || _yay_verify_mark "$f" "$marks" || [ $? = 1 ] || yay_die "could not mark $rel"
  [ "$fails" -eq 0 ]
}
