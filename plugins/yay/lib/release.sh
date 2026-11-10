# shellcheck shell=bash
# Changelog, versions, and zip checks for /yay:changelog, /yay:build, /yay:release.

command -v perl >/dev/null 2>&1 || true   # perl does the regex rewrites (macOS and Linux ship it)

# ---------- versions ----------

# Each versionFiles entry as "file<TAB>pattern".
_vfiles() {
  local line f p
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    f="$(printf '%s' "$line" | _json_field file)"; p="$(printf '%s' "$line" | _json_field pattern)"
    printf '%s\t%s\n' "$f" "$p"
  done <<EOF
$(yay_config_get versionFiles 2>/dev/null || true)
EOF
}
# Read one string field from a compact JSON object on stdin (no nesting).
_json_field() {
  local tmp; tmp="$(mktemp)"; cat > "$tmp"
  yay_json_get "$tmp" "$1"; local rc=$?; rm -f "$tmp"; return $rc
}

# yay_version_list -> "file<TAB>version" for every versionFiles match.
yay_version_list() {
  local root f p; root="$(yay_repo_root)"
  _vfiles | while IFS="$(printf '\t')" read -r f p; do
    [ -f "$root/$f" ] || { printf '%s\t%s\n' "$f" "(missing file)"; continue; }
    RE="$p" perl -ne 'BEGIN{$re=$ENV{RE}} if (/$re/) { print "$1\n"; $n++ } END{ print "(no match)\n" unless $n }' "$root/$f" \
      | sed "s|^|$f	|"
  done
}

yay_version_current() {
  local all v; all="$(yay_version_list)"; v="$(printf '%s\n' "$all" | sed -n '1s/^[^	]*	//p')"
  case "$v" in ""|"("*) yay_die "can't read the version from versionFiles in .yay/config.json";; esac
  printf '%s\n' "$v"
}

# yay_version_check -> exit 1 (with the list) when versionFiles disagree or miss.
yay_version_check() {
  local list n; list="$(yay_version_list)"
  [ -n "$list" ] || { echo "no versionFiles configured" >&2; return 1; }
  n="$(printf '%s\n' "$list" | cut -f2 | sort -u | grep -c .)"
  local bad=0; case "$(printf '%s\n' "$list" | cut -f2)" in "("*|*"
("*) bad=1;; esac
  if [ "$n" -ne 1 ] || [ "$bad" = 1 ]; then
    echo "version files disagree:" >&2; printf '%s\n' "$list" >&2; return 1
  fi
  printf '%s\n' "$list" | sed -n 1p | cut -f2
}

# yay_version_set <x.y.z> -> rewrite group 1 of every versionFiles pattern.
yay_version_set() {
  local new="$1" root f p n
  printf '%s' "$new" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$' || yay_die "not a version: $new"
  root="$(yay_repo_root)"
  _vfiles | while IFS="$(printf '\t')" read -r f p; do
    [ -f "$root/$f" ] || yay_die "versionFiles: $f does not exist"
    n="$(RE="$p" NEW="$new" perl -i -pe 'BEGIN{$re=$ENV{RE}; $new=$ENV{NEW}} if (/$re/) { substr($_, $-[1], $+[1]-$-[1]) = $new; $n++ } END { print STDERR "$n\n" }' "$root/$f" 2>&1 >/dev/null)"
    [ "${n:-0}" -gt 0 ] || yay_die "versionFiles: pattern matched nothing in $f"
    printf 'set\t%s\t%s\t(%s)\n' "$f" "$new" "$n"
  done
}

# yay_tested_set wp=<x.y> wc=<x.y> -> readme "Tested up to", header "WC tested up to", config tested.*
yay_tested_set() {
  local root main readme kv wp="" wc=""
  for kv in "$@"; do case "$kv" in wp=*) wp="${kv#wp=}";; wc=*) wc="${kv#wc=}";; *) yay_die "usage: yayh version tested wp=X.Y [wc=X.Y]";; esac; done
  root="$(yay_repo_root)"; main="$(yay_config_get plugin.mainFile)"; readme="$(yay_config_get changelog.readme)"
  if [ -n "$wp" ]; then
    [ -f "$root/$readme" ] && V="$wp" perl -i -pe 's/^(Tested up to:[ \t]*)\S+/$1$ENV{V}/' "$root/$readme"
    yay_json_set "$(yay_config_file)" tested.wp "$wp"; printf 'tested\twp\t%s\n' "$wp"
  fi
  if [ -n "$wc" ]; then
    V="$wc" perl -i -pe 's/^([ \t*#@]*WC tested up to:[ \t]*)\S+/$1$ENV{V}/' "$root/$main"
    yay_json_set "$(yay_config_file)" tested.wc "$wc"; printf 'tested\twc\t%s\n' "$wc"
  fi
}

