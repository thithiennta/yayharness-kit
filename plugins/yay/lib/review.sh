# shellcheck shell=bash
# yayh review diff: flag-only checks on this branch's changes, for reuse and comment
# discipline (reference/code-rules.md). Never blocks: it prints findings for Claude
# (and the reviewer agent) to fix or answer.

# yay_review_diff [base] [--plan=P-n] -> TSV: kind<TAB>where<TAB>message, then a summary line.
# Kinds:
#   similar-exists   a new function/method whose name matches existing ones
#   no-caller        a new symbol no other code names, or only tests do (yayh code unused)
#   comment-edited   an existing comment line was reworded or removed in a hunk that changes it
#   comment-grown    comment lines added directly next to an existing comment block
#   comment-heavy    a hunk adds as many inline comment lines as code lines
#   comment-elsewhere an added comment names a class, function or file not used in this file's code
#   comment-changelog an added comment reads like a change log ("added for", "fixed", "new:")
#   docblock-prose   a new docblock has more than two lines of prose besides the summary and tags
#   outside-plan     a changed file isn't named in the plan's tasks
yay_review_diff() {
  local base="" plan="" a root mb
  for a in "$@"; do case "$a" in --plan=*) plan="${a#--plan=}" ;; *) base="$a" ;; esac; done
  root="$(yay_repo_root)"
  [ -n "$base" ] || base="$(yay_base_branch)"
  mb="$(git -C "$root" merge-base "$base" HEAD 2>/dev/null || true)"
  [ -n "$mb" ] || yay_die "can't find the merge base with '$base'"
  local out; out="$(mktemp)"

  # 1. New symbols that look like existing ones.
  local news f ln kind name sig doc short hits h
  news="$(yay_code_new "$base")"
  while IFS="$YAY_TAB" read -r f ln kind name sig doc; do
    [ -n "$name" ] || continue
    case "$kind" in function|method) ;; *) continue ;; esac
    short="${name##*::}"; short="${short##*.}"
    hits="$(yay_code_similar "$short" --limit=8 2>/dev/null | awk -F '\t' -v self="$f:$ln" -v news="$(printf '%s' "$news" | awk -F '\t' '{ printf "%s:%s,", $1, $2 }')" '
        $1 >= 3 && $2 != self && index("," news, "," $2 ",") == 0 && ($3 == "function" || $3 == "method") { printf "%s (%s)", $4, $2; n++; if (n == 3) exit; printf "; " }')"
    hits="${hits%; }"
    [ -z "$hits" ] || printf 'similar-exists\t%s:%s\t%s() is new; existing look-alikes: %s. Reuse or extend one, or say why not.\n' "$f" "$ln" "$name" "$hits" >> "$out"
  done <<EOF
$news
EOF

  # 1b. New symbols nothing calls.
  local st where note
  while IFS="$YAY_TAB" read -r st where kind name note; do
    [ -n "$name" ] || continue
    if [ "$st" = test-only ]; then
      printf 'no-caller\t%s\t%s is new and only tests call it. A test alone is not a caller: delete it, or call it where the plan needs it.\n' "$where" "$name" >> "$out"
    else
      printf 'no-caller\t%s\t%s is new and no other code names it. Delete it, or call it where the plan needs it.%s\n' "$where" "$name" "${note:+ (Check first: it $note.)}" >> "$out"
    fi
  done <<EOF
