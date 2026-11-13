# shellcheck shell=bash
# `yayh wporg site`: the WordPress.org review's runtime checks, run on the same
# throwaway site as `release ui` (lib/bundle.sh) with the built zip installed.
# One line per check, PASS|WARN|FAIL|SKIP <TAB> <checklist ID> <TAB> <detail>,
# also written to <out>/site.tsv. The IDs are skills/wporg/references/checklist.md's.

# _yay_wporg_below <x.y> -> the minor before it (6.5 -> 6.4, 6.0 -> 5.9)
_yay_wporg_below() {
  local ma mi; ma="${1%%.*}"; mi="${1#*.}"; [ "$mi" != "$1" ] || mi=0; mi="${mi%%.*}"
  case "$ma:$mi" in *[!0-9:]*|:*|*:) return 1 ;; esac
  if [ "$mi" -gt 0 ]; then printf '%s.%s\n' "$ma" $((mi - 1)); else printf '%s.9\n' $((ma - 1)); fi
}

# _yay_wporg_get <path> <body-file> [cookie-jar] -> HTTP status of $url<path>
_yay_wporg_get() {
  if [ -n "${3:-}" ]; then curl -s -o "$2" -w '%{http_code}' --max-time 30 -b "$3" "$url$1" 2>/dev/null || true
  else curl -s -o "$2" -w '%{http_code}' --max-time 30 "$url$1" 2>/dev/null || true; fi
}

# _yay_wporg_page <status> <body-file> -> ok | fatal | output (bytes before the page) | empty
_yay_wporg_page() {
  case "$1" in 5??) echo fatal; return ;; esac
  grep -q 'There has been a critical error' "$2" 2>/dev/null && { echo fatal; return; }
  local first; first="$(head -c 400 "$2" 2>/dev/null | tr -d '[:space:]' | cut -c1)"
  case "$first" in '') echo empty ;; '<') echo ok ;; *) echo output ;; esac
}

# _yay_wporg_notices <html> -> the admin notice lines, core's update nag left out
_yay_wporg_notices() { { grep -E '<div[^>]*class="[^"]*(notice|error|updated)' "$1" 2>/dev/null || true; } | { grep -v 'update-nag' || true; } | sed 's/^[[:space:]]*//' | sort -u; }

# _yay_wporg_pcp_rows <csv> -> "<TYPE>\t<file>:<line> <code> (<type>): <message>" per Plugin Check row
_yay_wporg_pcp_rows() {
  awk -F, '/^FILE: /{ f = substr($0, 7); next }
    $1 ~ /^"?[0-9]+"?$/ && NF >= 5 { m = $5; for (i = 6; i <= NF; i++) m = m "," $i
      gsub(/"/, "", $1); gsub(/"/, "", $3); gsub(/"/, "", $4); gsub(/^"|"$/, "", m); gsub(/""/, "\"", m)
      printf "%s\t%s:%s %s (%s): %s\n", $3, f, $1, $4, tolower($3), m }' "$1" 2>/dev/null
}

