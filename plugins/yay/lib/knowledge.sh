# shellcheck shell=bash
# Knowledge docs: docs/knowledge/*.md and the yay:project block of CLAUDE.md.
# See reference/knowledge.md.

YAY_KNOWLEDGE_DIR="docs/knowledge"
YAY_PROJECT_BLOCK_MAX=90

# Files whose change can make the CLAUDE.md project block wrong (commands,
# layout, rules). Directory entries end with /.
yay_project_watch() {
  local main; main="$(yay_config_get plugin.mainFile 2>/dev/null || true)"
  printf '%s\n' .yay/config.json package.json composer.json scripts/ bin/ .github/workflows/ \
    phpunit.xml.dist phpunit.xml phpcs.xml phpcs.xml.dist .nvmrc .node-version ${main:+"$main"}
}

# Knowledge docs (not README.md), repo-relative.
yay_knowledge_docs() {
  local root d f; root="$(yay_repo_root)"; d="$root/$YAY_KNOWLEDGE_DIR"
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = README.md ] && continue
    printf '%s\n' "${f#"$root"/}"
  done
}

# `[a, b]` -> one item per line.
yay_fm_list() { printf '%s' "$1" | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'; }

# The project block's start marker attributes: ref=<sha> updated=<date>.
yay_project_attr() { # <attr>
  local root; root="$(yay_repo_root)"
  [ -f "$root/CLAUDE.md" ] || return 3
  sed -n "s/.*<!-- yay:project:start.* $1=\([^ ]*\).*-->.*/\1/p" "$root/CLAUDE.md" | sed -n 1p
}

# Ref a doc was last verified against ("" when never).
yay_knowledge_ref() { # <doc|CLAUDE.md>
  if [ "$1" = CLAUDE.md ]; then yay_project_attr ref; else yay_fm_get "$(yay_repo_root)/$1" updated_ref 2>/dev/null || true; fi
}

# Resolve --since: a ref, a tag, or a YYYY-MM-DD date.
yay_resolve_since() {
  local s="$1"
  if printf '%s' "$s" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    yay_git rev-list -1 --before="$s 00:00" HEAD 2>/dev/null || true
  else
    yay_git rev-parse --verify --quiet "$s^{commit}" 2>/dev/null || true
  fi
}

# Pathspecs excluded from staleness: docs, generated output.
_k_excludes() {
  local g
  printf '%s\n' ":(exclude)docs/" ":(exclude)CLAUDE.md" ":(exclude).yay/manifest.json"
  while IFS= read -r g; do [ -n "$g" ] && printf ':(exclude)%s\n' "$g"; done <<EOF
$(yay_config_get generatedPaths 2>/dev/null || true)
EOF
}

# yay_knowledge_stale [--since=<ref|tag|date>] -> TSV:
#   stale<TAB><doc><TAB><changed file>
#   fresh<TAB><doc>
#   never<TAB><doc>               (no updated_ref yet)
#   bad-ref<TAB><doc><TAB><ref>   (ref not in this repo's history)
#   uncovered<TAB><file>          (changed, but no doc covers it)
# Exit 1 when anything is stale/never/bad-ref.
yay_knowledge_stale() {
  local since="" a
  for a in "$@"; do case "$a" in --since=*) since="${a#--since=}";; *) yay_die "stale: unknown option $a";; esac; done
  local root sref="" doc ref covers c rc=0 oldest="" files ex
  root="$(yay_repo_root)"
  if [ -n "$since" ]; then sref="$(yay_resolve_since "$since")"; [ -n "$sref" ] || yay_die "cannot resolve --since=$since"; fi
  ex="$(_k_excludes)"

  _k_one() { # doc ref pathspec...
    local d="$1" r="$2"; shift 2
    if [ -z "$r" ]; then printf 'never\t%s\n' "$d"; rc=1; return; fi
    if ! yay_git rev-parse --verify --quiet "$r^{commit}" >/dev/null; then printf 'bad-ref\t%s\t%s\n' "$d" "$r"; rc=1; return; fi
    # shellcheck disable=SC2086
    files="$(yay_git diff --name-only "$r..HEAD" -- "$@" $ex 2>/dev/null)"
    if [ -n "$files" ]; then
      printf '%s\n' "$files" | sed "s|^|stale	$d	|"; rc=1
    else
      printf 'fresh\t%s\n' "$d"
    fi
    if [ -z "$oldest" ] || yay_git merge-base --is-ancestor "$r" "$oldest" 2>/dev/null; then oldest="$r"; fi
  }

  local IFS_SAVE="$IFS"
  # CLAUDE.md project block
  if [ -f "$root/CLAUDE.md" ]; then
    ref="${sref:-$(yay_knowledge_ref CLAUDE.md)}"
    IFS=$'\n'; _k_one CLAUDE.md "$ref" $(yay_project_watch); IFS="$IFS_SAVE"
  fi
  local all_covers=""
  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    ref="${sref:-$(yay_knowledge_ref "$doc")}"
    covers="$(yay_fm_list "$(yay_fm_get "$root/$doc" covers 2>/dev/null || true)")"
    [ -n "$covers" ] || covers="."
    all_covers="$all_covers
