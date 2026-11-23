# shellcheck shell=bash
# Reports a developer shares with the lead or the team (/yay:report): an idea, a
# summary of what's done, a feature idea. They live in .yay/reports/, never in the
# repo. The agent writes markdown only; render owns the look, check owns the words.

YAY_REPORT_KINDS="idea done feature"
YAY_REPORT_LANGS="en vi"

_report_kind_ok() { yay_in_list "$1" "$(printf '%s\n' $YAY_REPORT_KINDS)" || yay_die "unknown report kind '$1' ($YAY_REPORT_KINDS)"; }
_report_lang_ok() { yay_in_list "$1" "$(printf '%s\n' $YAY_REPORT_LANGS)" || yay_die "unknown report language '$1' ($YAY_REPORT_LANGS)"; }

# _report_sections <kind> <lang>: the required ## sections, the first one being the one-line summary.
_report_sections() {
  case "$2:$1" in
    en:idea)    printf '%s\n' "In one line" "The problem" "My idea" "What I need from you" ;;
    en:done)    printf '%s\n' "In one line" "What's done" "What it means for users" "What's next" ;;
    en:feature) printf '%s\n' "In one line" "Who it's for" "What they'd see" "Why it's worth it" "Rough size" "Questions" ;;
    vi:idea)    printf '%s\n' "Tóm tắt" "Vấn đề" "Ý tưởng" "Điều tôi cần" ;;
    vi:done)    printf '%s\n' "Tóm tắt" "Đã xong" "Người dùng được gì" "Tiếp theo" ;;
    vi:feature) printf '%s\n' "Tóm tắt" "Dành cho ai" "Người dùng sẽ thấy gì" "Vì sao đáng làm" "Quy mô" "Câu hỏi" ;;
  esac
}

# _report_dev <lang>: the optional, last, folded section for technical detail.
_report_dev() { case "$1" in vi) echo "Dành cho lập trình viên" ;; *) echo "For developers" ;; esac; }

# _report_limits <lang> -> "words lead sentence paragraph". Vietnamese words are
# single syllables, so the same length of text counts about 1.5 times the words.
_report_limits() { case "$1" in vi) echo "450 60 45 90" ;; *) echo "300 40 30 60" ;; esac; }

# _report_lang_of <file>: the report's language (front-matter lang, default en).
_report_lang_of() { local l; l="$(yay_fm_get "$1" lang 2>/dev/null || true)"; printf '%s\n' "${l:-en}"; }