# yay_json_set <file> <dotted.path> <string>
yay_json_set() {
  local f="$1" path="$2" val="$3" tmp; tmp="$(mktemp)"
  case "$(yay_json_engine)" in
    jq) jq --arg p "$path" --arg v "$val" 'setpath($p | split("."); $v)' "$f" > "$tmp" ;;
    node) node -e 'const fs=require("fs");const [f,p,v]=process.argv.slice(1);const j=JSON.parse(fs.readFileSync(f,"utf8"));let o=j;const ks=p.split(".");ks.slice(0,-1).forEach(k=>{o[k]=o[k]&&typeof o[k]==="object"?o[k]:{};o=o[k]});o[ks[ks.length-1]]=v;process.stdout.write(JSON.stringify(j,null,2)+"\n")' "$f" "$path" "$val" > "$tmp" ;;
    php) php -r '[$_,$f,$p,$v]=$argv;$j=json_decode(file_get_contents($f),true);$o=&$j;foreach(explode(".",$p) as $k){if(!isset($o[$k])||!is_array($o[$k]))$o[$k]=$o[$k]??[];$o=&$o[$k];}$o=$v;echo json_encode($j,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$f" "$path" "$val" > "$tmp" ;;
    python3) python3 -I -c 'import json,sys;f,p,v=sys.argv[1:];j=json.load(open(f));o=j;ks=p.split(".")
for k in ks[:-1]: o=o.setdefault(k,{})
o[ks[-1]]=v;print(json.dumps(j,indent=2))' "$f" "$path" "$val" > "$tmp" ;;
  esac
  cat "$tmp" > "$f"; rm -f "$tmp"
}

# ---------- changelog ----------

