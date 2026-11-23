# shellcheck shell=bash
# Reports a developer shares with the lead or the team (/yay:report): an idea, a
# summary of what's done, a feature idea. They live in .yay/reports/, never in the
# repo. The agent writes markdown only; render owns the look, check owns the words.

YAY_REPORT_KINDS="idea done feature"
YAY_REPORT_MAX_WORDS=300

_report_sections() {
  case "$1" in
    idea)    printf '%s\n' "In one line" "The problem" "My idea" "What I need from you" ;;
    done)    printf '%s\n' "In one line" "What's done" "What it means for users" "What's next" ;;
    feature) printf '%s\n' "In one line" "Who it's for" "What they'd see" "Why it's worth it" "Rough size" "Questions" ;;
    *) yay_die "unknown report kind '$1' ($YAY_REPORT_KINDS)" ;;
  esac
}

_report_dir() { printf '%s/.yay/reports\n' "$(yay_repo_root)"; }

# yay_report_new <kind> "<title>" -> path of the new markdown file.
yay_report_new() {
  local kind="${1:-}" title="${2:-}" dir slug f author
  [ -n "$kind" ] && [ -n "$title" ] || yay_die "usage: yayh report new <idea|done|feature> \"<title>\""
  _report_sections "$kind" >/dev/null
  case "$title" in *$'\n'*) yay_die "title must be one line";; esac
  slug="$(yay_slugify "$title")"; [ -n "$slug" ] || yay_die "title gives an empty slug"
  dir="$(_report_dir)"; mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  f="$dir/$(yay_today)-$slug.md"
  [ -e "$f" ] && yay_die "${f#"$(yay_repo_root)"/} already exists; open it or pick another title"
  author="$(git -C "$(yay_repo_root)" config user.name 2>/dev/null || true)"
  awk -v t="$title" -v a="$author" -v d="$(yay_today)" '
    { while ((i = index($0, "{{title}}")) > 0)  $0 = substr($0, 1, i-1) t substr($0, i+9)
      while ((i = index($0, "{{author}}")) > 0) $0 = substr($0, 1, i-1) a substr($0, i+10)
      while ((i = index($0, "{{today}}")) > 0)  $0 = substr($0, 1, i-1) d substr($0, i+9)
      print }' "$YAY_TEMPLATES/report/$kind.md" > "$f"
  printf '%s\n' "${f#"$(yay_repo_root)"/}"
}

# _report_file <path|slug> -> absolute path of one report.
_report_file() {
  local q="$1" root dir hits n
  [ -f "$q" ] && { (cd "$(dirname "$q")" && printf '%s/%s\n' "$PWD" "$(basename "$q")"); return; }
  root="$(yay_repo_root)"
  [ -f "$root/$q" ] && { printf '%s/%s\n' "$root" "$q"; return; }
  dir="$(_report_dir)"
  hits="$(find "$dir" -maxdepth 1 -name "*$(yay_slugify "$q")*.md" 2>/dev/null | sort)"
  n="$(printf '%s' "$hits" | grep -c . || true)"
  [ "$n" = 1 ] && { printf '%s\n' "$hits"; return; }
  [ "$n" -gt 1 ] && yay_die "\"$q\" matches several reports: $(printf '%s' "$hits" | tr '\n' ' ')"
  yay_die "no report '$q' (yayh report list)"
}