$(yay_code_unused "$base")
EOF

  # 2. Comment checks, per changed source file (committed, staged, unstaged, untracked).
  local files
  files="$( { git -C "$root" diff --name-only --diff-filter=AM "$mb" -- 2>/dev/null; git -C "$root" ls-files --others --exclude-standard; } | sort -u)"
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$root/$f" ] || continue
    case "$f" in *.php|*.js|*.jsx|*.ts|*.tsx|*.mjs|*.css|*.scss) ;; *) continue ;; esac
    { if git -C "$root" cat-file -e "$mb:$f" 2>/dev/null; then git -C "$root" diff -U0 "$mb" -- "$f"
      else awk '{ if (NR == 1) print "@@ -0,0 +1 @@"; print "+" $0 }' "$root/$f"; fi; } \
      | awk -v file="$f" '
        function is_doc(s)  { return s ~ /^[[:space:]]*(\/\*\*|\*\/|\*([[:space:]]|$))/ }
        function is_line(s) { return s ~ /^[[:space:]]*(\/\/|#[^\[]|#$|\/\*[^*])/ }
        function is_cmt(s)  { return is_doc(s) || is_line(s) }
        function exempt(s)  { return s ~ /(translators:|phpcs:|@premium-|eslint-disable|@ts-|istanbul ignore|phpstan-|psalm-|@codeCoverage)/ }
        function blank(s)   { return s ~ /^[[:space:]]*$/ }
        FNR == NR { L[FNR] = $0; n = FNR; if (!is_cmt($0)) code = code " " $0; next }
        /^@@/ { flush(); split($3, p, ","); nl = substr(p[1], 2) + 0; h = 1; nrem = 0; nadd = 0; next }
        /^(\+\+\+|---|diff |index |new file|deleted file)/ { next }
        /^-/ { rem[++nrem] = substr($0, 2); next }
        /^\+/ { addl[++nadd] = nl; add[nadd] = substr($0, 2); added[nl] = 1; nl++; next }
        function flush(   i, ci, cc, rc, first, t, tok, prose, indoc, lineno, s) {
          if (!h) return
          ci = 0; cc = 0; rc = 0
          for (i = 1; i <= nrem; i++) if (is_cmt(rem[i]) && !exempt(rem[i]) && !blank(rem[i])) rc++
          for (i = 1; i <= nadd; i++) {
            s = add[i]
            if (blank(s)) continue
            if (is_line(s) && !exempt(s)) { ci++; if (!first) first = addl[i] }
            else if (!is_cmt(s)) cc++
          }
          # an existing comment changed or went away
          if (rc > 0) printf "comment-edited\t%s:%d\t%d existing comment line(s) reworded or removed. Only change a comment when the code it describes changed.\n", file, (nadd ? addl[1] : nl), rc
          # inline comments added next to an existing comment block (not one this hunk wrote)
          if (ci > 0) {
            for (i = 1; i <= nadd; i++) {
              if (!is_line(add[i]) || exempt(add[i])) continue
              lineno = addl[i]
              if ((lineno > 1 && !added[lineno - 1] && is_line(L[lineno - 1])) || (!added[lineno + 1] && is_line(L[lineno + 1]))) {
                printf "comment-grown\t%s:%d\tnew comment lines added to an existing comment block. Leave existing blocks alone; put reasoning in the commit or PR.\n", file, lineno; break
              }
            }
          }
          if (ci >= 2 && ci >= cc) printf "comment-heavy\t%s:%d\t%d inline comment line(s) for %d code line(s). Comment only a non-obvious why.\n", file, first, ci, cc
          for (i = 1; i <= nadd; i++) {
            s = add[i]
            if (!is_line(s) || exempt(s)) continue
            t = s
            while (match(t, /[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*(::[A-Za-z_]+)?|[a-z_][a-z0-9_]*\(\)|[A-Za-z0-9_\/-]+\.(php|js|ts|tsx|jsx)/)) {
              tok = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
              sub(/\(\)$/, "", tok); sub(/::.*/, "", tok)
              if (index(code, tok) == 0) { printf "comment-elsewhere\t%s:%d\tcomment mentions %s, which this file'"'"'s code doesn'"'"'t use. Describing other files'"'"' behaviour goes stale; say it in the commit or PR.\n", file, addl[i], tok; break }
            }
            if (tolower(s) ~ /(added|fixed|changed|updated|removed) (for|in|by|to support)|(^|[^a-z])(new|fix|hack|changed):|ticket|issue #|bug #|(^|[^a-z])(p|b|r)-[0-9]+/)
              printf "comment-changelog\t%s:%d\treads like a change log. History belongs in git, not in comments.\n", file, addl[i]
          }
          # new docblocks with prose paragraphs
          indoc = 0; prose = 0
          for (i = 1; i <= nadd; i++) {
            s = add[i]
            if (s ~ /^[[:space:]]*\/\*\*/) { indoc = 1; prose = -1; start = addl[i]; if (s !~ /^[[:space:]]*\/\*\*[[:space:]]*$/) prose = 0; continue }
            if (indoc && s ~ /\*\//) { if (prose > 2) printf "docblock-prose\t%s:%d\tdocblock has %d prose lines besides the summary. WPCS needs a summary and tags, not an essay.\n", file, start, prose; indoc = 0; continue }
            if (indoc && s ~ /^[[:space:]]*\*[[:space:]]+[^@[:space:]]/) prose++
            if (indoc && s ~ /^[[:space:]]*\*[[:space:]]+@/) { if (prose > 2) printf "docblock-prose\t%s:%d\tdocblock has %d prose lines besides the summary. WPCS needs a summary and tags, not an essay.\n", file, start, prose; indoc = 0 }
          }
          h = 0; delete rem; delete add; delete addl
        }
        END { flush() }
      ' "$root/$f" - >> "$out"
  done <<EOF
$files
EOF

  # 3. Files outside the plan.
  if [ -n "$plan" ]; then
    local prel planned
    prel="$(yay_artifact_resolve "$plan")" || yay_die "no plan '$plan'"
    planned="$(awk '/^## /{t=($0 ~ /^## Tasks/)} t' "$root/$prel" | grep -oE '`[^`]+`' | tr -d '`' || true)"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      case "$f" in docs/*|tests/*|*/tests/*|readme.txt|CHANGELOG*|*.lock|package.json|composer.json) continue ;; esac
      if ! printf '%s\n' "$planned" | awk -v f="$f" '{ p = $1; sub(/\/$/, "", p) } f == p || index(f, p "/") == 1 { found = 1 } END { exit !found }'; then
        printf 'outside-plan\t%s\tchanged, but no task in %s names it. Is this change needed for the plan?\n' "$f" "$plan" >> "$out"
      fi
    done <<EOF
$files
EOF
  fi

  cat "$out"
  awk -F '\t' '{ c[$1]++; n++ } END { printf "summary\t%d finding(s)", n; for (k in c) printf "\t%s=%d", k, c[k]; printf "\n" }' "$out" | sort
  rm -f "$out"
  return 0
}
