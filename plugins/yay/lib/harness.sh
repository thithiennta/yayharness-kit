# shellcheck shell=bash
# Harness lifecycle: detect a repo's stack, inventory and wipe the old harness,
# render kit templates and sync them against .yay/manifest.json.
# See reference/ownership.md.

YAY_TEMPLATES="$YAY_KIT_ROOT/templates"

# What /yay:harness-init wipes (tracked files only). Order matters for display.
yay_wipe_targets() {
  printf '%s\n' \
    CLAUDE.md AGENTS.md GEMINI.md .cursorrules .cursor .windsurfrules \
    .github/copilot-instructions.md \
    .claude/skills .claude/rules .claude/hooks .claude/agents .claude/commands \
    .claude/agent-memory .claude/docs .claude/CLAUDE.md .claude/settings.json \
    docs
}

# Never wiped, even when inside a target.
yay_always_keep() {
  printf '%s\n' .claude/settings.local.json .claude/worktrees CLAUDE.local.md
}

# ---------- JSON helpers ----------

yay_json_str() { # escape a string as a JSON string literal
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//	/\\t}"
  printf '"%s"' "$s"
}

# Pretty-print JSON from stdin when an engine can; pass through otherwise.
yay_json_pretty() {
  local tmp; tmp="$(mktemp)"; cat > "$tmp"
  case "$(yay_json_engine)" in
    jq) jq . "$tmp" ;;
    node) node -e 'process.stdout.write(JSON.stringify(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")),null,2)+"\n")' "$tmp" ;;
    php) php -r 'echo json_encode(json_decode(file_get_contents($argv[1])),JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$tmp" ;;
    python3) python3 -I -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),indent=2))' "$tmp" ;;
  esac
  local rc=$?; rm -f "$tmp"; return $rc
}

# Deep-merge two JSON files: objects merge recursively, arrays become the
# union (left order first, duplicates dropped), other values: right wins.
yay_json_merge() {
  local a="$1" b="$2"
  case "$(yay_json_engine)" in
    jq) jq -s 'def m($x; $y):
          if ($x|type) == "object" and ($y|type) == "object" then
            reduce ($y|keys_unsorted[]) as $k ($x; .[$k] = (if ($x|has($k)) then m($x[$k]; $y[$k]) else $y[$k] end))
          elif ($x|type) == "array" and ($y|type) == "array" then
            reduce $y[] as $i ($x; if any(.[]; . == $i) then . else . + [$i] end)
          else $y end;
        m(.[0]; .[1])' "$a" "$b" ;;
    node) node -e 'const fs=require("fs");const r=f=>JSON.parse(fs.readFileSync(f,"utf8"));const isO=v=>v&&typeof v==="object"&&!Array.isArray(v);const m=(x,y)=>{if(isO(x)&&isO(y)){const o={...x};for(const k of Object.keys(y))o[k]=k in x?m(x[k],y[k]):y[k];return o}if(Array.isArray(x)&&Array.isArray(y)){const o=[...x];for(const i of y)if(!o.some(e=>JSON.stringify(e)===JSON.stringify(i)))o.push(i);return o}return y};process.stdout.write(JSON.stringify(m(r(process.argv[1]),r(process.argv[2])),null,2)+"\n")' "$a" "$b" ;;
    php) php -r 'function l($v){return is_array($v)&&($v===[]||array_keys($v)===range(0,count($v)-1));}function m($x,$y){if(is_array($x)&&is_array($y)&&!l($x)&&!l($y)){foreach($y as $k=>$v)$x[$k]=array_key_exists($k,$x)?m($x[$k],$v):$v;return $x;}if(l($x)&&l($y)&&is_array($x)&&is_array($y)){foreach($y as $i)if(!in_array($i,$x,true))$x[]=$i;return $x;}return $y;}echo json_encode(m(json_decode(file_get_contents($argv[1]),true),json_decode(file_get_contents($argv[2]),true)),JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$a" "$b" ;;
    python3) python3 -I -c '
import json,sys
def m(x,y):
    if isinstance(x,dict) and isinstance(y,dict):
        o=dict(x)
        for k,v in y.items(): o[k]=m(x[k],v) if k in x else v
        return o
    if isinstance(x,list) and isinstance(y,list):
        return x+[i for i in y if i not in x]
    return y