# yay_report_list -> TSV: date kind title path (newest first).
yay_report_list() {
  local dir f root; dir="$(_report_dir)"; root="$(yay_repo_root)"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$(yay_fm_get "$f" date 2>/dev/null || true)" "$(yay_fm_get "$f" kind 2>/dev/null || true)" \
      "$(yay_fm_get "$f" title 2>/dev/null || true)" "${f#"$root"/}"
  done | sort -r
}

# yay_report_check <report> [--max-words=N] -> "error: …" / "warn: …" lines; exit 1 on any error.
yay_report_check() {
  local q="" max="$YAY_REPORT_MAX_WORDS" a f kind out emoji rc
  for a in "$@"; do case "$a" in --max-words=*) max="${a#--max-words=}" ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh report check <report> [--max-words=N]"
  case "$max" in ''|*[!0-9]*) yay_die "--max-words must be a number" ;; esac
  f="$(_report_file "$q")"
  kind="$(yay_fm_get "$f" kind 2>/dev/null || true)"
  yay_in_list "$kind" "$(printf '%s\n' $YAY_REPORT_KINDS)" || { echo "error: front-matter kind '$kind' is not one of: $YAY_REPORT_KINDS"; return 1; }
  # Emoji and pictographs: the symbol blocks (U+2600-27BF, U+2B00-2BFF), U+1F000+, and the emoji variation selector.
  emoji="$(LC_ALL=C grep -nE "$(printf '\360\237|\342[\230-\236]|\342[\254\255]|\357\270\217')" "$f" | cut -d: -f1 | paste -sd, - || true)"
  out="$(_report_sections "$kind" | awk -v max="$max" -v title="$(yay_fm_get "$f" title 2>/dev/null || true)" \
    -v emoji="$emoji" -v kind="$kind" '
    function err(m) { print "error: " m; errs++ }
    function warn(m) { if (!(m in seenw)) { print "warn: " m; seenw[m] = 1 } }
    function words(s,   n, t) { t = s; gsub(/\*\*|\[|\]\([^)]*\)/, " ", t); n = split(t, _w, /[ \t]+/); if (_w[1] == "") n--; if (n > 0 && _w[n] == "") n--; return n }
    function sentences(s, where,   n, i, parts) {
      n = split(s, parts, /[.!?]+( |$)/)
      for (i = 1; i <= n; i++) if (words(parts[i]) > 30) warn("a sentence in " where " has " words(parts[i]) " words: split it (aim for under 20)")
    }
    function endpara() { if (para != "") { if (words(para) > 60) warn("a paragraph in " where() " has " words(para) " words: use 2-4 bullets"); para = "" } }
    function where() { return sec == "" ? "the top" : "'\''## " sec "'\''" }
    function plain(s, n,   t, w, k) {
      t = s
      gsub(/\]\([^)]*\)/, "]", t); gsub(/https?:\/\/[^ )]*/, "", t)
      if (t ~ /`/) err("code in " where() " (line " n "): say it in words, or move it to ## For developers")
      if (t ~ /[A-Za-z0-9_-]+\.(php|js|jsx|ts|tsx|css|scss|json|md|sh|py|html|ya?ml|xml|sql|lock)([^A-Za-z0-9]|$)/ || t ~ /[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]/)
        err("file or folder name in " where() " (line " n "): readers do not know the code; move it to ## For developers")
      if (t ~ /[A-Za-z_][A-Za-z0-9_]*\(\)/ || t ~ /::/ || t ~ /\$[A-Za-z_]/)
        err("code name in " where() " (line " n "): describe what it does instead")
      if (t ~ /(^|[^A-Za-z0-9])[a-z][a-z0-9]*_[a-z0-9_]+/ || t ~ /(^|[^A-Za-z])[a-z]+[A-Z][A-Za-z]*/)
        warn("line " n " looks like a code name (snake_case or camelCase): use plain words")
      if (t ~ /(^|[^A-Za-z])(R|P|B|BS|BL|UX)-[0-9]+/ || t ~ /(^|[ (])#[0-9]+/)
        warn("an internal id or PR number on line " n ": readers do not know it; say what it is, or move it to ## For developers")
      if (t ~ /->/) warn("'\''->'\'' on line " n ": write it as a sentence")
      k = tolower(" " t " "); gsub(/[^a-z0-9]+/, " ", k)
      hit = ""; for (i = 1; i in J; i++) if (index(k, " " J[i] " ")) hit = hit (hit == "" ? "" : ", ") J[i]
      if (hit != "") warn("jargon on line " n " (" hit "): say what it means for the user")
      bold += gsub(/\*\*[^*]+\*\*/, "&", t)
    }
    BEGIN {
      split("api endpoint endpoints hook hooks callback callbacks payload schema refactor refactored refactoring nonce ajax regex cron transient transients middleware singleton namespace async repo commit commits merged rebase deploy deployed pr ci pipeline backend frontend hpos sdk dto orm", J, " ")
    }
    NR == FNR { need[$0] = 1; needs[++nneed] = $0; next }
    FNR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    /<!--/ { err("template hint left on line " FNR ": write the section and delete the hint") ; next }
    /^```/ { if (!dev) err("code block in " where() ": move it to ## For developers"); fence = !fence; next }
    fence { if (dev) devwords += words($0); next }
    /^# / { h1++; if (h1 > 1) err("a second # title on line " FNR ": one title only"); next }
    /^###/ { err("sub-heading on line " FNR ": use only the ## sections of the template"); next }
    /^## / {
      endpara(); if (sec != "" && bullets[sec] > 6) warn("'\''## " sec "'\'' has " bullets[sec] " bullets: keep the 3-5 that matter")
      sec = substr($0, 4); sub(/[ \t]+$/, "", sec)
      if (dev) err("'\''## " sec "'\'' comes after ## For developers: that section must be last")
      if (sec == "For developers") { dev = 1; next }
      if (sec in have) err("'\''## " sec "'\'' appears twice")
      have[sec] = 1; order[++nsec] = sec
      if (!(sec in need)) warn("'\''## " sec "'\'' is not a " kind " section: fold it into one or drop it")
      next
    }
    /^[ \t]*$/ { endpara(); next }
    dev { devwords += words($0); next }
    {
      line = $0
      if (line ~ /<[A-Za-z\/!]/) err("HTML on line " FNR ": plain text only, the page has its own look")
      if (line ~ /!\[/) err("image on line " FNR ": share screenshots separately")
      if (line ~ /^[ \t]*\|/) err("table on line " FNR ": use a short list")
      filled[sec] = 1
      total += words(line)
      if (sec == "In one line") lead += words(line)
      plain(line, FNR)
      if (line ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]/) {
        endpara(); if (line !~ /^[ \t][ \t]/) bullets[sec]++; else warn("nested list on line " FNR ": keep lists flat")
        t = line; sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", t); sentences(t, where())
      } else { para = para " " line; sentences(line, where()) }
    }
    END {
      endpara(); if (sec != "" && bullets[sec] > 6) warn("'\''## " sec "'\'' has " bullets[sec] " bullets: keep the 3-5 that matter")
      if (title == "") err("front-matter has no title")
      else if (words(title) > 10) warn("the title has " words(title) " words: aim for under 8")
      if (h1 == 0) err("no # title line")
      for (i = 1; i <= nneed; i++) { s = needs[i]
        if (!(s in have)) err("no '\''## " s "'\'' section")
        else if (!(s in filled)) err("'\''## " s "'\'' is empty")
      }
      if (lead > 40) err("'\''## In one line'\'' has " lead " words: say what this is and what you want from the reader in under 40")
      if (order[1] != "" && order[1] != "In one line") warn("start with ## In one line, so the reader knows the point first")
      if (total > max) err("the report is " total " words (limit " max ", ## For developers not counted): cut it down")
      if (devwords > 200) warn("## For developers has " devwords " words: keep it under 200, link the PR or plan for the rest")
      if (bold > 4) warn(bold " bold phrases: bold only the one thing the reader must not miss")
      if (emoji != "") err("emoji or symbols on line " emoji ": plain words only")
      exit errs > 0
    }' - "$f")" && rc=0 || rc=$?
  [ -z "$out" ] || printf '%s\n' "$out"
  return "$rc"
}

