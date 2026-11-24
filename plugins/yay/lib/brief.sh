# shellcheck shell=bash
# Item briefs (/yay:roadmap --brief): one plain-language page per roadmap item that says
# what it is, for developers and for Claude. docs/briefs/R-<n>-<slug>.md, front-matter
# `item: R-<n>` (never `id:`, so R-<n> keeps resolving to the roadmap). Not the release
# brief (yayh roadmap brief <x.y.z>). Reuses the report checker and page (lib/report.sh).

_brief_sections() {
  case "$1" in
    vi) printf '%s\n' "Tóm tắt" "Vấn đề" "Người dùng thấy gì" "Quy tắc và trường hợp đặc biệt" "Ngoài phạm vi" "Xong khi" "Câu hỏi mở" ;;
    *)  printf '%s\n' "In one line" "Problem" "What the user sees" "Rules and edge cases" "Out of scope" "Done when" "Open questions" ;;
  esac
}
# _brief_heading <lang> <n>: the n-th section heading.
_brief_heading() { _brief_sections "$1" | sed -n "${2}p"; }
_brief_limits() { case "$1" in vi) echo "1000 60 45 90" ;; *) echo "700 40 30 60" ;; esac; }

_brief_item_ok() { printf '%s' "$1" | grep -Eq '^R-[0-9]+$' || yay_die "expected a roadmap item id like R-12, got '$1'"; }