# _report_slug "<title>": yay_slugify after folding Vietnamese letters to ASCII.
_report_slug() {
  local t="$1" from to
  t="$(printf '%s' "$t" | LC_ALL=C sed -E "s/$(printf '\314[\200-\277]|\315[\200-\257]')//g")"   # combining marks (NFD)
  for from in "a:à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ|À|Á|Ạ|Ả|Ã|Â|Ầ|Ấ|Ậ|Ẩ|Ẫ|Ă|Ằ|Ắ|Ặ|Ẳ|Ẵ" \
              "e:è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ|È|É|Ẹ|Ẻ|Ẽ|Ê|Ề|Ế|Ệ|Ể|Ễ" "i:ì|í|ị|ỉ|ĩ|Ì|Í|Ị|Ỉ|Ĩ" \
              "o:ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ|Ò|Ó|Ọ|Ỏ|Õ|Ô|Ồ|Ố|Ộ|Ổ|Ỗ|Ơ|Ờ|Ớ|Ợ|Ở|Ỡ" \
              "u:ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ|Ù|Ú|Ụ|Ủ|Ũ|Ư|Ừ|Ứ|Ự|Ử|Ữ" "y:ỳ|ý|ỵ|ỷ|ỹ|Ỳ|Ý|Ỵ|Ỷ|Ỹ" "d:đ|Đ"; do
    to="${from%%:*}"; t="$(printf '%s' "$t" | LC_ALL=C sed -E "s/${from#*:}/$to/g")"
  done
  yay_slugify "$t"
}

_report_dir() { printf '%s/.yay/reports\n' "$(yay_repo_root)"; }

# yay_report_new <kind> "<title>" [--lang=en|vi] -> path of the new markdown file.
# The language defaults to report.lang in .yay/config.json (or .yay/local.json), then en.
yay_report_new() {
  local kind="" title="" lang="" a dir slug f author tpl
  for a in "$@"; do
    case "$a" in --lang=*) lang="${a#--lang=}" ;; -*) yay_die "unknown option $a" ;;
      *) if [ -z "$kind" ]; then kind="$a"; elif [ -z "$title" ]; then title="$a"; else yay_die "one title only (quote it)"; fi ;; esac
  done
  [ -n "$kind" ] && [ -n "$title" ] || yay_die "usage: yayh report new <idea|done|feature> \"<title>\" [--lang=en|vi]"
  [ -n "$lang" ] || lang="$(yay_config_get report.lang en 2>/dev/null || echo en)"
  _report_kind_ok "$kind"; _report_lang_ok "$lang"
  case "$title" in *$'\n'*) yay_die "title must be one line";; esac
  slug="$(_report_slug "$title")"; [ -n "$slug" ] || yay_die "title gives an empty slug"
  dir="$(_report_dir)"; mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  f="$dir/$(yay_today)-$slug.md"
  [ -e "$f" ] && yay_die "${f#"$(yay_repo_root)"/} already exists; open it or pick another title"
  tpl="$YAY_TEMPLATES/report/$kind.md"; [ "$lang" = en ] || tpl="$YAY_TEMPLATES/report/$lang/$kind.md"
  author="$(git -C "$(yay_repo_root)" config user.name 2>/dev/null || true)"
  awk -v t="$title" -v a="$author" -v d="$(yay_today)" '
    { while ((i = index($0, "{{title}}")) > 0)  $0 = substr($0, 1, i-1) t substr($0, i+9)
      while ((i = index($0, "{{author}}")) > 0) $0 = substr($0, 1, i-1) a substr($0, i+10)
      while ((i = index($0, "{{today}}")) > 0)  $0 = substr($0, 1, i-1) d substr($0, i+9)
      print }' "$tpl" > "$f"
  printf '%s\n' "${f#"$(yay_repo_root)"/}"
}