# _report_md2html <file>: the plain markdown subset check allows, as HTML.
_report_md2html() {
  awk '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
    function inl(s,   out, m, a, b, url, txt) {
      s = esc(s); out = ""
      while (match(s, /\[[^]]+\]\(https?:\/\/[^) ]+\)/)) {
        m = substr(s, RSTART, RLENGTH); a = index(m, "](")
        txt = substr(m, 2, a - 2); url = substr(m, a + 2, length(m) - a - 2); gsub(/"/, "%22", url)
        out = out substr(s, 1, RSTART - 1) "<a href=\"" url "\">" txt "</a>"; s = substr(s, RSTART + RLENGTH)
      }
      s = out s; out = ""
      while (match(s, /\*\*[^*]+\*\*/)) { out = out substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>"; s = substr(s, RSTART + RLENGTH) }
      s = out s; out = ""
      while (match(s, /`[^`]+`/)) { out = out substr(s, 1, RSTART - 1) "<code>" substr(s, RSTART + 1, RLENGTH - 2) "</code>"; s = substr(s, RSTART + RLENGTH) }
      return out s
    }
    function close_block() {
      if (para != "") { print "<p>" inl(para) "</p>"; para = "" }
      if (list != "") { print "</" list ">"; list = "" }
    }
    function close_sec() { close_block(); if (lead) { print "</div>"; lead = 0 } }
    FNR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    /<!--/ { next }
    /^```/ { close_block(); if (fence) print (fstart ? "<pre><code>" : "") "</code></pre>"; fence = !fence; fstart = 1; next }
    fence { print (fstart ? "<pre><code>" : "") esc($0); fstart = 0; next }
    /^# / { next }
    /^## / {
      close_sec(); h = substr($0, 4); sub(/[ \t]+$/, "", h)
      if (h == "For developers") { print "<details>\n<summary>For developers</summary>"; dev = 1 }
      else if (h == "In one line") { print "<div class=\"lead\">"; lead = 1 }
      else print "<h2>" esc(h) "</h2>"
      next
    }
    /^[ \t]*$/ { close_block(); next }
    /^[ \t]*([-*+]|[0-9]+[.)])[ \t]/ {
      if (para != "") { print "<p>" inl(para) "</p>"; para = "" }
      want = ($0 ~ /^[ \t]*[0-9]/) ? "ol" : "ul"
      if (list != want) { if (list != "") print "</" list ">"; print "<" want ">"; list = want }
      t = $0; sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", t); print "<li>" inl(t) "</li>"; next
    }
    list != "" && /^[ \t]/ { t = $0; sub(/^[ \t]+/, "", t); print "<li>" inl(t) "</li>"; next }
    { if (list != "") { print "</" list ">"; list = "" } t = $0; sub(/^[ \t]+/, "", t); para = (para == "" ? t : para " " t) }
    END { close_sec(); if (fence) print "</code></pre>"; if (dev) print "</details>" }' "$1"
}