# yay_wporg_site <zip> out=<dir> [--keep] [--no-pcp]
# T1 Plugin Check, Q11 clean activation, Q7 lifecycle, Q6 debug.log, Q10 runtime
# requirements. Exit 0 = no FAIL, 1 = a FAIL, 3 = can't run (no e2e setup, no Docker).
yay_wporg_site() {
  local zip="" out="" keep="" pcp=1 a root site wpenv url folder main rc=0 usage
  usage="usage: yayh wporg site <zip> out=<dir> [--keep] [--no-pcp]"
  for a in "$@"; do
    case "$a" in
      out=*) out="${a#out=}" ;; --keep) keep=1 ;; --no-pcp) pcp="" ;;
      -*|*=*) yay_die "$usage" ;;
      *) zip="$a" ;;
    esac
  done
  [ -n "$zip" ] && [ -n "$out" ] || yay_die "$usage"
  root="$(yay_repo_root)"; case "$zip" in /*) ;; *) zip="$root/$zip" ;; esac
  case "$out" in /*) ;; *) out="$root/$out" ;; esac
  [ -f "$zip" ] || yay_die "no zip at $zip"
  mkdir -p "$out"; : > "$out/site.tsv"
  _w() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" | tee -a "$out/site.tsv"; }

  _yay_ui_site_up "$zip" "$out" site >"$out/.site-up" || rc=$?
  tee -a "$out/site.tsv" < "$out/.site-up"; rm -f "$out/.site-up"
  [ "$rc" -eq 0 ] || return "$rc"

  local opts0 tabs0 jar="$out/.cookies" s
  opts0="$(_yay_ui_cli wp option list --field=option_name | sort -u)" || true
  tabs0="$(_yay_ui_cli wp db tables --all-tables-with-prefix | sort -u)" || true

  # T1: Plugin Check from WordPress.org, plugin_repo errors block the upload.
  if [ -z "$pcp" ]; then _w SKIP T1 "--no-pcp: the upload gate didn't run; run Tools → Plugin Check by hand"
  elif ! _yay_ui_cli wp plugin install plugin-check --activate >"$out/plugin-check-install.log"; then
    _w SKIP T1 "Plugin Check couldn't be installed from WordPress.org (offline?): the upload gate didn't run; run Tools → Plugin Check by hand"
  else
    _yay_ui_cli wp plugin check "$folder" --categories=plugin_repo --format=csv --fields=line,column,type,code,message >"$out/plugin-check-repo.csv" || true
    _yay_ui_cli wp plugin check "$folder" --format=csv --fields=line,column,type,code,message >"$out/plugin-check.csv" || true
    if ! grep -qE '^FILE: |^Success: ' "$out/plugin-check-repo.csv" "$out/plugin-check.csv" 2>/dev/null; then
      _w SKIP T1 "Plugin Check didn't run (see $out/plugin-check.csv): run Tools → Plugin Check by hand"
    else
      local errs warns n
      errs="$(_yay_wporg_pcp_rows "$out/plugin-check-repo.csv" | { grep '^ERROR' || true; } | cut -f2-)" || true
      warns="$(_yay_wporg_pcp_rows "$out/plugin-check.csv" | cut -f2- | { grep -vxF -e "$errs" || true; })" || true
      [ -n "$errs" ] || warns="$(_yay_wporg_pcp_rows "$out/plugin-check.csv" | cut -f2-)" || true
      if [ -n "$errs" ]; then
        printf '%s\n' "$errs" | sed -n '1,20p' | while IFS= read -r s; do _w FAIL T1 "plugin_repo: $s"; done
        n="$(printf '%s\n' "$errs" | grep -c .)"; [ "$n" -le 20 ] || _w INFO T1 "$n plugin_repo errors in all, see $out/plugin-check-repo.csv"
      else _w PASS T1 "Plugin Check plugin_repo: no errors"; fi
      if [ -n "$warns" ]; then
        printf '%s\n' "$warns" | sed -n '1,20p' | while IFS= read -r s; do _w WARN T1 "$s"; done
        n="$(printf '%s\n' "$warns" | grep -c .)"; [ "$n" -le 20 ] || _w INFO T1 "$n more results from the full run, see $out/plugin-check.csv"
      fi
    fi
    _yay_ui_cli wp plugin deactivate plugin-check >/dev/null || true
    _yay_ui_cli wp plugin delete plugin-check >/dev/null || true
  fi

  # Q11: activation prints nothing, and the front end and wp-admin/ answer cleanly.
  local act extra page ok=1
  # stderr too: WP-CLI reports "unexpected output" there, wp-env its spinner lines.
  act="$( (cd "$site" && "$wpenv" run cli wp plugin activate "$folder/$main") 2>&1 )" || ok=""
  extra="$(printf '%s\n' "$act" | { grep -vE "^Plugin '.*' activated\.$|^Success: |^(ℹ|✔|✖) |^Command failed with exit code|^[[:space:]]*$" || true; } | tr '\n' ' ' | cut -c1-240)"
  if [ -n "$ok" ] && [ -z "$extra" ]; then _w PASS Q11 "wp plugin activate printed nothing"
  elif _yay_ui_cli wp plugin is-active "$folder/$main" >/dev/null; then _w FAIL Q11 "activation printed output: $extra"
  else _w FAIL Q11 "wp plugin activate $folder/$main failed, so the checks below ran with it inactive: $extra"; fi
  s="$(_yay_wporg_get / "$out/q11-front.html")"; page="$(_yay_wporg_page "$s" "$out/q11-front.html")"
  case "$page" in
    ok) _w PASS Q11 "front page answers $s with the plugin active" ;;
    fatal) _w FAIL Q11 "front page fatals with the plugin active ($s, see $out/q11-front.html)" ;;
    *) _w FAIL Q11 "front page: $page before the page markup ($s, see $out/q11-front.html)" ;;
  esac
  curl -s -o /dev/null -c "$jar" -b 'wordpress_test_cookie=WP%20Cookie%20check' --max-time 30 \
    --data-urlencode log=admin --data-urlencode pwd=password -d testcookie=1 "$url/wp-login.php" 2>/dev/null || true
  s="$(_yay_wporg_get /wp-admin/ "$out/q11-admin.html" "$jar")"; page="$(_yay_wporg_page "$s" "$out/q11-admin.html")"
  case "$s:$page" in
    3??:*) _w WARN Q11 "couldn't log in to check wp-admin/ (it answered $s)" ;;
    *:ok) _w PASS Q11 "wp-admin/ answers $s with the plugin active" ;;
    *:fatal) _w FAIL Q11 "wp-admin/ fatals with the plugin active ($s, see $out/q11-admin.html)" ;;
    *) _w FAIL Q11 "wp-admin/: $page before the page markup ($s, see $out/q11-admin.html)" ;;
  esac

  # Q7: deactivate and uninstall (keeping the mapped folder), then look for what's left.
  local pre opts1 tabs1 left
  pre="$(printf '%s' "$folder" | tr 'A-Z-' 'a-z_')"
  if ! _yay_ui_cli wp plugin deactivate "$folder/$main" >/dev/null; then _w FAIL Q7 "wp plugin deactivate $folder/$main failed"
  elif ! _yay_ui_cli wp plugin uninstall "$folder/$main" --skip-delete >"$out/q7-uninstall.log"; then _w FAIL Q7 "wp plugin uninstall failed (see $out/q7-uninstall.log)"
  else
    opts1="$(_yay_ui_cli wp option list --field=option_name | sort -u)" || true
    tabs1="$(_yay_ui_cli wp db tables --all-tables-with-prefix | sort -u)" || true
    left="$( { comm -13 <(printf '%s\n' "$opts0") <(printf '%s\n' "$opts1") \
                 | { grep -vE '^(_site)?_transient_|^theme_mods_|^(cron|recently_activated|uninstall_plugins|active_plugins|rewrite_rules|can_compress_scripts|auto_updater\.lock)$' || true; }
               printf '%s\n' "$opts1" | { grep -iF -e "$pre" -e "$folder" || true; }
               comm -13 <(printf '%s\n' "$tabs0") <(printf '%s\n' "$tabs1")
               printf '%s\n' "$tabs1" | { grep -iF -e "$pre" -e "$folder" || true; }; } | { grep . || true; } | sort -u)"
    if [ -n "$left" ]; then _w WARN Q7 "uninstall left $(printf '%s\n' "$left" | grep -c .) options or tables: $(printf '%s\n' "$left" | sed -n '1,8p' | paste -sd' ' -) (fine only if keeping data is deliberate and the readme says so)"
    else _w PASS Q7 "activate, deactivate and uninstall leave no options or tables behind"; fi
  fi

  # Q6: PHP errors, warnings and notices from the plugin's folder so far.
  _yay_ui_log_scan "$out" "$folder" Q6 | tee -a "$out/site.tsv" || true

  # Q10: WordPress older than Requires at least, forced from a mu-plugin: no fatal, and a notice.
  local req old mu="yay-wporg-q10.php"
  req="$(sed -n 's/^[[:space:]/*#@]*Requires at least:[[:space:]]*//p' "$site/plugin/$folder/$main" | sed -n 1p | tr -d '\r ')" || true
  if [ -z "$req" ] || ! old="$(_yay_wporg_below "$req")"; then _w SKIP Q10 "no usable Requires at least header in $main"
  else
    _yay_ui_cli wp plugin activate "$folder/$main" >/dev/null || true
    _yay_ui_cli wp eval 'wp_mkdir_p( WPMU_PLUGIN_DIR ); file_put_contents( WPMU_PLUGIN_DIR . "/'"$mu"'", "<?php " . chr( 36 ) . "GLOBALS[" . chr( 39 ) . "wp_version" . chr( 39 ) . "] = " . chr( 39 ) . "'"$old"'" . chr( 39 ) . ";" );' >/dev/null || true
    s="$(_yay_wporg_get /wp-admin/ "$out/q10-admin.html" "$jar")"; page="$(_yay_wporg_page "$s" "$out/q10-admin.html")"
    _yay_ui_cli wp --skip-plugins --skip-themes eval 'if ( file_exists( WPMU_PLUGIN_DIR . "/'"$mu"'" ) ) { unlink( WPMU_PLUGIN_DIR . "/'"$mu"'" ); }' >/dev/null || true
    if [ "$page" = fatal ]; then _w FAIL Q10 "wp-admin/ fatals when WordPress is $old (Requires at least $req): check the version at runtime and stop with a notice"
    elif [ -n "$(comm -13 <(_yay_wporg_notices "$out/q11-admin.html") <(_yay_wporg_notices "$out/q10-admin.html"))" ]; then
      _w PASS Q10 "with WordPress $old (Requires at least $req) the admin loads and shows a notice"
    else _w WARN Q10 "no notice when WordPress is $old (Requires at least $req): check the version at runtime, show a notice and stop (see $out/q10-admin.html)"; fi
  fi

  rm -f "$jar"
  if [ -n "$keep" ]; then _w INFO site "$url (admin / password), stop with: yayh release ui-stop"
  else (cd "$site" && "$wpenv" stop >/dev/null 2>&1) || true; fi
  ! grep -q '^FAIL' "$out/site.tsv"
}