# yay_brief_path <R-n> -> the brief's repo-relative path; exit 3 when the item has none.
yay_brief_path() {
  local id="${1:-}" root f
  _brief_item_ok "$id"
  root="$(yay_repo_root)"
  for f in "$root"/docs/briefs/*.md; do
    [ -f "$f" ] || continue
    [ "$(yay_fm_get "$f" item 2>/dev/null || true)" = "$id" ] && { printf '%s\n' "${f#"$root"/}"; return 0; }
  done
  return 3
}

# _brief_file <R-n|path> -> absolute path.
_brief_file() {
  local q="$1" root rel
  root="$(yay_repo_root)"
  [ -f "$q" ] && { (cd "$(dirname "$q")" && printf '%s/%s\n' "$PWD" "$(basename "$q")"); return; }
  [ -f "$root/$q" ] && { printf '%s/%s\n' "$root" "$q"; return; }
  rel="$(yay_brief_path "$q")" || yay_die "$q has no brief (yayh brief new $q)"
  printf '%s/%s\n' "$root" "$rel"
}

# yay_brief_new <R-n> [--lang=en|vi] -> creates docs/briefs/R-<n>-<slug>.md from the template,
# links it from the item (- brief:) and prints the path.
yay_brief_new() {
  local id="" lang="" a title root rel author tpl
  for a in "$@"; do case "$a" in --lang=*) lang="${a#--lang=}" ;; -*) yay_die "unknown option $a" ;; *) id="$a" ;; esac; done
  [ -n "$id" ] || yay_die "usage: yayh brief new <R-n> [--lang=en|vi]"
  _brief_item_ok "$id"
  [ -n "$lang" ] || lang="$(yay_config_get language en 2>/dev/null || echo en)"
  _report_lang_ok "$lang"
  # Read the whole list: an awk `exit` here SIGPIPEs the list under pipefail.
  title="$(yay_roadmap_list | awk -F '\t' -v id="$id" '$1 == id && t == "" { t = $5 } END { print t }')"
  [ -n "$title" ] || yay_die "no roadmap item $id (yayh roadmap add first)"
  if rel="$(yay_brief_path "$id")"; then yay_die "$id already has a brief: $rel"; fi
  root="$(yay_repo_root)"
  rel="docs/briefs/$id-$(_report_slug "$title").md"
  mkdir -p "$root/docs/briefs"
  author="$(git -C "$root" config user.name 2>/dev/null || true)"
  tpl="$YAY_TEMPLATES/brief/brief.md"; [ "$lang" = en ] || tpl="$YAY_TEMPLATES/brief/$lang/brief.md"
  awk -v i="$id" -v t="$title" -v a="$author" -v d="$(yay_today)" '
    { while ((k = index($0, "{{item}}")) > 0)   $0 = substr($0, 1, k-1) i substr($0, k+8)
      while ((k = index($0, "{{title}}")) > 0)  $0 = substr($0, 1, k-1) t substr($0, k+9)
      while ((k = index($0, "{{author}}")) > 0) $0 = substr($0, 1, k-1) a substr($0, k+10)
      while ((k = index($0, "{{today}}")) > 0)  $0 = substr($0, 1, k-1) d substr($0, k+9)
      print }' "$tpl" > "$root/$rel"
  yay_roadmap_set "$id" brief "$rel" >/dev/null
  printf '%s\n' "$rel"
}

# yay_brief_list -> TSV: item status title path.
yay_brief_list() {
  local root f; root="$(yay_repo_root)"
  for f in "$root"/docs/briefs/*.md; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$(yay_fm_get "$f" item 2>/dev/null || true)" "$(yay_fm_get "$f" status 2>/dev/null || true)" \
      "$(yay_fm_get "$f" title 2>/dev/null || true)" "${f#"$root"/}"
  done
}

# yay_brief_check <R-n|path> [--max-words=N] -> "error: …" / "warn: …" lines; exit 1 on any error.
yay_brief_check() {
  local q="" max="" a f lang lim item st
  for a in "$@"; do case "$a" in --max-words=*) max="${a#--max-words=}" ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh brief check <R-n|path> [--max-words=N]"
  f="$(_brief_file "$q")"
  item="$(yay_fm_get "$f" item 2>/dev/null || true)"
  printf '%s' "$item" | grep -Eq '^R-[0-9]+$' || { echo "error: front-matter item '$item' is not a roadmap item id"; return 1; }
  st="$(yay_fm_get "$f" status 2>/dev/null || true)"
  case "$st" in draft|ready) ;; *) echo "error: front-matter status '$st' is not draft or ready"; return 1 ;; esac
  lang="$(_report_lang_of "$f")"
  yay_in_list "$lang" "$(printf '%s\n' $YAY_REPORT_LANGS)" || { echo "error: front-matter lang '$lang' is not one of: $YAY_REPORT_LANGS"; return 1; }
  lim="$(_brief_limits "$lang")"
  [ -n "$max" ] || max="${lim%% *}"
  case "$max" in *[!0-9]*) yay_die "--max-words must be a number" ;; esac
  _plain_check "$f" brief "$max" "$lim" "$(_report_dev "$lang")" 0 "$(_brief_heading "$lang" 3)" 12 8 \
    "$(_brief_heading "$lang" 6)" "$(_brief_heading "$lang" 5)" < <(_brief_sections "$lang")
}

# yay_brief_checks <R-n|path> -> how many - [ ] lines its Done when has (0 when none).
yay_brief_checks() {
  local f lang; f="$(_brief_file "$1")"; lang="$(_report_lang_of "$f")"
  awk -v h="## $(_brief_heading "$lang" 6)" '$0 == h { on = 1; next } /^## / { on = 0 } on && /^[ \t]*[-*] \[[ xX]\][ \t]/ { n++ } END { print n + 0 }' "$f"
}

# yay_brief_render <R-n|path> [--text]: check, then the plain page in .yay/briefs/R-<n>.html
# (gitignored; prints its path), or paste-ready text. Refuses on check errors.
yay_brief_render() {
  local q="" text="" a f lang root html
  for a in "$@"; do case "$a" in --text) text=1 ;; *) q="$a" ;; esac; done
  [ -n "$q" ] || yay_die "usage: yayh brief render <R-n|path> [--text]"
  f="$(_brief_file "$q")"
  yay_brief_check "$f" >&2 || yay_die "fix the errors above first (yayh brief check)"
  lang="$(_report_lang_of "$f")"
  if [ -n "$text" ]; then _plain_render "$f" "$lang" "$(_brief_heading "$lang" 1)" "$(_report_dev "$lang")"; return; fi
  root="$(yay_repo_root)"; mkdir -p "$root/.yay/briefs"
  [ -f "$root/.yay/briefs/.gitignore" ] || printf '*\n' > "$root/.yay/briefs/.gitignore"
  html="$root/.yay/briefs/$(yay_fm_get "$f" item).html"
  _plain_render "$f" "$lang" "$(_brief_heading "$lang" 1)" "$(_report_dev "$lang")" "$html"
  printf '%s\n' "${html#"$root"/}"
}