$covers"
    IFS=$'\n'; _k_one "$doc" "$ref" $covers; IFS="$IFS_SAVE"
  done <<EOF
$(yay_knowledge_docs)
EOF

  # Changes no doc covers (new areas), since the oldest ref.
  if [ -n "$oldest" ]; then
    local excl="" c2
    while IFS= read -r c2; do
      [ -n "$c2" ] || continue
      [ "$c2" = "." ] && { excl=""; all_covers="."; break; }
      excl="$excl
:(exclude)$c2"
    done <<EOF
$all_covers
EOF
    if [ "$all_covers" != "." ]; then
      IFS=$'\n'
      # shellcheck disable=SC2086
      yay_git diff --name-only "$oldest..HEAD" -- . $ex $excl $(yay_project_watch | sed 's/^/:(exclude)/') 2>/dev/null \
        | sed -n '1,50p' | sed 's/^/uncovered	/'
      IFS="$IFS_SAVE"
    fi
  fi
  return $rc
}

# yay_knowledge_stamp <doc|CLAUDE.md> [ref] -> record the ref the doc now matches.
yay_knowledge_stamp() {
  local doc="$1" ref="${2:-}" root today tmp
  root="$(yay_repo_root)"; today="$(yay_today)"
  [ -n "$ref" ] || ref="$(yay_git rev-parse --short HEAD)"
  yay_git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || yay_die "not a commit: $ref"
  if [ "$doc" = CLAUDE.md ]; then
    [ -f "$root/CLAUDE.md" ] && grep -q '<!-- yay:project:start' "$root/CLAUDE.md" || yay_die "CLAUDE.md has no yay:project block"
    tmp="$(mktemp)"
    sed "s|<!-- yay:project:start[^>]*-->|<!-- yay:project:start ref=$ref updated=$today -->|" "$root/CLAUDE.md" > "$tmp"
    cat "$tmp" > "$root/CLAUDE.md"; rm -f "$tmp"
  else
    [ -f "$root/$doc" ] || yay_die "no such doc: $doc"
    yay_fm_set "$root/$doc" updated "$today"
    yay_fm_set "$root/$doc" updated_ref "$ref"
  fi
  printf 'stamped\t%s\t%s\n' "$doc" "$ref"
}

# The project block text (between the markers, exclusive).
yay_project_block() {
  local root; root="$(yay_repo_root)"
  awk '/<!-- yay:project:end -->/{on=0} on{print} /<!-- yay:project:start/{on=1}' "$root/CLAUDE.md" 2>/dev/null
}

