# shellcheck shell=bash
# Release checks, bundle size, the bundle folder, and the plugins-page UI check
# against the built zip, for /yay:release. Lines are STATUS<TAB>check<TAB>detail.

# ---------- versions ----------

# _yay_semver_gt <a> <b>: 0 when a > b. A prerelease (1.5.0-rc.2) sorts before
# its release (1.5.0), and rc.10 after rc.9.
_yay_semver_gt() {
  awk -v a="$1" -v b="$2" '
    function split3(v, o,   core, n, i) { core = v; sub(/[-+].*/, "", core); n = split(core, o, "."); for (i = n + 1; i <= 3; i++) o[i] = 0 }
    function pre(v) { if (v !~ /-/) return ""; sub(/^[^-]*-/, "", v); return v }
    function precmp(x, y,   xs, ys, nx, ny, i) {
      if (x == y) return 0; if (x == "") return 1; if (y == "") return -1
      nx = split(x, xs, "."); ny = split(y, ys, ".")
      for (i = 1; i <= nx && i <= ny; i++) {
        if (xs[i] == ys[i]) continue
        if (xs[i] ~ /^[0-9]+$/ && ys[i] ~ /^[0-9]+$/) return (xs[i] + 0 > ys[i] + 0) ? 1 : -1
        return (xs[i] > ys[i]) ? 1 : -1
      }
      return (nx > ny) ? 1 : (nx < ny ? -1 : 0)
    }
    BEGIN {
      split3(a, A); split3(b, B)
      for (i = 1; i <= 3; i++) { if (A[i] + 0 > B[i] + 0) exit 0; if (A[i] + 0 < B[i] + 0) exit 1 }
      exit (precmp(pre(a), pre(b)) > 0 ? 0 : 1)
    }'
}

_yay_release_status() { # STATUS check detail; counts FAILs in _rfails
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  [ "$1" != FAIL ] || _rfails=$((_rfails + 1))
  return 0
}

# yay_release_check <version> [--rc]
# The release gate before building: versions agree and equal <version>, it's newer
# than the last tag, the readme's Stable tag, the changelog entry, the release notes.
# With --rc (a test bundle like 1.5.0-rc.1), the changelog and notes may not exist
# yet and the Stable tag isn't checked. Exit 1 on any FAIL.
yay_release_check() {
  local v="" rc="" a root readme last lv st mode base entry notes
  for a in "$@"; do case "$a" in --rc) rc=1 ;; -*) yay_die "usage: yayh release check <version> [--rc]" ;; *) v="$a" ;; esac; done
  [ -n "$v" ] || yay_die "usage: yayh release check <version> [--rc]"
  _rfails=0
  root="$(yay_repo_root)"; readme="$root/$(yay_config_get changelog.readme 2>/dev/null || echo readme.txt)"
  base="${v%%-*}"

  local cur
  if cur="$(yay_version_check 2>/dev/null)"; then
    if [ "$cur" = "$v" ]; then _yay_release_status PASS version "every version file says $v"
    else _yay_release_status FAIL version "version files say $cur, expected $v (yayh version set $v)"; fi
  else
    _yay_release_status FAIL version "version files disagree: $(yay_version_list | tr '\t\n' '= ' )"
  fi

  last="$(yay_last_tag 2>/dev/null || true)"
  if [ -n "$last" ]; then
    lv="$(yay_version_of_tag "$last" 2>/dev/null || true)"
    if [ -n "$lv" ] && _yay_semver_gt "$v" "$lv"; then _yay_release_status PASS newer "$v is newer than the last release $lv ($last)"
    else _yay_release_status FAIL newer "$v is not newer than the last release ${lv:-?} ($last)"; fi
  else
    _yay_release_status WARN newer "no release tag yet, so nothing to compare $v with"
  fi

  if [ -f "$readme" ]; then
    st="$(sed -n 's/^Stable tag:[[:space:]]*//p' "$readme" | sed -n 1p | tr -d '\r ')"
    mode="$(yay_config_get release.stableTag 2>/dev/null || echo version)"
    if [ -n "$rc" ]; then
      _yay_release_status PASS stable-tag "${st:-none} (not checked for a test bundle)"
    elif [ "$st" = "$v" ]; then _yay_release_status PASS stable-tag "Stable tag: $st"
    elif [ "$st" = trunk ] && [ "$mode" = trunk ]; then _yay_release_status PASS stable-tag "Stable tag: trunk (release.stableTag is trunk)"
    elif [ -z "$st" ]; then _yay_release_status FAIL stable-tag "$(basename "$readme") has no Stable tag line"
    else _yay_release_status FAIL stable-tag "Stable tag is $st, expected $v"; fi
  else
    _yay_release_status WARN stable-tag "no $(basename "$readme")"
  fi

  entry="$(yay_changelog_entry "$base" 2>/dev/null || true)"
  if [ -z "$entry" ]; then
    if [ -n "$rc" ]; then _yay_release_status WARN changelog "no entry for $base yet (the release writes it)"
    else _yay_release_status FAIL changelog "no changelog entry for $v in $(basename "$readme") (follow /yay:changelog)"; fi
  elif printf '%s' "$entry" | grep -Eiq '(^|[^a-z])(todo|tbd|fixme|lorem|xxx)([^a-z]|$)'; then
    _yay_release_status FAIL changelog "the $base entry has placeholder text: $(printf '%s\n' "$entry" | grep -Ei 'todo|tbd|fixme|lorem|xxx' | sed -n 1p)"
  else
    _yay_release_status PASS changelog "$(printf '%s\n' "$entry" | grep -c .) lines for $base"
  fi

  notes="$(yay_config_get changelog.notesDir 2>/dev/null || echo docs/releases)/$base.md"
  if [ -f "$root/$notes" ]; then _yay_release_status PASS notes "$notes"
  elif [ -n "$rc" ]; then _yay_release_status WARN notes "no $notes yet (the release writes it)"
  else _yay_release_status FAIL notes "no $notes (follow /yay:changelog)"; fi

  [ "$_rfails" -eq 0 ]
}