print(json.dumps(m(json.load(open(sys.argv[1])),json.load(open(sys.argv[2]))),indent=2))' "$a" "$b" ;;
  esac
}

# ---------- detect ----------

_hdr() { # _hdr <file> <Header Name> -> value from a WP plugin/readme header
  [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]*#@]*$2:[[:space:]]*//p" "$1" | head -1 | sed 's/[[:space:]]*$//' | tr -d '\r'
}

_has_script() { yay_json_get "$1" "scripts.$2" >/dev/null 2>&1; }

yay_detect_main_file() {
  local root f; root="$(yay_repo_root)"
  for f in "$root"/*.php; do
    [ -f "$f" ] || continue
    case "$(head -40 "$f")" in *'Plugin Name:'*) basename "$f"; return 0 ;; esac
  done
  return 3
}

yay_detect_pm() {
  local root; root="$(yay_repo_root)"
  [ -f "$root/package.json" ] || return 3
  if [ -f "$root/pnpm-lock.yaml" ] || grep -q '"packageManager"[[:space:]]*:[[:space:]]*"pnpm' "$root/package.json"; then echo pnpm
  elif [ -f "$root/yarn.lock" ]; then echo yarn
  else echo npm; fi
}

# Print a proposed .yay/config.json for the current repo. Every guess is a
# draft; /yay:harness-init shows it to the user before writing.
yay_detect() {
  local root main name ver slug td rphp rwp rwc twp twc editions wporg base tagfmt pm
  root="$(yay_repo_root)"
  main="$(yay_detect_main_file)" || main=""
  name="$(_hdr "$root/$main" 'Plugin Name')"; [ -n "$name" ] || name="$(basename "$root")"
  ver="$(_hdr "$root/$main" 'Version')"
  slug="${main%.php}"; [ -n "$slug" ] || slug="$(yay_slugify "$(basename "$root")")"
  slug="$(yay_slugify "$slug")"
  td="$(_hdr "$root/$main" 'Text Domain')"; [ -n "$td" ] || td="$slug"
  rphp="$(_hdr "$root/$main" 'Requires PHP')"; [ -n "$rphp" ] || rphp="$(_hdr "$root/readme.txt" 'Requires PHP')"; [ -n "$rphp" ] || rphp="7.4"
  rwp="$(_hdr "$root/$main" 'Requires at least')"; [ -n "$rwp" ] || rwp="$(_hdr "$root/readme.txt" 'Requires at least')"
  rwc="$(_hdr "$root/$main" 'WC requires at least')"
  twp="$(_hdr "$root/readme.txt" 'Tested up to')"
  twc="$(_hdr "$root/$main" 'WC tested up to')"

  if [ -d "$root/includes/Pro" ] || [ -d "$root/src/Pro" ] || [ -d "$root/pro" ] || [ -d "$root/editions" ]; then
    editions='["free","pro"]'; wporg='null'
  else
    editions='["free"]'
    if [ -f "$root/readme.txt" ] && grep -qi '^Stable tag:' "$root/readme.txt"; then wporg="$(yay_json_str "$slug")"; else wporg='null'; fi
  fi

  base=""
  for b in dev develop main master; do
    git -C "$root" show-ref --verify --quiet "refs/heads/$b" && { base="$b"; break; }
  done
  [ -n "$base" ] || base="$(git -C "$root" branch --show-current 2>/dev/null)"; [ -n "$base" ] || base="main"

  tagfmt='v{version}'
  local lt; lt="$(git -C "$root" tag --sort=-v:refname 2>/dev/null | grep -E '^v?[0-9]+\.' | head -1 || true)"
  case "$lt" in [0-9]*) tagfmt='{version}';; esac

  # Commands
  local cmds="" install="" build="" lint="" typecheck="" test="" dev="" package=""
  pm="$(yay_detect_pm)" || pm=""
  local runsh="$root/scripts/run.sh"
  if [ -n "$pm" ]; then install="$pm install"; fi
  if [ -f "$root/composer.json" ]; then install="${install:+$install && }composer install"; fi
  if [ -f "$runsh" ] && grep -qE '^[[:space:]]*build\)' "$runsh"; then build="./scripts/run.sh build"
  elif [ -n "$pm" ] && _has_script "$root/package.json" build; then build="$pm run build"; fi
  if [ -f "$root/composer.json" ] && _has_script "$root/composer.json" lint; then lint="composer lint"; fi
  if [ -n "$pm" ] && _has_script "$root/package.json" lint; then lint="${lint:+$lint && }$pm run lint"; fi
  if [ -n "$pm" ] && _has_script "$root/package.json" typecheck; then typecheck="$pm run typecheck"; fi
  if [ -f "$root/composer.json" ] && _has_script "$root/composer.json" test; then test="composer test"; fi
  if [ -n "$pm" ] && _has_script "$root/package.json" dev; then dev="$pm run dev"
  elif [ -f "$runsh" ] && grep -qE '^[[:space:]]*dev\)' "$runsh"; then dev="./scripts/run.sh dev"; fi
  if [ -f "$runsh" ] && grep -qE '^[[:space:]]*release\)' "$runsh"; then package="./scripts/run.sh release {version} --plan={edition} --no-prompt"; fi
  local k v
  for k in install dev build lint typecheck test package; do
    eval "v=\$$k"
    [ -n "$v" ] && cmds="$cmds${cmds:+,}$(yay_json_str "$k"):$(yay_json_str "$v")"
  done

  # Version files
  local vf=""
  if [ -n "$main" ]; then
    vf="{\"file\":$(yay_json_str "$main"),\"pattern\":$(yay_json_str '^[[:space:]*]*Version:[[:space:]]*([0-9][^[:space:]]*)')}"
    local const; const="$(grep -oE "define\([[:space:]]*'[A-Z0-9_]+_VERSION'" "$root/$main" 2>/dev/null | head -1 | grep -oE "[A-Z0-9_]+_VERSION" || true)"
    [ -n "$const" ] && vf="$vf,{\"file\":$(yay_json_str "$main"),\"pattern\":$(yay_json_str "define\\([[:space:]]*'$const',[[:space:]]*'([^']+)'")}"
  fi
  [ -f "$root/readme.txt" ] && vf="$vf${vf:+,}{\"file\":\"readme.txt\",\"pattern\":$(yay_json_str '^Stable tag:[[:space:]]*([0-9][^[:space:]]*)')}"

  # Generated paths: present on disk or ignored by git.
  local gp="" p
  for p in vendor/ vendor-prefixed/ node_modules/ assets/dist/ build/ dist/ release/; do
    if [ -e "$root/${p%/}" ] || grep -qxE "/?${p%/}/?" "$root/.gitignore" 2>/dev/null; then
      gp="$gp${gp:+,}$(yay_json_str "$p")"
    fi
  done

  local pkgout='null'
  grep -qxE '/?release/?' "$root/.gitignore" 2>/dev/null && pkgout="$(yay_json_str 'release/*.zip')"

  {
    printf '{'
    printf '"schemaVersion":1,'
    printf '"plugin":{"name":%s,"slug":%s,"mainFile":%s,"textDomain":%s,"wporgSlug":%s},' \
      "$(yay_json_str "$name")" "$(yay_json_str "$slug")" "$(yay_json_str "$main")" "$(yay_json_str "$td")" "$wporg"
    printf '"editions":%s,' "$editions"
    printf '"requires":{"php":%s,"wp":%s,"wc":%s},' "$(yay_json_str "$rphp")" "$(yay_json_str "${rwp:-6.5}")" \
      "$( [ -n "$rwc" ] && yay_json_str "$rwc" || echo null )"
    printf '"tested":{"wp":%s,"wc":%s},' "$(yay_json_str "${twp:-}")" "$( [ -n "$twc" ] && yay_json_str "$twc" || echo null )"
    printf '"git":{"baseBranch":%s,"tagFormat":%s,"branchTypes":["feat","fix","chore","hotfix","docs","refactor","test"],"scopes":[]},' \
      "$(yay_json_str "$base")" "$(yay_json_str "$tagfmt")"
    printf '"commands":{%s},' "$cmds"
    printf '"package":{"output":%s},' "$pkgout"
    printf '"versionFiles":[%s],' "$vf"
    printf '"generatedPaths":[%s],' "$gp"
    printf '"changelog":{"readme":"readme.txt","notesDir":"docs/releases"},'
    printf '"checks":[],"keep":[]'
    printf '}\n'
  } | yay_json_pretty
  [ -n "$ver" ] && printf 'yayh: detected version %s in %s\n' "$ver" "$main" >&2
  return 0
}

# Light validation of .yay/config.json (no JSON Schema engine needed).
yay_config_validate() {
  local f errs=0 k v
  f="$(yay_config_file)"
  [ -f "$f" ] || { echo "missing $f" >&2; return 1; }
  yay_json_get "$f" schemaVersion >/dev/null || { echo "not valid JSON or no schemaVersion: $f" >&2; return 1; }
  for k in plugin.name plugin.slug plugin.mainFile editions git.baseBranch; do
    v="$(yay_json_get "$f" "$k" 2>/dev/null)" || v=""
    [ -n "$v" ] || { echo "config: $k is required" >&2; errs=$((errs+1)); }
  done
  v="$(yay_json_get "$f" plugin.slug 2>/dev/null)" || v=""
  printf '%s' "$v" | grep -Eq '^[a-z0-9-]+$' || { echo "config: plugin.slug must be lowercase kebab-case" >&2; errs=$((errs+1)); }
  v="$(yay_json_get "$f" plugin.mainFile 2>/dev/null)" || v=""
  [ -z "$v" ] || [ -f "$(yay_repo_root)/$v" ] || { echo "config: plugin.mainFile '$v' does not exist" >&2; errs=$((errs+1)); }
  v="$(yay_json_get "$f" git.tagFormat 2>/dev/null)" || v="{version}"
  case "$v" in *'{version}'*) ;; *) echo "config: git.tagFormat must contain {version}" >&2; errs=$((errs+1));; esac
  yay_json_get "$f" commands >/dev/null 2>&1 || { echo "config: commands is required (use {} when none apply)" >&2; errs=$((errs+1)); }
  local line file
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="$(printf '%s' "$line" | sed -n 's/.*"file":"\([^"]*\)".*/\1/p')"
    [ -z "$file" ] || [ -f "$(yay_repo_root)/$file" ] || { echo "config: versionFiles entry '$file' does not exist" >&2; errs=$((errs+1)); }
  done <<EOF
$(yay_json_get "$f" versionFiles 2>/dev/null)
EOF
  [ "$errs" -eq 0 ]
}