# Does a backticked token look like a repo path worth checking?
_k_pathlike() {
  local t="$1"
  case "$t" in
    *' '*|*'<'*|*'>'*|*'{'*|*'}'*|*'*'*|*'$'*|*'='*|*'('*|*'|'*|http*|/*|~*|.|..|-*) return 1 ;;
  esac
  printf '%s' "$t" | grep -Eq '^[A-Za-z0-9_.@-]+(/[A-Za-z0-9_.@-]+)*/?$' || return 1
  case "$t" in */*) return 0 ;; esac
  # bare names: only files with a known extension
  printf '%s' "$t" | grep -Eq '\.(php|js|jsx|ts|tsx|json|md|txt|xml|dist|ya?ml|sh|css|scss|lock|neon|ini)$'
}

# yay_knowledge_check [file...] -> "file:line: message" per problem; exit 1 if any.
yay_knowledge_check() {
  local root files f n=0 line ln tok target gen
  root="$(yay_repo_root)"
  if [ $# -gt 0 ]; then files="$*"; else files="CLAUDE.md
$(yay_knowledge_docs)"; fi
  gen="$(yay_config_get generatedPaths 2>/dev/null || true)"

  _k_issue() { printf '%s:%s: %s\n' "$1" "$2" "$3"; n=$((n+1)); }

  for f in $files; do
    [ -f "$root/$f" ] || { _k_issue "$f" 0 "missing"; continue; }
    if [ "$f" = CLAUDE.md ]; then
      grep -q '<!-- yay:project:start' "$root/CLAUDE.md" || { _k_issue CLAUDE.md 0 "no yay:project block"; continue; }
      local blk lines; blk="$(yay_project_block)"
      lines="$(printf '%s\n' "$blk" | grep -c .)"
      [ "$lines" -le "$YAY_PROJECT_BLOCK_MAX" ] || _k_issue CLAUDE.md 0 "project block has $lines non-empty lines; budget is $YAY_PROJECT_BLOCK_MAX. Move detail to docs/knowledge/ behind a 'read when' link"
      case "$blk" in *'has not been written yet'*) _k_issue CLAUDE.md 0 "project block is still the placeholder";; esac
      [ -n "$(yay_project_attr ref)" ] || _k_issue CLAUDE.md 0 "project block has no ref=; run 'yayh knowledge stamp CLAUDE.md'"
    else
      local k
      for k in area updated updated_ref covers; do
        yay_fm_get "$root/$f" "$k" >/dev/null 2>&1 || _k_issue "$f" 1 "front-matter is missing '$k'"
      done
      local r; r="$(yay_fm_get "$root/$f" updated_ref 2>/dev/null || true)"
      if [ -n "$r" ] && ! yay_git rev-parse --verify --quiet "$r^{commit}" >/dev/null; then _k_issue "$f" 1 "updated_ref '$r' is not a commit"; fi
      local c
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        [ -n "$(yay_git ls-files -- "$c" | sed -n 1p)" ] || _k_issue "$f" 1 "covers '$c' matches no tracked file"
      done <<EOF
$(yay_fm_list "$(yay_fm_get "$root/$f" covers 2>/dev/null || true)")
EOF
    fi

    # Paths in backticks and relative markdown links must exist.
    ln=0
    local infence=0
    while IFS= read -r line || [ -n "$line" ]; do
      ln=$((ln+1))
      case "$line" in '```'*) infence=$((1-infence)); continue;; esac
      [ "$infence" = 1 ] && continue
      while IFS= read -r tok; do
        [ -n "$tok" ] || continue
        tok="${tok%%:[0-9]*}"                      # file.php:42 -> file.php
        _k_pathlike "$tok" || continue
        local skip=0 g
        while IFS= read -r g; do [ -n "$g" ] && case "$tok" in "$g"*|"${g%/}") skip=1;; esac; done <<GEN
$gen
GEN
        [ "$skip" = 1 ] && continue
        case "$tok" in ../*|/*|~/*) continue;; esac   # outside the repo by construction
        case "$tok" in */*)
          # Only paths rooted in this repo: a first segment that isn't a
          # top-level entry here (e.g. WooCommerce's myaccount/orders.php
          # template path) refers to something outside it.
          [ -e "$root/${tok%%/*}" ] || continue
          [ -e "$root/${tok%/}" ] || yay_git check-ignore -q "$tok" 2>/dev/null || _k_issue "$f" "$ln" "path \`$tok\` does not exist"
          ;;
        *)
          [ -e "$root/$tok" ] || [ -n "$(yay_git ls-files -- "*/$tok" "$tok" | sed -n 1p)" ] || yay_git check-ignore -q "$tok" 2>/dev/null \
            || _k_issue "$f" "$ln" "file \`$tok\` is not in the repo"
          ;;
        esac
      done <<TOKS
$(printf '%s\n' "$line" | grep -oE '`[^`]+`' | tr -d '`' || true)
TOKS
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        case "$target" in http*|mailto:*) continue;; esac
        [ -e "$(dirname "$root/$f")/$target" ] || _k_issue "$f" "$ln" "link target '$target' does not exist"
      done <<LINKS
$(printf '%s\n' "$line" | grep -oE '\]\([^)#[:space:]]+' | sed 's/^](//' || true)
LINKS
    done < "$root/$f"
  done
  [ "$n" -eq 0 ]
}