# ---------- size ----------

_yay_human() { awk -v b="$1" 'BEGIN { s = b < 0 ? "-" : ""; b = b < 0 ? -b : b; if (b >= 1048576) printf "%s%.1f MB", s, b / 1048576; else if (b >= 1024) printf "%s%.0f KB", s, b / 1024; else printf "%s%d B", s, b }'; }

# _yay_size_baseline <edition-key> <version> -> "<version> <bytes> <files>" of the
# newest earlier release whose notes recorded a size.
_yay_size_baseline() {
  local key="$1" v="$2" root dir f fv b n best="" bv=""
  root="$(yay_repo_root)"; dir="$root/$(yay_config_get changelog.notesDir 2>/dev/null || echo docs/releases)"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    fv="$(yay_fm_get "$f" version 2>/dev/null || basename "$f" .md)"
    [ "$fv" != "${v%%-*}" ] || continue
    _yay_semver_gt "$v" "$fv" || continue
    b="$(yay_fm_get "$f" "zip_bytes_$key" 2>/dev/null || true)"; [ -n "$b" ] || continue
    n="$(yay_fm_get "$f" "zip_files_$key" 2>/dev/null || echo 0)"
    if [ -z "$bv" ] || _yay_semver_gt "$fv" "$bv"; then bv="$fv"; best="$fv $b $n"; fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
}