# yay_changelog_collect [--since=<ref>] [--to=<ref>]
# TSV: sha type scope breaking subject pr fixes roadmap plan
yay_changelog_collect() {
  local since="" to="HEAD" a
  for a in "$@"; do case "$a" in --since=*) since="${a#--since=}";; --to=*) to="${a#--to=}";; *) yay_die "collect: unknown option $a";; esac; done
  [ -n "$since" ] || since="$(yay_changelog_baseline | cut -f1)"
  local range="$since..$to"
  yay_git log --no-merges --reverse \
    --format='%h%x1f%s%x1f%(trailers:key=Fixes,valueonly,separator=%x2C)%x1f%(trailers:key=Roadmap,valueonly,separator=%x2C)%x1f%(trailers:key=Plan,valueonly,separator=%x2C)%x1f%b%x1e' \
    "$range" 2>/dev/null \
  | awk 'BEGIN{RS="\036"; FS="\037"; OFS="\t"}
    NF>=2 {
      sha=$1; gsub(/^\n+/, "", sha); subj=$2; type="other"; scope=""; brk=0; pr=""
      if (match(subj, /^[a-z]+(\([a-z0-9-]+\))?!?: /)) {
        head=substr(subj, 1, RLENGTH-2); subj=substr(subj, RLENGTH+1)
        if (head ~ /!$/) { brk=1; sub(/!$/, "", head) }
        if (match(head, /\(.*\)/)) { scope=substr(head, RSTART+1, RLENGTH-2); type=substr(head, 1, RSTART-1) } else type=head
      }
      if ($6 ~ /BREAKING[ -]CHANGE/) brk=1
      if (match(subj, / \(#[0-9]+\)$/)) { pr=substr(subj, RSTART+3, RLENGTH-4); subj=substr(subj, 1, RSTART-1) }
      gsub(/\t/, " ", subj); gsub(/[ \n]+$/, "", $3); gsub(/[ \n]+$/, "", $4); gsub(/[ \n]+$/, "", $5)
      print sha, type, scope, brk, subj, pr, $3, $4, $5
    }'
}

# yay_changelog_baseline -> where the next release's changes start, as
# "<ref><TAB><how>":
#   tag               the last release tag
#   release-commit    no tag, but a "chore(release): <current>" commit exists
#   first-appearance  neither: the commit where the current version first
#                     appeared. Ambiguous (never released? released untagged?),
#                     so /yay:release must ask the user.
yay_changelog_baseline() {
  local t cur f c
  t="$(yay_last_tag)"
  if [ -n "$t" ]; then printf '%s\ttag\n' "$t"; return 0; fi
  cur="$(yay_version_current)"
  c="$(yay_git log -1 --format=%h -E --grep="^chore\(release\): v?${cur}( |\$)" 2>/dev/null || true)"
  if [ -n "$c" ]; then printf '%s\trelease-commit\n' "$c"; return 0; fi
  f="$(_vfiles | sed -n '1s/\t.*//p')"
  c="$(yay_git log --format=%h -S"$cur" -- "$f" 2>/dev/null | sed -n '$p')"
  [ -n "$c" ] || yay_die "no release tag and no commit introduces version $cur in $f; pass --since"
  printf '%s\tfirst-appearance\n' "$c"
}

# yay_changelog_suggest [--since=<ref>] -> major|minor|patch|none from commit types.
yay_changelog_suggest() {
  local c; c="$(yay_changelog_collect "$@")"
  [ -n "$c" ] || { echo none; return; }
  if printf '%s\n' "$c" | awk -F'\t' '$4==1{f=1} END{exit !f}'; then echo major
  elif printf '%s\n' "$c" | awk -F'\t' '$2=="feat"{f=1} END{exit !f}'; then echo minor
  elif printf '%s\n' "$c" | awk -F'\t' '$2=="fix"||$2=="perf"||$2=="refactor"{f=1} END{exit !f}'; then echo patch
  else echo none; fi
}

# yay_changelog_style -> the readme's existing conventions:
#   heading<TAB>= {version} - {date} =    bullet<TAB>*    labels<TAB>Fix, New    entries<TAB>N
yay_changelog_style() {
  local root readme; root="$(yay_repo_root)"; readme="$root/$(yay_config_get changelog.readme)"
  [ -f "$readme" ] || { printf 'heading\t= {version} - {date} =\nbullet\t*\nlabels\t\nentries\t0\n'; return; }
  awk '
    /^== *Changelog *==/ { on=1; next }
    on && /^== / { on=0 }
    on && /^= .* =[[:space:]]*$/ {
      n++
      if (!h) { h=$0; sub(/[[:space:]]+$/, "", h)
        if (match(h, /[0-9]+\.[0-9]+(\.[0-9]+)?([-.][0-9A-Za-z.]+)?/)) h=substr(h,1,RSTART-1) "{version}" substr(h,RSTART+RLENGTH)
        if (match(h, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) h=substr(h,1,RSTART-1) "{date}" substr(h,RSTART+RLENGTH)
      }
      next }
    on && n>0 && n<=5 && /^[*-] / {
      if (!b) b=substr($0,1,1)
      if (match($0, /^[*-] [A-Z][A-Za-z]+:/)) { l=substr($0, 3, RLENGTH-3); if (!(l in seen)) { seen[l]=1; labels=labels (labels?", ":"") l } }
    }
    END {
      if (!h) h="= {version} - {date} ="
      if (!b) b="*"
      printf "heading\t%s\nbullet\t%s\nlabels\t%s\nentries\t%d\n", h, b, labels, n
    }' "$readme"
}

# yay_changelog_write <version> <bullets-file> [--date=YYYY-MM-DD] [--replace]
# Insert "<heading>\n<bullets>\n" right after "== Changelog ==".
yay_changelog_write() {
  local ver="$1" bullets="$2"; shift 2 || true
  local date replace=0 a root readme heading tmp
  date="$(yay_today)"
  for a in "$@"; do case "$a" in --date=*) date="${a#--date=}";; --replace) replace=1;; *) yay_die "write: unknown option $a";; esac; done
  [ -f "$bullets" ] || yay_die "no bullets file: $bullets"
  root="$(yay_repo_root)"; readme="$root/$(yay_config_get changelog.readme)"
  [ -f "$readme" ] || yay_die "no $(yay_config_get changelog.readme)"
  grep -q '^== *Changelog *==' "$readme" || yay_die "$(basename "$readme") has no '== Changelog ==' section"
  heading="$(yay_changelog_style | sed -n 's/^heading	//p')"
  heading="$(yay_fill "$heading" "version=$ver" "date=$date")"
  if grep -Fqx -- "$heading" "$readme" || awk -v v="$ver" '/^= .* =/ && index($0, " " v " ") {f=1} END{exit !f}' "$readme"; then
    [ "$replace" = 1 ] || yay_die "the changelog already has an entry for $ver (pass --replace)"
    tmp="$(mktemp)"
    awk -v v="$ver" '
      /^= .* =/ { skip = index($0, " " v " ") ? 1 : 0 }
      /^== / && !/Changelog/ { skip=0 }
      !skip { print }' "$readme" > "$tmp"; cat "$tmp" > "$readme"; rm -f "$tmp"
  fi
  tmp="$(mktemp)"
  awk -v h="$heading" -v bf="$bullets" '
    { print }
    /^== *Changelog *==/ && !done {
      getline nxt; print ""; print h
      while ((getline l < bf) > 0) if (l != "") print l
      print ""
      if (nxt != "") print nxt
      done=1 }' "$readme" > "$tmp"
  cat "$tmp" > "$readme"; rm -f "$tmp"
  printf 'wrote\t%s\t%s\n' "$(yay_config_get changelog.readme)" "$heading"
}