# _report_file <path|slug> -> absolute path of one report.
_report_file() {
  local q="$1" root dir hits n
  [ -f "$q" ] && { (cd "$(dirname "$q")" && printf '%s/%s\n' "$PWD" "$(basename "$q")"); return; }
  root="$(yay_repo_root)"
  [ -f "$root/$q" ] && { printf '%s/%s\n' "$root" "$q"; return; }
  dir="$(_report_dir)"
  hits="$(find "$dir" -maxdepth 1 -name "*$(_report_slug "$q")*.md" 2>/dev/null | sort)"
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
  local q="" max="" a f kind lang lim out emoji rc
  for a in "$@"; do case "$a" in --max-words=*) max="${a#--max-words=}" ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh report check <report> [--max-words=N]"
  f="$(_report_file "$q")"
  kind="$(yay_fm_get "$f" kind 2>/dev/null || true)"
  yay_in_list "$kind" "$(printf '%s\n' $YAY_REPORT_KINDS)" || { echo "error: front-matter kind '$kind' is not one of: $YAY_REPORT_KINDS"; return 1; }
  lang="$(_report_lang_of "$f")"
  yay_in_list "$lang" "$(printf '%s\n' $YAY_REPORT_LANGS)" || { echo "error: front-matter lang '$lang' is not one of: $YAY_REPORT_LANGS"; return 1; }
  lim="$(_report_limits "$lang")"
  [ -n "$max" ] || max="${lim%% *}"
  case "$max" in *[!0-9]*) yay_die "--max-words must be a number" ;; esac
  # Emoji and pictographs: the symbol blocks (U+2600-27BF, U+2B00-2BFF), U+1F000+, and the emoji variation selector.
  emoji="$(LC_ALL=C grep -nE "$(printf '\360\237|\342[\230-\236]|\342[\254\255]|\357\270\217')" "$f" | cut -d: -f1 | paste -sd, - || true)"
  # shellcheck disable=SC2086
  set -- $lim
  out="$(_report_sections "$kind" "$lang" | awk -v max="$max" -v leadmax="$2" -v sentmax="$3" -v paramax="$4" \
    -v title="$(yay_fm_get "$f" title 2>/dev/null || true)" -v emoji="$emoji" -v kind="$kind" -v devh="$(_report_dev "$lang")" '
    function err(m) { print "error: " m; errs++ }
    function warn(m) { if (!(m in seenw)) { print "warn: " m; seenw[m] = 1 } }
    function words(s,   n, t) { t = s; gsub(/\*\*|\[|\]\([^)]*\)/, " ", t); n = split(t, _w, /[ \t]+/); if (_w[1] == "") n--; if (n > 0 && _w[n] == "") n--; return n }
    function sentences(s, where,   n, i, parts) {
      n = split(s, parts, /[.!?]+( |$)/)
      for (i = 1; i <= n; i++) if (words(parts[i]) > sentmax) warn("a sentence in " where " has " words(parts[i]) " words: split it")
    }
    function endpara() { if (para != "") { if (words(para) > paramax) warn("a paragraph in " where() " has " words(para) " words: use 2-4 bullets"); para = "" } }
    function where() { return sec == "" ? "the top" : "'\''## " sec "'\''" }
    function plain(s, n,   t, w, k) {
      t = s
      gsub(/\]\([^)]*\)/, "]", t); gsub(/https?:\/\/[^ )]*/, "", t)
      if (t ~ /`/) err("code in " where() " (line " n "): say it in words, or move it to ## " devh)
      if (t ~ /[A-Za-z0-9_-]+\.(php|js|jsx|ts|tsx|css|scss|json|md|sh|py|html|ya?ml|xml|sql|lock)([^A-Za-z0-9]|$)/ || t ~ /[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]/)
        err("file or folder name in " where() " (line " n "): readers do not know the code; move it to ## " devh)
      if (t ~ /[A-Za-z_][A-Za-z0-9_]*\(\)/ || t ~ /::/ || t ~ /\$[A-Za-z_]/)
        err("code name in " where() " (line " n "): describe what it does instead")
      if (t ~ /(^|[^A-Za-z0-9])[a-z][a-z0-9]*_[a-z0-9_]+/ || t ~ /(^|[^A-Za-z])[a-z]+[A-Z][A-Za-z]*/)
        warn("line " n " looks like a code name (snake_case or camelCase): use plain words")
      if (t ~ /(^|[^A-Za-z])(R|P|B|BS|BL|UX)-[0-9]+/ || t ~ /(^|[ (])#[0-9]+/)
        warn("an internal id or PR number on line " n ": readers do not know it; say what it is, or move it to ## " devh)
      if (t ~ /->/) warn("'\''->'\'' on line " n ": write it as a sentence")
      k = tolower(" " t " "); gsub(/[^a-z0-9]+/, " ", k)
      hit = ""; for (i = 1; i in J; i++) if (index(k, " " J[i] " ")) hit = hit (hit == "" ? "" : ", ") J[i]
      if (hit != "") warn("jargon on line " n " (" hit "): say what it means for the user")
      bold += gsub(/\*\*[^*]+\*\*/, "&", t)
    }
    BEGIN {
      split("api endpoint endpoints hook hooks callback callbacks payload schema refactor refactored refactoring nonce ajax regex cron transient transients middleware singleton namespace async repo commit commits merged rebase deploy deployed pr ci pipeline backend frontend hpos sdk dto orm push debug database server", J, " ")
    }
    NR == FNR { need[$0] = 1; needs[++nneed] = $0; if (nneed == 1) leadh = $0; next }
    FNR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    /<!--/ { err("template hint left on line " FNR ": write the section and delete the hint") ; next }
    /^```/ { if (!dev) err("code block in " where() ": move it to ## " devh); fence = !fence; next }
    fence { if (dev) devwords += words($0); next }
    /^# / { h1++; if (h1 > 1) err("a second # title on line " FNR ": one title only"); next }
    /^###/ { err("sub-heading on line " FNR ": use only the ## sections of the template"); next }
    /^## / {
      endpara(); if (sec != "" && bullets[sec] > 6) warn("'\''## " sec "'\'' has " bullets[sec] " bullets: keep the 3-5 that matter")
      sec = substr($0, 4); sub(/[ \t]+$/, "", sec)
      if (dev) err("'\''## " sec "'\'' comes after ## " devh ": that section must be last")
      if (sec == devh) { dev = 1; next }
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
      if (sec == leadh) lead += words(line)
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
      if (lead > leadmax) err("'\''## " leadh "'\'' has " lead " words: say what this is and what you want from the reader in under " leadmax)
      if (order[1] != "" && order[1] != leadh) warn("start with ## " leadh ", so the reader knows the point first")
      if (total > max) err("the report is " total " words (limit " max ", ## " devh " not counted): cut it down")
      if (devwords > 200) warn("## " devh " has " devwords " words: keep it under 200, link the PR or plan for the rest")
      if (bold > 4) warn(bold " bold phrases: bold only the one thing the reader must not miss")
      if (emoji != "") err("emoji or symbols on line " emoji ": plain words only")
      exit errs > 0
    }' - "$f")" && rc=0 || rc=$?
  [ -z "$out" ] || printf '%s\n' "$out"
  return "$rc"
}

