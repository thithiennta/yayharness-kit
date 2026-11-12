# shellcheck shell=bash
# Symbol search for reuse: what functions, methods and classes already exist.
# Plain awk over tracked source files; no PHP or Node parser needed.

# _yay_code_files -> tracked PHP/JS/TS source files, minus vendor, builds and generated paths.
_yay_code_files() {
  local root gen f
  root="$(yay_repo_root)"
  gen="$(yay_config_get generatedPaths 2>/dev/null || true)"
  git -C "$root" ls-files -- '*.php' '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' 2>/dev/null \
    | while IFS= read -r f; do
        case "$f" in
          vendor/*|*/vendor/*|node_modules/*|*/node_modules/*|*.min.js|dist/*|*/dist/*|build/*|*/build/*|release/*) continue ;;
          tests/*|*/tests/*|*.test.*|*.spec.*|*/__tests__/*) continue ;;
        esac
        if [ -n "$gen" ] && _yay_code_generated "$f" "$gen"; then continue; fi
        printf '%s\n' "$f"
      done
}

_yay_code_generated() { # <path> <newline list of globs/prefixes>
  local g
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    g="${g%/}"
    case "$1" in "$g"|"$g"/*) return 0 ;; esac
    # shellcheck disable=SC2254
    case "$1" in $g) return 0 ;; esac
  done <<EOF
$2
EOF
  return 1
}

# yay_code_index [file...] -> TSV: file line kind name signature doc-summary
# kind: class | function | method | const. Methods are Class::name (PHP) or Class.name (JS).
yay_code_index() {
  local root
  root="$(yay_repo_root)"
  { if [ $# -gt 0 ]; then printf '%s\n' "$@"; else _yay_code_files; fi; } | while IFS= read -r f; do
    [ -f "$root/$f" ] || continue
    awk -v file="$f" '
      function sig(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]*\{[[:space:]]*$/, "", s); return substr(s, 1, 160) }
      function emit(kind, name) { printf "%s\t%d\t%s\t%s\t%s\t%s\n", file, FNR, kind, name, sig($0), doc; doc = "" }
      # docblock summary: the first text line of the /** … */ right above a definition
      /^[[:space:]]*\/\*\*/ { indoc = 1; got = 0; doc = ""; t = $0; sub(/^[[:space:]]*\/\*\*[[:space:]]*/, "", t); sub(/[[:space:]]*\*\/.*$/, "", t); if (t != "") { doc = t; got = 1 } if ($0 ~ /\*\//) indoc = 0; next }
      indoc { if (!got) { t = $0; sub(/^[[:space:]]*\*[[:space:]]?/, "", t); if (t != "" && t !~ /^@/) { doc = t; got = 1 } } if ($0 ~ /\*\//) indoc = 0; next }
      /^[[:space:]]*(\/\/|\*|\/\*|#)/ { next }
      /^[[:space:]]*$/ { next }
      # PHP / JS classes, interfaces, traits, enums
      match($0, /(^|[[:space:]])(abstract[[:space:]]+|final[[:space:]]+|export[[:space:]]+(default[[:space:]]+)?)*(class|interface|trait|enum)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
        s = substr($0, RSTART, RLENGTH); n = split(s, w, /[[:space:]]+/); cls = w[n]; depth_cls = 1; emit("class", cls); next
      }
      # PHP functions and methods
      file ~ /\.php$/ && match($0, /function[[:space:]]+&?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/) {
        s = substr($0, RSTART, RLENGTH); sub(/^function[[:space:]]+&?/, "", s); sub(/[[:space:]]*\($/, "", s)
        if (s ~ /^__/) next
        if (cls != "" && $0 ~ /^[[:space:]]+/) emit("method", cls "::" s); else emit("function", s)
        next
      }
      file ~ /\.php$/ && match($0, /^[[:space:]]*(public[[:space:]]+|private[[:space:]]+|protected[[:space:]]+)?const[[:space:]]+[A-Z_][A-Z0-9_]*/) {
        s = substr($0, RSTART, RLENGTH); n = split(s, w, /[[:space:]]+/); emit("const", (cls != "" ? cls "::" : "") w[n]); next
      }
      file ~ /\.php$/ && match($0, /define\([[:space:]]*.[A-Z_][A-Z0-9_]*./) {
        s = substr($0, RSTART, RLENGTH); sub(/^define\([[:space:]]*./, "", s); sub(/.$/, "", s); emit("const", s); next
      }
      # JS / TS functions
      file !~ /\.php$/ && match($0, /^[[:space:]]*(export[[:space:]]+)?(default[[:space:]]+)?(async[[:space:]]+)?function\*?[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*/) {
        s = substr($0, RSTART, RLENGTH); n = split(s, w, /[[:space:]]+/); s = w[n]; sub(/^\*/, "", s); emit("function", s); next
      }
      file !~ /\.php$/ && match($0, /^[[:space:]]*(export[[:space:]]+)?const[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*(:[^=]*)?=[[:space:]]*(async[[:space:]]*)?(\([^)]*\)|[A-Za-z_$][A-Za-z0-9_$]*)[[:space:]]*(:[^=]*)?=>/) {
        s = $0; sub(/^[[:space:]]*(export[[:space:]]+)?const[[:space:]]+/, "", s); sub(/[^A-Za-z0-9_$].*/, "", s); emit("function", s); next
      }
      file !~ /\.php$/ && cls != "" && match($0, /^[[:space:]]+(static[[:space:]]+)?(async[[:space:]]+)?[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\([^)]*\)[[:space:]]*\{/) {
        s = $0; sub(/^[[:space:]]+(static[[:space:]]+)?(async[[:space:]]+)?/, "", s); sub(/[^A-Za-z0-9_$].*/, "", s)
        if (s !~ /^(if|for|while|switch|catch|function|return|constructor)$/) emit("method", cls "." s); next
      }
      { doc = "" }
    ' "$root/$f"
  done
}

# _yay_code_words <text> -> lowercase words, split on non-alphanumerics and camelCase.
_yay_code_words() {
  printf '%s\n' "$*" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' ' ' \
    | tr ' ' '\n' | awk 'length($0) >= 2 && !seen[$0]++'
}

# yay_code_find <words...> [--limit=N] [--kind=function|method|class|const]
# -> TSV: score file:line kind name signature doc, best first. A word scores 2 when it is a
# prefix of one of the symbol's own words ("format" finds Format::price and formatFee), and 1
# when it only appears in the docblock summary.
yay_code_find() {
  local limit=20 kind="" a q=""
  for a in "$@"; do
    case "$a" in --limit=*) limit="${a#--limit=}" ;; --kind=*) kind="${a#--kind=}" ;; *) q="$q $a" ;; esac
  done
  [ -n "${q# }" ] || yay_die "usage: yayh code find <words...> [--limit=N] [--kind=…]"
  local words; words="$(_yay_code_words "$q" | tr '\n' ' ')"
  yay_code_index | awk -F '\t' -v words="$words" -v kind="$kind" '
    function split_words(s, out,   i, c, buf) {
      # camelCase and snake_case -> words (portable awk has no lookbehind)
      out_n = 0; buf = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c ~ /[A-Z]/ && i > 1 && substr(s, i - 1, 1) ~ /[a-z0-9]/) { if (buf != "") out[++out_n] = tolower(buf); buf = c }
        else if (c ~ /[A-Za-z0-9]/) buf = buf c
        else { if (buf != "") out[++out_n] = tolower(buf); buf = "" }
      }
      if (buf != "") out[++out_n] = tolower(buf)
      return out_n
    }
    BEGIN { nq = split(words, qw, " ") }
    kind != "" && $3 != kind { next }
    {
      delete sw; n = split_words($4, sw); delete dw; m = split_words($6, dw); score = 0
      for (i = 1; i <= nq; i++) { if (qw[i] == "") continue
        hit = 0
        for (j = 1; j <= n; j++) if (index(sw[j], qw[i]) == 1 || index(qw[i], sw[j]) == 1 && length(sw[j]) >= 3) { hit = 2; break }
        if (!hit) for (j = 1; j <= m; j++) if (index(dw[j], qw[i]) == 1 && length(qw[i]) >= 3) { hit = 1; break }
        score += hit }
      if (score > 0) printf "%d\t%s:%s\t%s\t%s\t%s\t%s\n", score, $1, $2, $3, $4, $5, $6
    }' | sort -t "$(printf '\t')" -k1,1nr -k4,4 | sed -n "1,${limit}p"
}

# yay_code_new [base] -> TSV: file line kind name signature, for symbols whose definition
# line is added on this branch (committed since the merge base, staged or unstaged).
yay_code_new() {
  local base="${1:-}" root mb files f
  root="$(yay_repo_root)"
  [ -n "$base" ] || base="$(yay_base_branch)"
  mb="$(git -C "$root" merge-base "$base" HEAD 2>/dev/null || git -C "$root" rev-parse "$base" 2>/dev/null || true)"
  [ -n "$mb" ] || yay_die "can't find base '$base'"
  files="$( { git -C "$root" diff --name-only --diff-filter=AM "$mb" -- 2>/dev/null; git -C "$root" ls-files --others --exclude-standard; } | sort -u)"
  local added idx
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *.php|*.js|*.jsx|*.ts|*.tsx|*.mjs) ;; *) continue ;; esac
    idx="$(yay_code_index "$f")"; [ -n "$idx" ] || continue
    if git -C "$root" ls-files --error-unmatch -- "$f" >/dev/null 2>&1 && git -C "$root" cat-file -e "$mb:$f" 2>/dev/null; then
      added="$(git -C "$root" diff -U0 "$mb" -- "$f" | awk '/^@@/ { split($3, a, ","); l = substr(a[1], 2) + 0; next } /^\+\+\+/ { next } /^\+/ { printf "%s%d", (n++ ? "," : ""), l; l++ }')"
    else
      added="ALL"
    fi
    printf '%s\n' "$idx" | awk -F '\t' -v added="$added" 'BEGIN { if (added != "ALL") { n = split(added, a, ","); for (i = 1; i <= n; i++) ok[a[i]] = 1 } }
      added == "ALL" || ($2 in ok)'
  done <<EOF
$files
EOF
}

_yay_code_is_test() { # <path>
  case "$1" in tests/*|*/tests/*|*.test.*|*.spec.*|*/__tests__/*) return 0 ;; esac
  return 1
}

# yay_code_unused [base] -> TSV: status file:line kind name note, for each symbol this branch
# adds that no other source line names. status: unused (nothing names it) or test-only (only
# tests do: a test alone isn't a caller). The search is by whole word, so a mention in a string
# or a comment counts as a caller: lines here are leads to confirm, and a clean run proves little
# for a common name. note: for a method of a class that extends or implements something, a hint
# that the parent may call it by name (a WordPress or WooCommerce override).
yay_code_unused() {
  local base="${1:-}" root gen news f ln kind name sig doc short hits h src tst note csig
  root="$(yay_repo_root)"
  gen="$(yay_config_get generatedPaths 2>/dev/null || true)"
  news="$(yay_code_new "$base")" || return 1
  while IFS="$YAY_TAB" read -r f ln kind name sig doc; do
    [ -n "$name" ] || continue
    _yay_code_is_test "$f" && continue
    short="${name##*::}"; short="${short##*.}"
    hits="$(git -C "$root" grep -n -w -I -F --untracked -e "$short" -- \
        '*.php' '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' \
        ':!*vendor/*' ':!*node_modules/*' ':!*.min.js' ':!dist/*' ':!*/dist/*' ':!build/*' ':!*/build/*' ':!release/*' 2>/dev/null \
      | awk -F ':' -v self="$f:$ln" '$1 ":" $2 != self { print $1 }')"
    src=0; tst=0
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      if [ -n "$gen" ] && _yay_code_generated "$h" "$gen"; then continue; fi
      if _yay_code_is_test "$h"; then tst=$((tst + 1)); else src=$((src + 1)); fi
    done <<EOF
$hits
EOF
    [ "$src" -eq 0 ] || continue
    note=""
    if [ "$kind" = method ]; then
      csig="$(yay_code_index "$f" | awk -F '\t' -v ln="$ln" '$3 == "class" && $2 + 0 < ln + 0 { s = $5 } END { print s }')"
      case "$csig" in *" extends "*|*" implements "*)
        note="may be called by name from its parent: ${csig#*class }" ;;
      esac
    fi
    printf '%s\t%s:%s\t%s\t%s\t%s\n' "$( [ "$tst" -gt 0 ] && echo test-only || echo unused )" "$f" "$ln" "$kind" "$name" "$note"
  done <<EOF
$news
EOF
}

# yay_code_similar <name> [--exclude=file:line] -> like code find, for an identifier.
yay_code_similar() {
  local name="$1"; shift
  yay_code_find "$(_yay_code_words "$name" | tr '\n' ' ')" "$@"
}