# yay_changelog_entry <version> -> the bullets of that version's readme entry.
yay_changelog_entry() {
  local root readme; root="$(yay_repo_root)"; readme="$root/$(yay_config_get changelog.readme)"
  awk -v v="$1" '/^= .* =/ { on = index($0, " " v " ") ? 1 : 0; next } /^==/ { on=0 } on && /[^[:space:]]/ { print }' "$readme"
}

# ---------- build ----------

# yay_zip_path edition=<e> version=<v> -> newest zip matching package.output.
yay_zip_path() {
  local glob root kv edition=""; root="$(yay_repo_root)"
  for kv in "$@"; do case "$kv" in edition=*) edition="${kv#edition=}";; esac; done
  # package.output is a glob, or a map of edition -> glob when editions name zips differently.
  glob=""
  [ -n "$edition" ] && glob="$(yay_config_get "package.output.$edition" 2>/dev/null)" || true
  if [ -z "$glob" ]; then
    glob="$(yay_config_get package.output 2>/dev/null)" || yay_die "set package.output in .yay/config.json (a glob like release/{slug}-{version}.zip, or {\"<edition>\": \"<glob>\"})"
    case "$glob" in "{"*) yay_die "package.output has no entry for edition '$edition'";; esac
  fi
  glob="$(yay_fill "$glob" "slug=$(yay_config_get plugin.slug)" "$@")"
  # shellcheck disable=SC2086
  ( cd "$root" && ls -t $glob 2>/dev/null | sed -n 1p )
}

# yay_zip_check <zip> [edition=<e>] [version=<v>]
# Lines: PASS|WARN|FAIL<TAB><check><TAB><detail>. Exit 1 on any FAIL.
yay_zip_check() {
  local zip="$1"; shift
  local edition="" version="" kv
  for kv in "$@"; do case "$kv" in edition=*) edition="${kv#edition=}";; version=*) version="${kv#version=}";; *) yay_die "usage: yayh build check <zip> [edition=e] [version=v]";; esac; done
  local root fails=0 slug main readme list tops top tmp
  root="$(yay_repo_root)"; case "$zip" in /*) ;; *) zip="$root/$zip";; esac
  [ -f "$zip" ] || yay_die "no zip at $zip"
  slug="$(yay_config_get plugin.slug)"; main="$(yay_config_get plugin.mainFile)"; readme="$(yay_config_get changelog.readme)"
  _r() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; [ "$1" = FAIL ] && fails=$((fails+1)); return 0; }

  list="$(unzip -Z1 "$zip" 2>/dev/null)" || { _r FAIL zip "not a readable zip"; return 1; }
  tops="$(printf '%s\n' "$list" | cut -d/ -f1 | sort -u)"
  if [ "$(printf '%s\n' "$tops" | grep -c .)" = 1 ]; then top="$tops"; _r PASS folder "single top folder $top/"
  else top=""; _r FAIL folder "expected one top folder, got: $(printf '%s' "$tops" | tr '\n' ' ')"; fi
  [ -z "$top" ] || [ "$top" = "$slug" ] || _r WARN folder "top folder is $top/, plugin slug is $slug (WordPress installs it as $top)"

  # Dev files that must never ship, and ones that usually shouldn't.
  local allow p hit
  allow="$(yay_config_get package.allow 2>/dev/null || true)"
  _hits() { printf '%s\n' "$list" | sed "s|^[^/]*/||" | { grep -E "$1" || true; } | while IFS= read -r p; do
              hit=0; while IFS= read -r a; do [ -n "$a" ] && case "$p" in $a) hit=1;; esac; done <<A
