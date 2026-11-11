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

# yay_verify <plan> [--run] -> TSV: n status command expected detail
#   without --run: status is cmd | manual (what would run)
#   with --run:    status is pass | fail | manual; exit 1 when any command check fails
yay_verify() {
  local plan="" run=0 a rel f root n kind cmd exp text out code fails=0 status detail
  for a in "$@"; do case "$a" in --run) run=1 ;; -*) yay_die "usage: yayh verify <plan> [--run]" ;; *) plan="$a" ;; esac; done
  [ -n "$plan" ] || yay_die "usage: yayh verify <plan> [--run]"
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
    printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$status" "$cmd" "$exp" "$detail"
  done <<EOT
$(_yay_verify_items "$f")
EOT
  [ "$fails" -eq 0 ]
}