# _report_md2html <file>: the plain markdown subset check allows, as HTML.
_report_md2html() {
  awk -v leadh="$2" -v devh="$3" '
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
      if (h == devh) { print "<details>\n<summary>" esc(devh) "</summary>"; dev = 1 }
      else if (h == leadh) { print "<div class=\"lead\">"; lead = 1 }
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
  awk -v title="$2" -v by="$3" -v leadh="$4" -v devh="$5" '
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
    /^## / { h = substr($0, 4); sub(/[ \t]+$/, "", h); print ""; if (h != leadh) print (h == devh ? "---\n" devh : h); next }
    /^[ \t]*$/ { next }
    /^[ \t]*[*+-][ \t]/ { t = $0; sub(/^[ \t]*[*+-][ \t]+/, "", t); print "- " inl(t); next }
    { t = $0; sub(/^[ \t]+/, "", t); print inl(t) }' "$1"
}

# yay_report_render <report> [--text] [--max-words=N]: check, then write the page
# next to it (prints its path), or print the plain text. Refuses on check errors.
yay_report_render() {
  local q="" text="" a f title author date by html body max_arg="" lang leadh devh
  for a in "$@"; do case "$a" in --text) text=1 ;; --max-words=*) max_arg="$a" ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh report render <report> [--text] [--max-words=N]"
  f="$(_report_file "$q")"
  # shellcheck disable=SC2086
  yay_report_check "$f" $max_arg >&2 || yay_die "fix the errors above first (yayh report check)"
  title="$(yay_fm_get "$f" title)"; author="$(yay_fm_get "$f" author 2>/dev/null || true)"; date="$(yay_fm_get "$f" date 2>/dev/null || true)"
  by="$author${author:+${date:+ · }}$date"
  lang="$(_report_lang_of "$f")"; leadh="$(_report_sections "$(yay_fm_get "$f" kind)" "$lang" | sed -n 1p)"; devh="$(_report_dev "$lang")"
  if [ -n "$text" ]; then _report_md2text "$f" "$title" "$by" "$leadh" "$devh"; return; fi
  html="${f%.md}.html"; body="$(mktemp)"
  _report_md2html "$f" "$leadh" "$devh" > "$body"
  T="$title" BY="$by" L="$lang" awk -v body="$body" '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); gsub(/"/, "\\&quot;", s); return s }
    BEGIN { t = esc(ENVIRON["T"]); b = esc(ENVIRON["BY"]); l = ENVIRON["L"] }
    $0 == "{{body}}" { while ((getline l < body) > 0) print l; next }
    { while ((i = index($0, "{{title}}")) > 0)  $0 = substr($0, 1, i-1) t substr($0, i+9)
      while ((i = index($0, "{{byline}}")) > 0) $0 = substr($0, 1, i-1) b substr($0, i+10)
      while ((i = index($0, "{{lang}}")) > 0)   $0 = substr($0, 1, i-1) l substr($0, i+8)
      print }' "$YAY_TEMPLATES/report/page.html" > "$html"
  rm -f "$body"
  printf '%s\n' "${html#"$(yay_repo_root)"/}"
}