$allow
A
              [ "$hit" = 1 ] || printf '%s\n' "$p"; done | sed -n '1,5p'; }
  local bad
  bad="$(_hits '(^|/)(\.git|\.claude|\.yay|node_modules)/|(^|/)(CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md|\.env(\..*)?)$')"
  if [ -n "$bad" ]; then _r FAIL dev-files "$(printf '%s' "$bad" | tr '\n' ' ')"; else _r PASS dev-files "no .git, .claude, .yay, node_modules, CLAUDE.md, .env"; fi
  bad="$(_hits '^(\.github|tests?|docs)/|(^|/)(phpunit\.xml(\.dist)?|phpcs\.xml(\.dist)?|\.nvmrc|\.editorconfig|\.DS_Store|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|[^/]+\.map)$|^(package|composer)\.json$')"
  if [ -n "$bad" ]; then _r WARN dev-files "usually not shipped: $(printf '%s' "$bad" | tr '\n' ' ') (allow with package.allow)"; fi

  # Per-edition forbidden paths (e.g. Pro code in a Free/Lite zip).
  if [ -n "$edition" ]; then
    local forb g found=""
    forb="$(yay_config_get "package.forbidden.$edition" 2>/dev/null || true)"
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      found="$found$(printf '%s\n' "$list" | sed "s|^[^/]*/||" | { grep -F -- "$g" || true; } | sed -n '1,3p')"
    done <<F
$forb
F
    if [ -n "$forb" ]; then
      if [ -n "$found" ]; then _r FAIL edition "$edition zip contains forbidden paths: $(printf '%s' "$found" | tr '\n' ' ')"
      else _r PASS edition "no $(printf '%s\n' "$forb" | paste -sd' ' -) in the $edition zip"; fi
    fi
  fi

  # Extract once for content checks.
  tmp="$(mktemp -d)"; unzip -q "$zip" -d "$tmp" 2>/dev/null
  local base="$tmp/$top"
  if [ -f "$base/$main" ]; then
    local hv; hv="$(sed -n 's/^[[:space:]*#@]*Version:[[:space:]]*//p' "$base/$main" | sed -n 1p | tr -d '\r ')"
    if [ -n "$version" ] && [ "$hv" != "$version" ]; then _r FAIL version "$main header says $hv, expected $version"
    else _r PASS version "$main Version: $hv"; fi
  else
    _r FAIL main-file "$main is not in the zip"
  fi
  if [ -n "$version" ] && [ -f "$base/$readme" ]; then
    local st; st="$(sed -n 's/^Stable tag:[[:space:]]*//p' "$base/$readme" | sed -n 1p | tr -d '\r ')"
    [ -z "$st" ] || [ "$st" = "$version" ] || [ "$st" = trunk ] && _r PASS stable-tag "${st:-none}" || _r FAIL stable-tag "readme Stable tag is $st, expected $version"
  fi
  if command -v php >/dev/null 2>&1; then
    local perr; perr="$(find "$base" -name '*.php' -print0 | xargs -0 -n 50 php -l 2>&1 | grep -v '^No syntax errors' | grep -v '^$' | sed -n '1,5p' || true)"
    if [ -n "$perr" ]; then _r FAIL php-syntax "$(printf '%s' "$perr" | tr '\n' ' ')"; else _r PASS php-syntax "php -l ($(php -r 'echo PHP_VERSION;')) on $(find "$base" -name '*.php' | wc -l | tr -d ' ') files"; fi
  fi
  _r PASS size "$(du -h "$zip" | cut -f1 | tr -d ' '), $(printf '%s\n' "$list" | { grep -vc '/$' || true; }) files"
  rm -rf "$tmp"

  # Repo-defined checks.
  local c cmd
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cmd="$(yay_fill "$c" "zip=$zip" "edition=$edition" "version=$version" "slug=$slug")"
    if (cd "$root" && bash -c "$cmd") >/dev/null 2>&1; then _r PASS check "$cmd"; else _r FAIL check "$cmd"; fi
  done <<CH
$(yay_config_get checks 2>/dev/null || true)
CH
  [ "$fails" -eq 0 ]
}