# _report_md2text <file>: plain text to paste into chat.
_report_md2text() {
  awk -v title="$2" -v by="$3" '
    function inl(s,   out, m, a) {
      out = ""
      while (match(s, /\[[^]]+\]\([^)]+\)/)) { m = substr(s, RSTART, RLENGTH); a = index(m, "](")
        out = out substr(s, 1, RSTART - 1) substr(m, 2, a - 2) " (" substr(m, a + 2, length(m) - a - 2) ")"; s = substr(s, RSTART + RLENGTH) }
      s = out s; gsub(/\*\*/, "", s); return s
    }
    BEGIN { print title; if (by != "") print by }
    FNR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    /<!--/ || /^# / { next }
    /^## / { h = substr($0, 4); sub(/[ \t]+$/, "", h); print ""; if (h != "In one line") print (h == "For developers" ? "---\nFor developers" : h); blank = 0; next }
    /^[ \t]*$/ { next }
    /^[ \t]*[*+-][ \t]/ { t = $0; sub(/^[ \t]*[*+-][ \t]+/, "", t); print "- " inl(t); next }
    { t = $0; sub(/^[ \t]+/, "", t); print inl(t) }' "$1"
}

# yay_report_render <report> [--text] [--max-words=N]: check, then write the page
# next to it (prints its path), or print the plain text. Refuses on check errors.
yay_report_render() {
  local q="" text="" a f title author date by html body max_arg=""
  for a in "$@"; do case "$a" in --text) text=1 ;; --max-words=*) max_arg="$a" ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh report render <report> [--text] [--max-words=N]"
  f="$(_report_file "$q")"
  # shellcheck disable=SC2086
  yay_report_check "$f" $max_arg >&2 || yay_die "fix the errors above first (yayh report check)"
  title="$(yay_fm_get "$f" title)"; author="$(yay_fm_get "$f" author 2>/dev/null || true)"; date="$(yay_fm_get "$f" date 2>/dev/null || true)"
  by="$author${author:+${date:+ · }}$date"
  if [ -n "$text" ]; then _report_md2text "$f" "$title" "$by"; return; fi
  html="${f%.md}.html"; body="$(mktemp)"
  _report_md2html "$f" > "$body"
  T="$title" BY="$by" awk -v body="$body" '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); gsub(/"/, "\\&quot;", s); return s }
    BEGIN { t = esc(ENVIRON["T"]); b = esc(ENVIRON["BY"]) }
    $0 == "{{body}}" { while ((getline l < body) > 0) print l; next }
    { while ((i = index($0, "{{title}}")) > 0)  $0 = substr($0, 1, i-1) t substr($0, i+9)
      while ((i = index($0, "{{byline}}")) > 0) $0 = substr($0, 1, i-1) b substr($0, i+10)
      print }' "$YAY_TEMPLATES/report/page.html" > "$html"
  rm -f "$body"
  printf '%s\n' "${html#"$(yay_repo_root)"/}"
}