# yay_release_size <zip> [edition=e] [version=v] [--record=<notes file>]
# Size, file count and the largest files, compared with the last release that
# recorded its size. UNUSUAL when the size or file count moves more than
# release.sizeChangePct (25) percent or release.sizeChangeKb (1024) KB, or a file is
# over release.largeFileKb (2048) KB. --record writes zip_bytes_<e>/zip_files_<e>
# into the notes front-matter, as the next release's baseline. Always exits 0.
yay_release_size() {
  local zip="" edition="" v="" record="" a root key bytes files pct kb large bl bv bb bn d dp df
  for a in "$@"; do
    case "$a" in
      edition=*) edition="${a#edition=}" ;; version=*) v="${a#version=}" ;; --record=*) record="${a#--record=}" ;;
      -*|*=*) yay_die "usage: yayh release size <zip> [edition=e] [version=v] [--record=<notes>]" ;;
      *) zip="$a" ;;
    esac
  done
  root="$(yay_repo_root)"; case "$zip" in /*) ;; *) zip="$root/$zip" ;; esac
  [ -f "$zip" ] || yay_die "no zip at $zip"
  key="${edition:-main}"
  pct="$(yay_config_get release.sizeChangePct 2>/dev/null || echo 25)"
  kb="$(yay_config_get release.sizeChangeKb 2>/dev/null || echo 1024)"
  large="$(yay_config_get release.largeFileKb 2>/dev/null || echo 2048)"
  bytes="$(wc -c < "$zip" | tr -d ' ')"
  files="$(unzip -Z1 "$zip" 2>/dev/null | grep -vc '/$' || true)"
  printf 'INFO\tsize\t%s (%s bytes), %s files\n' "$(_yay_human "$bytes")" "$bytes" "$files"

  if [ -n "$v" ] && bl="$(_yay_size_baseline "$key" "$v")"; then
    bv="${bl%% *}"; bb="$(printf '%s' "$bl" | cut -d' ' -f2)"; bn="$(printf '%s' "$bl" | cut -d' ' -f3)"
    d=$((bytes - bb)); df=$((files - bn))
    dp="$(awk -v d="$d" -v b="$bb" 'BEGIN { printf "%+.0f", b ? d * 100 / b : 0 }')"
    if awk -v d="$d" -v b="$bb" -v p="$pct" -v k="$kb" 'BEGIN { a = d < 0 ? -d : d; exit !((b && a * 100 / b > p) || a > k * 1024) }'; then
      printf 'UNUSUAL\tsize-change\t%s%% (%s) vs %s (%s)\n' "$dp" "$(_yay_human "$d")" "$bv" "$(_yay_human "$bb")"
    else
      printf 'OK\tsize-change\t%s%% (%s) vs %s (%s)\n' "$dp" "$(_yay_human "$d")" "$bv" "$(_yay_human "$bb")"
    fi
    if [ "$bn" -gt 0 ] && awk -v d="$df" -v b="$bn" -v p="$pct" 'BEGIN { a = d < 0 ? -d : d; exit !(a * 100 / b > p) }'; then
      printf 'UNUSUAL\tfile-count\t%+d files vs %s (%s)\n' "$df" "$bv" "$bn"
    else
      printf 'OK\tfile-count\t%+d files vs %s (%s)\n' "$df" "$bv" "$bn"
    fi
  else
    printf 'WARN\tbaseline\tno earlier release recorded its %s zip size: nothing to compare with (this release records one)\n' "$key"
  fi

  # unzip -Z -l: perms ver os size type csize method date time name
  local list; list="$(unzip -Z -l "$zip" 2>/dev/null | awk '
    NF >= 10 && $1 ~ /^[-d]/ && $NF !~ /\/$/ { name = $10; for (i = 11; i <= NF; i++) name = name " " $i; print $4 "\t" name }')"
  printf '%s\n' "$list" | awk -F '\t' -v big=$((large * 1024)) '$1 + 0 > big { printf "UNUSUAL\tlarge-file\t%s (%.1f MB)\n", $2, $1 / 1048576 }'
  printf 'INFO\tlargest\t%s\n' "$(printf '%s\n' "$list" | sort -rn | sed -n '1,5p' | awk -F '\t' 'NF { printf "%s%s (%s)", (NR > 1 ? ", " : ""), $2, ($1 >= 1048576 ? sprintf("%.1f MB", $1 / 1048576) : ($1 >= 1024 ? sprintf("%.0f KB", $1 / 1024) : $1 " B")) }')"

  if [ -n "$record" ]; then
    case "$record" in /*) ;; *) record="$root/$record" ;; esac
    [ -f "$record" ] || yay_die "no notes file $record"
    yay_fm_set "$record" "zip_bytes_$key" "$bytes" >/dev/null
    yay_fm_set "$record" "zip_files_$key" "$files" >/dev/null
    printf 'INFO\trecorded\t%s zip_bytes_%s=%s zip_files_%s=%s\n' "${record#"$root"/}" "$key" "$bytes" "$key" "$files"
  fi
}

# ---------- the bundle folder ----------

_yay_bundle_root() { printf '%s/%s\n' "$(yay_repo_root)" "$(yay_config_get release.bundleDir 2>/dev/null || echo release/bundles)"; }

# yay_release_next_rc <x.y.z> -> x.y.z-rc.<n>, one past the highest bundle made so far.
yay_release_next_rc() {
  local v="$1" slug d n max=0
  printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || yay_die "usage: yayh release next-rc <x.y.z>"
  slug="$(yay_config_get plugin.slug)"
  for d in "$(_yay_bundle_root)/$slug-$v-rc."*; do
    [ -d "$d" ] || continue
    n="${d##*-rc.}"; case "$n" in ''|*[!0-9]*) continue ;; esac
    [ "$n" -gt "$max" ] && max="$n"
  done
  printf '%s-rc.%d\n' "$v" $((max + 1))
}

_yay_sha256() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

# yay_release_bundle <version> <edition>=<zip>... [--replace]
# Collect the zips into <bundleDir>/<slug>-<version>/ with MANIFEST.txt (commit,
# size, file count, sha256 per zip) and files-<edition>.txt. Prints the folder.
yay_release_bundle() {
  local v="" replace="" pairs="" a root slug dir e z sha bytes files
  for a in "$@"; do
    case "$a" in --replace) replace=1 ;; *=*) pairs="$pairs $a" ;; -*) yay_die "usage: yayh release bundle <version> <edition>=<zip>... [--replace]" ;; *) v="$a" ;; esac
  done
  [ -n "$v" ] && [ -n "$pairs" ] || yay_die "usage: yayh release bundle <version> <edition>=<zip>... [--replace]"
  root="$(yay_repo_root)"; slug="$(yay_config_get plugin.slug)"
  dir="$(_yay_bundle_root)/$slug-$v"
  if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    [ -n "$replace" ] || yay_die "${dir#"$root"/} already exists (pass --replace to rebuild it)"
    find "$dir" -maxdepth 1 -type f \( -name '*.zip' -o -name 'MANIFEST.txt' -o -name 'files-*.txt' \) -exec rm -f {} +
  fi
  mkdir -p "$dir"
  if ! git -C "$root" check-ignore -q "${dir#"$root"/}/MANIFEST.txt" 2>/dev/null; then
    yay_warn "${dir#"$root"/} isn't gitignored: add it (or release/) to .gitignore so bundles are never committed"
  fi
  {
    printf '%s %s\n' "$slug" "$v"
    printf 'commit: %s (%s)\n' "$(git -C "$root" rev-parse --short HEAD)" "$(git -C "$root" rev-parse --abbrev-ref HEAD)"
    printf 'built: %s\n\n' "$(date '+%Y-%m-%d %H:%M %Z')"
    printf 'edition\tfile\tbytes\tfiles\tsha256\n'
  } > "$dir/MANIFEST.txt"
  for a in $pairs; do
    e="${a%%=*}"; z="${a#*=}"; case "$z" in /*) ;; *) z="$root/$z" ;; esac
    [ -f "$z" ] || yay_die "no zip at $z"
    cp "$z" "$dir/"
    sha="$(_yay_sha256 "$z")"; bytes="$(wc -c < "$z" | tr -d ' ')"
    unzip -Z1 "$z" 2>/dev/null | grep -v '/$' > "$dir/files-$e.txt" || true
    files="$(grep -c . "$dir/files-$e.txt" || true)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$e" "$(basename "$z")" "$bytes" "$files" "$sha" >> "$dir/MANIFEST.txt"
  done
  printf '%s\n' "$dir"
}

# ---------- UI check: the built zip in its own wp-env site ----------
# The e2e site maps the source checkout as the plugin folder, so installing a zip
# there would overwrite the source. This site lives outside the working tree, in
# <git-common-dir>/yay-release-site/, maps the extracted zip, and has its own port.

_yay_ui_site_dir() {
  local d; d="$(git -C "$(yay_repo_root)" rev-parse --git-common-dir)"
  case "$d" in /*) ;; *) d="$(yay_repo_root)/$d" ;; esac
  printf '%s/yay-release-site\n' "$(cd "$d" && pwd -P)"
}
_yay_ui_port() { yay_config_get release.uiPort 2>/dev/null || printf '%s\n' "$(( $(yay_e2e_base_port) + 4 ))"; }
_yay_ui_wpenv() {
  local bin; bin="$(yay_repo_root)/$(yay_e2e_dir)/node_modules/.bin/wp-env"
  [ -x "$bin" ] || return 1
  printf '%s\n' "$bin"
}

# yay_release_ui <zip> out=<dir> [edition=e] [--keep]
# Start the site with the zip, drive the plugins page (activate, every row action
# and meta link, deactivate), screenshot each step into <dir>, and scan debug.log.
# Exit 0 = PASS lines only, 1 = a FAIL, 3 = can't run (no e2e setup, no Docker).
yay_release_ui() {
  local zip="" out="" edition="" keep="" a root e2e site port url wpenv tmp top main folder
  for a in "$@"; do
    case "$a" in
      out=*) out="${a#out=}" ;; edition=*) edition="${a#edition=}" ;; --keep) keep=1 ;;
      -*|*=*) yay_die "usage: yayh release ui <zip> out=<dir> [edition=e] [--keep]" ;;
      *) zip="$a" ;;
    esac
  done
  [ -n "$zip" ] && [ -n "$out" ] || yay_die "usage: yayh release ui <zip> out=<dir> [edition=e] [--keep]"
  root="$(yay_repo_root)"; case "$zip" in /*) ;; *) zip="$root/$zip" ;; esac
  case "$out" in /*) ;; *) out="$root/$out" ;; esac
  [ -f "$zip" ] || yay_die "no zip at $zip"
  e2e="$root/$(yay_e2e_dir)"
  if [ ! -f "$e2e/.wp-env.json" ] || ! wpenv="$(_yay_ui_wpenv)" || [ ! -x "$e2e/node_modules/.bin/playwright" ]; then
    printf 'SKIP\tui\tno e2e setup with wp-env and Playwright installed (run /yay:e2e-init, then yayh run e2e-install)\n'; return 3
  fi
  [ "$(_e2e_docker)" = running ] || { printf 'SKIP\tui\tDocker is not running\n'; return 3; }
  command -v node >/dev/null 2>&1 || { printf 'SKIP\tui\tnode is not installed\n'; return 3; }

  site="$(_yay_ui_site_dir)"; port="$(_yay_ui_port)"; url="http://localhost:$port"
  mkdir -p "$site/plugin" "$out"
  # Refresh the plugin folder in place: a running site has it bind-mounted, and
  # deleting the folder breaks the mount.
  local x; x="$(mktemp -d)"
  unzip -q "$zip" -d "$x" || { rm -rf "$x"; printf 'FAIL\tui\tcannot extract %s\n' "$zip"; return 1; }
  top="$(ls "$x" | sed -n 1p)"
  mkdir -p "$site/plugin/$top"
  find "$site/plugin/$top" -mindepth 1 -delete
  cp -R "$x/$top/." "$site/plugin/$top/"
  rm -rf "$x"
  main="$(cd "$site/plugin/$top" && grep -l -E '^[[:space:]/*#@]*Plugin Name:' ./*.php 2>/dev/null | sed -n 1p | sed 's|^\./||')"
  [ -n "$main" ] || { printf 'FAIL\tui\tno PHP file with a Plugin Name header at the top of %s/\n' "$top"; return 1; }
  folder="$top"

  # The e2e site's .wp-env.json, with the source mapping swapped for the zip.
  E2E_ENV="$e2e/.wp-env.json" SITE="$site" FOLDER="$folder" PORT="$port" node -e '
    const fs = require("fs"); const c = JSON.parse(fs.readFileSync(process.env.E2E_ENV, "utf8"));
    const f = process.env.FOLDER, key = "wp-content/plugins/" + f;
    c.mappings = Object.fromEntries(Object.entries(c.mappings || {}).filter(([k]) => !k.startsWith("wp-content/plugins/" + f)));
    c.mappings[key] = "./plugin/" + f;
    c.plugins = (c.plugins || []).filter(p => !/^\.\.?(\/|$)/.test(p) && !String(p).endsWith("/" + f));
    delete c.lifecycleScripts; delete c.env;
    c.port = Number(process.env.PORT); c.testsEnvironment = false;
    c.config = Object.assign({}, c.config, { WP_DEBUG: true, WP_DEBUG_LOG: true, WP_DEBUG_DISPLAY: false });
    fs.writeFileSync(process.env.SITE + "/.wp-env.json", JSON.stringify(c, null, 2));
  ' || { printf 'FAIL\tui\tcannot write the release site config from %s\n' "$e2e/.wp-env.json"; return 1; }

  if ! (cd "$site" && WP_ENV_PORT="$port" WP_ENV_TESTS_PORT="$((port + 1))" "$wpenv" start >"$out/wp-env.log" 2>&1); then
    printf 'FAIL\tui\twp-env could not start the release site (see %s)\n' "$out/wp-env.log"; return 1
  fi
  local i=0 code
  while :; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url/wp-login.php" 2>/dev/null || true)"
    case "$code" in 2??|3??) break ;; esac
    i=$((i + 1)); [ "$i" -le 30 ] || { printf 'FAIL\tui\tthe release site did not answer at %s\n' "$url"; return 1; }
    sleep 2
  done
  _yay_ui_cli() { (cd "$site" && "$wpenv" run cli "$@" 2>/dev/null); }
  _yay_ui_cli wp plugin deactivate "$folder/$main" >/dev/null || true
  _yay_ui_cli wp eval 'if ( file_exists( WP_CONTENT_DIR . "/debug.log" ) ) { unlink( WP_CONTENT_DIR . "/debug.log" ); }' >/dev/null || true

  tmp="$e2e/.yay-release"
  rm -rf "$tmp"; mkdir -p "$tmp"
  cp "$YAY_KIT_ROOT/templates/release/playwright.config.ts" "$YAY_KIT_ROOT/templates/release/plugins-page.spec.ts" "$tmp/"
  local rc=0
  (cd "$e2e" && YAY_UI_URL="$url" YAY_UI_OUT="$out" YAY_PLUGIN_FILE="$folder/$main" \
     ./node_modules/.bin/playwright test -c .yay-release/playwright.config.ts >"$out/playwright.log" 2>&1) || rc=$?
  rm -rf "$tmp"

  if [ -f "$out/ui-check.tsv" ]; then cat "$out/ui-check.tsv"
  else printf 'FAIL\tui\tthe plugins-page check produced no results (see %s)\n' "$out/playwright.log"; rc=1; fi
  [ "$rc" -eq 0 ] || grep -q '^FAIL' "$out/ui-check.tsv" 2>/dev/null || printf 'FAIL\tui\tPlaywright failed (see %s)\n' "$out/playwright.log"

  local log
  log="$(_yay_ui_cli wp eval 'echo @file_get_contents( WP_CONTENT_DIR . "/debug.log" );' || true)"
  printf '%s\n' "$log" > "$out/debug.log"
  local mine; mine="$(printf '%s\n' "$log" | { grep -F "/$folder/" || true; })"
  printf '%s\n' "$mine" | { grep -E 'PHP (Fatal|Parse) error' || true; } | sed -n '1,5p' | sed 's/^/FAIL	php-log	/'
  printf '%s\n' "$mine" | { grep -E 'PHP (Warning|Notice|Deprecated)' || true; } | sed -n '1,5p' | sed 's/^/WARN	php-log	/'
  printf '%s' "$mine" | grep -qE 'PHP (Warning|Notice|Deprecated|Fatal|Parse)' || printf 'PASS\tphp-log\tno PHP errors, warnings or notices from %s/ in debug.log\n' "$folder"
  printf 'INFO\tscreenshots\t%s\n' "$out"
  if [ -n "$keep" ]; then printf 'INFO\tsite\t%s (admin / password), stop with: yayh release ui-stop\n' "$url"
  else (cd "$site" && "$wpenv" stop >/dev/null 2>&1) || true; fi
  if [ "$rc" -ne 0 ] || printf '%s' "$mine" | grep -qE 'PHP (Fatal|Parse) error' || grep -q '^FAIL' "$out/ui-check.tsv" 2>/dev/null; then return 1; fi
  return 0
}

yay_release_ui_stop() {
  local site wpenv; site="$(_yay_ui_site_dir)"
  [ -f "$site/.wp-env.json" ] || { echo "no release site"; return 0; }
  wpenv="$(_yay_ui_wpenv)" || yay_die "wp-env isn't installed in $(yay_e2e_dir)"
  (cd "$site" && "$wpenv" stop)
}