# ---------- inventory & wipe ----------

# _is_kept <path> -> 0 when path is (inside) an always-keep, config.keep or
# --keep=<path> entry (inventory/wipe options; YAY_KEEP env works too).
_is_kept() {
  local p="$1" k
  for k in $(yay_always_keep) $(yay_config_get keep 2>/dev/null || true) ${YAY_KEEP:-}; do
    k="${k%/}"
    case "$p" in "$k"|"$k"/*) return 0;; esac
  done
  return 1
}

# yay_inventory -> TSV lines:
#   wipe<TAB><target><TAB><tracked-file-count>
#   keep<TAB><path><TAB><reason>
#   untracked<TAB><path>
yay_inventory() {
  local a; for a in "$@"; do case "$a" in --keep=*) YAY_KEEP="${YAY_KEEP:-}${YAY_KEEP:+ }${a#--keep=}";; *) yay_die "inventory: unknown option $a";; esac; done
  local root t n f
  root="$(yay_repo_root)"
  for t in $(yay_wipe_targets); do
    [ -e "$root/$t" ] || continue
    n=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if _is_kept "$f"; then printf 'keep\t%s\tkept by rule\n' "$f"; else n=$((n+1)); fi
    done <<EOF
$(git -C "$root" ls-files -- "$t")
EOF
    [ "$n" -gt 0 ] && printf 'wipe\t%s\t%d\n' "$t" "$n"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      _is_kept "$f" && continue
      printf 'untracked\t%s\n' "$f"
    done <<EOF
$(git -C "$root" ls-files --others --exclude-standard -- "$t")
EOF
  done
  for t in $(yay_always_keep); do
    [ -e "$root/$t" ] && printf 'keep\t%s\tpersonal file, never wiped\n' "$t"
  done
  return 0
}

# yay_wipe --yes [--allow-base]  -> git rm the tracked wipe targets, keeping kept paths.
yay_wipe() {
  local yes=0 allow_base=0 a root br base t
  for a in "$@"; do
    case "$a" in
      --yes) yes=1;; --allow-base) allow_base=1;;
      --keep=*) YAY_KEEP="${YAY_KEEP:-}${YAY_KEEP:+ }${a#--keep=}";;
      *) yay_die "wipe: unknown option $a";;
    esac
  done
  [ "$yes" = 1 ] || yay_die "wipe deletes files; show 'yayh harness inventory' to the user, then pass --yes"
  root="$(yay_repo_root)"
  git -C "$root" diff --quiet && git -C "$root" diff --cached --quiet \
    || yay_die "the working tree has uncommitted changes; commit or stash them first"
  br="$(git -C "$root" branch --show-current)"
  base="$(yay_config_get git.baseBranch 2>/dev/null || yay_base_branch)"
  if [ "$br" = "$base" ] && [ "$allow_base" = 0 ]; then
    yay_die "on the base branch '$base'; create a branch first (e.g. chore/yay-harness)"
  fi
  local excludes="" k
  for k in $(yay_always_keep) $(yay_config_get keep 2>/dev/null || true) ${YAY_KEEP:-}; do
    excludes="$excludes :(exclude)${k%/}"
  done
  for t in $(yay_wipe_targets); do
    [ -n "$(git -C "$root" ls-files -- "$t")" ] || continue
    # shellcheck disable=SC2086
    git -C "$root" rm -r -q --ignore-unmatch -- "$t" $excludes
    printf 'wiped\t%s\n' "$t"
  done
}

# ---------- templates ----------

# Registry: templates/registry.tsv  (template<TAB>dest<TAB>mode<TAB>group)
#   mode: file  = kit-owned whole file, tracked in the manifest
#         block = kit-owned managed block inside dest (entry dest#managed)
#         json  = kit-owned JSON file, deep-merged with .yay/<basename>.extra.json
#         seed  = written once if missing, then owned by knowledge/workflow (not tracked)
yay_registry() { grep -v '^#' "$YAY_TEMPLATES/registry.tsv" | grep -v '^[[:space:]]*$'; }

# Marketplace source for .claude/settings.json: the user's registered source
# for "yayharness", else the planned GitHub repo.
yay_marketplace_source() {
  local km="$HOME/.claude/plugins/known_marketplaces.json" src=""
  if [ -n "${YAY_MARKETPLACE_SOURCE:-}" ]; then printf '%s\n' "$YAY_MARKETPLACE_SOURCE"; return; fi
  if [ -f "$km" ]; then src="$(yay_json_get "$km" yayharness.source 2>/dev/null)" || src=""; fi
  [ -n "$src" ] && { printf '%s\n' "$src"; return; }
  printf '{"source":"github","repo":"YayCommerce/yayharness"}\n'
}

# yay_render <template-file> -> stdout. Placeholders: {{dotted.config.key}},
# {{kit.version}}, {{kit.marketplaceSource}}, {{today}}. Arrays join with ", ".
yay_render() {
  local tpl="$1" out keys k v
  out="$(cat "$tpl")"
  keys="$(grep -oE '\{\{[a-zA-Z0-9_.]+\}\}' "$tpl" | sort -u | sed 's/[{}]//g')" || true
  for k in $keys; do
    case "$k" in
      kit.version) v="$(yay_kit_version)" ;;
      kit.marketplaceSource) v="$(yay_marketplace_source)" ;;
      today) v="$(yay_today)" ;;
      *) v="$(yay_config_get "$k" 2>/dev/null | paste -sd, - | sed 's/,/, /g')" || v="" ;;
    esac
    out="$(printf '%s' "$out" | awk -v k="{{$k}}" -v v="$v" 'BEGIN{gsub(/\\/,"\\\\",v)} { while ((i = index($0, k)) > 0) $0 = substr($0, 1, i-1) v substr($0, i+length(k)); print }')"
  done
  printf '%s\n' "$out"
}

# Rendered content for a registry row (json mode merges the extra file).
_rendered() {
  local tpl="$1" dest="$2" mode="$3" tmp extra root
  root="$(yay_repo_root)"
  if [ "$mode" = json ]; then
    tmp="$(mktemp)"; yay_render "$YAY_TEMPLATES/$tpl" > "$tmp"
    extra="$root/.yay/$(basename "${dest%.json}").extra.json"
    if [ -f "$extra" ]; then yay_json_merge "$tmp" "$extra"; else yay_json_pretty < "$tmp"; fi
    rm -f "$tmp"
  else
    yay_render "$YAY_TEMPLATES/$tpl"
  fi
}

# Replace (or insert) the managed block of <file> with the block in <newblock-file>.
_write_block() {
  local file="$1" nb="$2" tmp
  tmp="$(mktemp)"
  if [ -f "$file" ] && grep -q '<!-- yay:managed:start' "$file"; then
    awk -v nb="$nb" '
      /<!-- yay:managed:start/ { while ((getline l < nb) > 0) print l; skip=1; next }
      skip && /<!-- yay:managed:end -->/ { skip=0; next }
      !skip { print }
    ' "$file" > "$tmp"
  elif [ -f "$file" ]; then
    awk -v nb="$nb" 'NR==1 && /^# / { print; print ""; while ((getline l < nb) > 0) print l; print ""; next } NR==1 { while ((getline l < nb) > 0) print l; print "" } { print }' "$file" > "$tmp"
  else
    cat "$nb" > "$tmp"
  fi
  mkdir -p "$(dirname "$file")"; cat "$tmp" > "$file"; rm -f "$tmp"
}

# Current content tracked for a dest (whole file or managed block), for diffs.
_current() {
  local entry="$1"
  yay_manifest_content "$entry" 2>/dev/null || true
}

# yay_sync [--check] [--force] [--diff] [--only=<group>[,<group>]]
# Output: "<action>\t<entry>" with action in
#   created updated up-to-date seeded skipped-modified conflict removed orphaned
# --check: change nothing; exit 1 when anything would change.
yay_sync() {
  local check=0 force=0 diff=0 only="" a
  for a in "$@"; do
    case "$a" in
      --check) check=1;; --force) force=1;; --diff) diff=1;; --only=*) only="${a#--only=}";;
      *) yay_die "sync: unknown option $a";;
    esac
  done
  yay_config_require
  local root pending=0 unresolved=0 tpl dest mode group entry status new cur action tmpnew registered=""
  root="$(yay_repo_root)"
  tmpnew="$(mktemp)"
  while IFS="$(printf '\t')" read -r tpl dest mode group; do
    [ -n "$tpl" ] || continue
    if [ -n "$only" ]; then case ",$only," in *",$group,"*) ;; *) continue;; esac; fi
    entry="$dest"; [ "$mode" = block ] && entry="$dest#managed"
    registered="$registered $entry "

    if [ "$mode" = lines ]; then
      local missing="" l
      while IFS= read -r l; do
        [ -n "$l" ] || continue
        grep -qxF -- "$l" "$root/$dest" 2>/dev/null || missing="$missing$l
"
      done < "$YAY_TEMPLATES/$tpl"
      if [ -z "$missing" ]; then printf 'up-to-date\t%s\n' "$entry"; continue; fi
      pending=1
      if [ "$check" = 0 ]; then
        { [ -s "$root/$dest" ] && [ -n "$(tail -c1 "$root/$dest")" ] && echo; printf '# yay harness\n%s' "$missing"; } >> "$root/$dest"
      fi
      printf 'updated\t%s\n' "$entry"; continue
    fi

    if [ "$mode" = seed ]; then
      if [ -e "$root/$dest" ]; then continue; fi
      action=seeded
      if [ "$check" = 0 ]; then
        mkdir -p "$(dirname "$root/$dest")"
        case "$tpl" in -) : > "$root/$dest" ;; *) yay_render "$YAY_TEMPLATES/$tpl" > "$root/$dest" ;; esac
      fi
      pending=1; printf '%s\t%s\n' "$action" "$entry"; continue
    fi

    _rendered "$tpl" "$dest" "$mode" > "$tmpnew"
    new="$(cat "$tmpnew")"
    cur="$(_current "$entry")"
    # An empty managed block (just its two markers, as seeded) counts as absent.
    if [ "$mode" = block ] && [ "$(printf '%s\n' "$cur" | grep -cv '^<!-- yay:managed:\(start\|end\)')" = 0 ]; then cur=""; fi
    status="$(yay_manifest_status "$entry" | cut -f1)"
    if [ -z "$status" ]; then
      # Not tracked yet.
      if [ -z "$cur" ]; then status=missing
      elif [ "$cur" = "$new" ]; then status=same
      else status=untracked-differs; fi
    fi

    if [ "$cur" = "$new" ] && [ -n "$cur" ]; then
      action=up-to-date
    else
      case "$status" in
        missing) [ -z "$cur" ] && action=created || action=updated ;;
        clean|same) action=updated ;;
        modified) [ "$force" = 1 ] && action=updated || action=skipped-modified ;;
        untracked-differs) [ "$force" = 1 ] && action=updated || action=conflict ;;
      esac
    fi

    if [ "$diff" = 1 ] && [ "$action" != up-to-date ]; then
      diff -u <(printf '%s\n' "$cur") "$tmpnew" | sed -e "1s|.*|--- a/$entry|" -e "2s|.*|+++ b/$entry (kit $(yay_kit_version))|" >&2 || true
    fi

    case "$action" in
      created|updated)
        pending=1
        if [ "$check" = 0 ]; then
          if [ "$mode" = block ]; then _write_block "$root/$dest" "$tmpnew"
          else mkdir -p "$(dirname "$root/$dest")"; cat "$tmpnew" > "$root/$dest"; fi
          yay_manifest_record "$entry" "$tpl"
        fi ;;
      up-to-date)
        # Make sure an identical-but-untracked file becomes tracked.
        if [ "$check" = 0 ] && [ "$status" = same ]; then yay_manifest_record "$entry" "$tpl"; fi ;;
      skipped-modified|conflict) pending=1; unresolved=1 ;;
    esac
    printf '%s\t%s\n' "$action" "$entry"
  done <<EOF
$(yay_registry)
EOF
  rm -f "$tmpnew"

  # Entries the kit no longer ships.
  if [ -z "$only" ]; then
    local st e
    while IFS="$(printf '\t')" read -r st e; do
      [ -n "$e" ] || continue
      case "$registered" in *" $e "*) continue;; esac
      pending=1
      if [ "$st" = clean ] && [ "$check" = 0 ]; then
        case "$e" in *'#managed') : ;; *) rm -f "$root/$e" ;; esac
        yay_manifest_forget "$e"; printf 'removed\t%s\n' "$e"
      elif [ "$st" = missing ] && [ "$check" = 0 ]; then
        yay_manifest_forget "$e"; printf 'removed\t%s\n' "$e"
      else
        unresolved=1; printf 'orphaned\t%s\n' "$e"
      fi
    done <<EOF
$(yay_manifest_status)
EOF
  fi

  if [ "$check" = 1 ]; then
    [ "$pending" = 1 ] && return 1
    [ "$(yay_harness_status)" = "current $(yay_kit_version)" ] || return 1
    return 0
  fi
  # Stamp the kit version only when a full sync left nothing for the user.
  if [ -z "$only" ] && [ "$unresolved" = 0 ]; then yay_manifest_stamp; fi
  return 0
}

# Paths the kit wrote or manages that exist now, for staging precisely
# (never `git add -A`: that would sweep in the user's untracked files).
yay_harness_files() {
  local root tpl dest mode group
  root="$(yay_repo_root)"
  for dest in .yay/config.json .yay/manifest.json .yay/settings.extra.json; do
    [ -e "$root/$dest" ] && printf '%s\n' "$dest"
  done
  while IFS="$(printf '\t')" read -r tpl dest mode group; do
    [ -n "$dest" ] && [ -e "$root/$dest" ] && printf '%s\n' "$dest"
  done <<EOF
$(yay_registry)
EOF
  return 0
}

# Kit version recorded in the repo vs the installed kit.
yay_harness_status() {
  local mf have want
  mf="$(yay_manifest_file)"
  want="$(yay_kit_version)"
  if [ ! -f "$(yay_config_file)" ]; then echo "not-initialized"; return 0; fi
  have="$(yay_json_get "$mf" kitVersion 2>/dev/null)" || have=""
  if [ -z "$have" ]; then echo "no-manifest"
  elif [ "$have" = "$want" ]; then echo "current $have"
  else echo "outdated $have -> $want"; fi
}
