# shellcheck shell=bash
# woo-check: the QIT-style static checks of /yay:woo-check, run locally on the built zip.
# Tools are pinned in skills/woo-check/tools/ and installed into the kit cache, never into a plugin.
# Rows and IDs: skills/woo-check/scripts/woocheck.py and references/checklist.md.

_yay_wc_kit() { printf '%s/skills/woo-check\n' "$YAY_KIT_ROOT"; }
_yay_wc_py() { python3 -I "$(_yay_wc_kit)/scripts/woocheck.py" "$@"; }

# yay_woocheck_cache -> the tool folder for this kit's composer.lock (a new lock, a new folder).
yay_woocheck_cache() {
  local base h
  base="${YAY_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/yay}"
  h="$(yay_sha256 < "$(_yay_wc_kit)/tools/composer.lock" | cut -c1-12)"
  printf '%s/woo-check/%s\n' "$base" "$h"
}

_yay_wc_platform() { # -> "<os> <arch>" as gitleaks.tsv names them
  local os arch
  case "$(uname -s)" in Darwin) os=darwin ;; Linux) os=linux ;; *) os="$(uname -s | tr '[:upper:]' '[:lower:]')" ;; esac
  case "$(uname -m)" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; *) arch="$(uname -m)" ;; esac
  printf '%s %s\n' "$os" "$arch"
}

_yay_wc_lock_version() { # composer package -> its locked version
  python3 -I -c 'import json,sys
for p in json.load(open(sys.argv[1]))["packages"]:
    if p["name"] == sys.argv[2]: print(p["version"].lstrip("v"))' "$(_yay_wc_kit)/tools/composer.lock" "$1"
}

_yay_wc_bin() { # tool -> path in the cache (may not exist)
  local c; c="$(yay_woocheck_cache)"
  case "$1" in
    phpcs) printf '%s/vendor/bin/phpcs\n' "$c" ;;
    phpstan) printf '%s/vendor/bin/phpstan\n' "$c" ;;
    gitleaks) printf '%s/bin/gitleaks\n' "$c" ;;
  esac
}

# yay_woocheck_tools [--install] -> TSV: tool, pinned version, ok|missing, path.
yay_woocheck_tools() {
  local install="" a c os arch line ver url sum tmp t v
  for a in "$@"; do case "$a" in --install) install=1 ;; *) yay_die "usage: yayh woo-check tools [--install]" ;; esac; done
  command -v python3 >/dev/null 2>&1 || yay_die "woo-check needs python3 (brew install python3)"
  c="$(yay_woocheck_cache)"
  read -r os arch < <(_yay_wc_platform)
  line="$(awk -F'\t' -v o="$os" -v a="$arch" '!/^#/ && $2 == o && $3 == a { print; exit }' "$(_yay_wc_kit)/tools/gitleaks.tsv")"
  if [ -n "$install" ]; then
    if [ ! -x "$c/vendor/bin/phpcs" ] || [ ! -x "$c/vendor/bin/phpstan" ]; then
      command -v php >/dev/null 2>&1 || yay_die "woo-check tools need php on PATH (brew install php)"
      command -v composer >/dev/null 2>&1 || yay_die "woo-check tools need composer on PATH (brew install composer)"
      mkdir -p "$c"
      cp "$(_yay_wc_kit)/tools/composer.json" "$(_yay_wc_kit)/tools/composer.lock" "$c/"
      composer install --no-dev --no-interaction --no-progress --quiet --working-dir="$c" >&2 \
        || yay_die "composer install of the woo-check tools failed (offline?); nothing is checked without them"
    fi
    if [ ! -x "$c/bin/gitleaks" ]; then
      [ -n "$line" ] || yay_die "no pinned gitleaks for $os $arch in tools/gitleaks.tsv"
      url="$(printf '%s' "$line" | cut -f4)"; sum="$(printf '%s' "$line" | cut -f5)"
      mkdir -p "$c/bin"; tmp="$c/bin/.gitleaks.tar.gz"
      curl -fsSL --max-time 120 -o "$tmp" "$url" || { rm -f "$tmp"; yay_die "couldn't download gitleaks from $url"; }
      if [ "$(yay_sha256 < "$tmp")" != "$sum" ]; then rm -f "$tmp"; yay_die "gitleaks download doesn't match its pinned sha256; deleted it"; fi
      tar -xzf "$tmp" -C "$c/bin" gitleaks && rm -f "$tmp" && chmod +x "$c/bin/gitleaks"
    fi
  fi
  for t in phpcs phpstan gitleaks; do
    case "$t" in
      phpcs) v="$(_yay_wc_lock_version squizlabs/php_codesniffer)" ;;
      phpstan) v="$(_yay_wc_lock_version phpstan/phpstan)" ;;
      gitleaks) v="$(printf '%s' "$line" | cut -f1)" ;;
    esac
    if [ -x "$(_yay_wc_bin "$t")" ]; then printf '%s\t%s\tok\t%s\n' "$t" "$v" "$(_yay_wc_bin "$t")"
    else printf '%s\t%s\tmissing\t%s\n' "$t" "$v" "$(_yay_wc_bin "$t")"; fi
  done
}

_yay_wc_skip() { # out ids... reason (last arg)
  local out="$1" reason id; shift; reason="${*: -1}"
  for id in "${@:1:$#-1}"; do printf 'SKIP\t%s\t-\t0\t-\t%s\n' "$id" "$reason" >> "$out/findings.tsv"; done
}
_yay_wc_ran() { # out tool ids...
  local out="$1" tool="$2" id; shift 2
  for id in "$@"; do printf 'INFO\t%s\t-\t0\t%s\tran %s\n' "$id" "$tool" "$tool" >> "$out/findings.tsv"; done
}
_yay_wc_convert() { # out tool json root
  _yay_wc_py convert "$2" "$3" --root "$4" --lib "$YAY_WC_LIBS" | sed '/^$/d' >> "$1/findings.tsv"
}

# _yay_wc_libs -> the repo's generatedPaths folders (vendor-prefixed/…) as "a/,b/": library code,
# like vendor/, so PHPCS and PHPStan don't report on it and MAL1 there is a WARN.
_yay_wc_libs() {
  yay_config_get generatedPaths 2>/dev/null | awk '/\/$/ && $0 != "vendor/" && $0 != "node_modules/" { printf "%s%s", sep, $0; sep = "," }' || true
}

_yay_wc_header() { # file header -> value
  sed -n "1,80{s/^[ \\t/*#@]*$2:[[:space:]]*//p;}" "$1" 2>/dev/null | sed -n '1{s/\r$//;p;}'
}

_yay_wc_baseline_file() { printf '%s/.yay/woo-check-baseline.tsv\n' "$(yay_repo_root)"; }

# yay_woocheck_static <zip|dir> out=<dir> [repo=<root>] [--only=sec,stan,cmp,mal,val]
# Writes findings.tsv, areas.tsv and raw/ in out; prints areas.tsv.
# Exit 0, 1 when SEC or MAL is Failed, 3 when nothing could run.
yay_woocheck_static() {
  local src="" out="" repo="" only="sec,stan,cmp,mal,val" a dir main php wcreq wctest wclatest level bin rs
  for a in "$@"; do
    case "$a" in
      out=*) out="${a#out=}" ;; repo=*) repo="${a#repo=}" ;; --only=*) only="${a#--only=}" ;;
      -*) yay_die "unknown option $a" ;;
      *) [ -z "$src" ] || yay_die "one zip or folder only"; src="$a" ;;
    esac
  done
  [ -n "$src" ] && [ -n "$out" ] || yay_die "usage: yayh woo-check static <zip|dir> out=<dir> [repo=<root>] [--only=sec,stan,cmp,mal,val]"
  [ -e "$src" ] || yay_die "no such zip or folder: $src"
  command -v python3 >/dev/null 2>&1 || yay_die "woo-check needs python3 (brew install python3)"
  _on() { case ",$only," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
  [ -n "$repo" ] || repo="$(yay_repo_root 2>/dev/null || pwd)"
  mkdir -p "$out"; out="$(cd "$out" && pwd -P)"
  rm -rf "$out/src" "$out/raw" "$out/findings.tsv"; mkdir -p "$out/raw"; : > "$out/findings.tsv"

  if [ -d "$src" ]; then dir="$(cd "$src" && pwd -P)"
  else
    mkdir -p "$out/src"; unzip -q "$src" -d "$out/src" || yay_die "can't unzip $src"
    rm -rf "$out/src/__MACOSX"; dir="$out/src"
    if [ "$(find "$out/src" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ] && [ -d "$(find "$out/src" -mindepth 1 -maxdepth 1)" ]; then
      dir="$(find "$out/src" -mindepth 1 -maxdepth 1)"
    fi
  fi
  main=""; for a in "$dir"/*.php; do grep -qE '^[ \t/*#@]*Plugin Name:' "$a" 2>/dev/null && { main="$a"; break; }; done
  php="$(yay_config_get requires.php 2>/dev/null || true)"
  [ -n "$php" ] || php="$(_yay_wc_header "$main" 'Requires PHP')"
  wcreq="$(yay_config_get requires.wc 2>/dev/null || true)"
  wctest="$(yay_config_get tested.wc 2>/dev/null || true)"
  level="$(yay_config_get wooCheck.phpstanLevel 2)"
  YAY_WC_LIBS="$(_yay_wc_libs)"
  local libx="" l
  for l in $(printf '%s' "$YAY_WC_LIBS" | tr ',' ' '); do libx="$libx  <exclude-pattern>$dir/${l%/}/*</exclude-pattern>
"; done
  wclatest="${YAY_WC_LATEST-}"
  if [ -z "${YAY_WC_LATEST+x}" ] && [ -z "${YAY_WOOCHECK_OFFLINE:-}" ]; then
    wclatest="$(curl -fsS --max-time 10 'https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request%5Bslug%5D=woocommerce&request%5Bfields%5D%5Bsections%5D=0' 2>/dev/null \
      | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true)"
  fi

  if _on sec || _on cmp; then
    bin="$(_yay_wc_bin phpcs)"
    if [ ! -x "$bin" ]; then
      _on sec && _yay_wc_skip "$out" SEC1 SEC2 "phpcs not installed: yayh woo-check tools --install"
      _on cmp && _yay_wc_skip "$out" CMP1 "phpcs not installed: yayh woo-check tools --install"
    else
      if _on sec; then
        rs="$out/raw/ruleset-security.xml"
        printf '%s\n' '<?xml version="1.0"?>' '<ruleset name="yay-woo-check-security">' '  <arg name="extensions" value="php"/>' \
          '  <exclude-pattern>*/vendor/*</exclude-pattern>' '  <exclude-pattern>*/node_modules/*</exclude-pattern>' \
          "${libx%?}" '  <rule ref="WordPress.Security"/>' '  <rule ref="WordPress.DB"/>' '</ruleset>' | sed '/^$/d' > "$rs"
        "$bin" -q --standard="$rs" --report=json --report-file="$out/raw/phpcs-sec.json" "$dir" >/dev/null 2>"$out/raw/phpcs-sec.err" || true
        if [ -s "$out/raw/phpcs-sec.json" ]; then _yay_wc_ran "$out" phpcs SEC1 SEC2; _yay_wc_convert "$out" phpcs-sec "$out/raw/phpcs-sec.json" "$dir"
        else _yay_wc_skip "$out" SEC1 SEC2 "phpcs failed: see raw/phpcs-sec.err"; fi
      fi
      if _on cmp; then
        rs="$out/raw/ruleset-compat.xml"
        printf '%s\n' '<?xml version="1.0"?>' '<ruleset name="yay-woo-check-compat">' '  <arg name="extensions" value="php"/>' \
          '  <exclude-pattern>*/vendor/*</exclude-pattern>' '  <exclude-pattern>*/node_modules/*</exclude-pattern>' \
          "${libx%?}" "  <config name=\"testVersion\" value=\"${php:-7.4}-\"/>" '  <rule ref="PHPCompatibilityWP"/>' '</ruleset>' | sed '/^$/d' > "$rs"
        "$bin" -q --standard="$rs" --report=json --report-file="$out/raw/phpcs-cmp.json" "$dir" >/dev/null 2>"$out/raw/phpcs-cmp.err" || true
        if [ -s "$out/raw/phpcs-cmp.json" ]; then _yay_wc_ran "$out" phpcs CMP1; _yay_wc_convert "$out" phpcs-cmp "$out/raw/phpcs-cmp.json" "$dir"
        else _yay_wc_skip "$out" CMP1 "phpcs failed: see raw/phpcs-cmp.err"; fi
      fi
    fi
  fi

  if _on stan; then
    bin="$(_yay_wc_bin phpstan)"
    if [ ! -x "$bin" ]; then _yay_wc_skip "$out" STAN1 "phpstan not installed: yayh woo-check tools --install"
    else
      local stubs; stubs="$(yay_woocheck_cache)/vendor/php-stubs/woocommerce-stubs"
      # Constants the plugin defines inside if ( ! defined() ): PHPStan sees them only from a stub.
      _yay_wc_py constants "$dir" --lib "$YAY_WC_LIBS" > "$out/raw/phpstan-constants.php"
      { printf 'parameters:\n  level: %s\n  tmpDir: %s\n  paths:\n    - %s\n' "$level" "$out/raw/phpstan-tmp" "$dir"
        printf '  excludePaths:\n    analyse:\n      - %s/vendor/*\n      - %s/node_modules/*\n' "$dir" "$dir"
        for l in $(printf '%s' "$YAY_WC_LIBS" | tr ',' ' '); do printf '      - %s/%s*\n' "$dir" "$l"; done
        printf '  scanFiles:\n    - %s\n' "$out/raw/phpstan-constants.php"
        for a in "$stubs/woocommerce-stubs.php" "$stubs/woocommerce-packages-stubs.php"; do [ -f "$a" ] && printf '    - %s\n' "$a"; done
        if grep -q "^define" "$out/raw/phpstan-constants.php"; then
          printf '  dynamicConstantNames:\n'; sed -n "s/^define( '\\([^']*\\)'.*/    - \\1/p" "$out/raw/phpstan-constants.php"
        fi
      } > "$out/raw/phpstan.neon"
      "$bin" analyse -c "$out/raw/phpstan.neon" --error-format=json --no-progress --memory-limit=1G \
        > "$out/raw/phpstan.json" 2>"$out/raw/phpstan.err" || true
      if grep -q '"totals"' "$out/raw/phpstan.json" 2>/dev/null; then _yay_wc_ran "$out" phpstan STAN1; _yay_wc_convert "$out" phpstan "$out/raw/phpstan.json" "$dir"
      else _yay_wc_skip "$out" STAN1 "phpstan failed: see raw/phpstan.err"; fi
    fi
  fi

  if _on sec; then
    if [ ! -f "$repo/composer.lock" ]; then _yay_wc_skip "$out" SEC3 "no composer.lock in the repo"
    elif ! command -v composer >/dev/null 2>&1; then _yay_wc_skip "$out" SEC3 "composer not on PATH (brew install composer)"
    else
      composer audit --no-dev --locked --format=json --no-interaction --working-dir="$repo" > "$out/raw/composer.json" 2>"$out/raw/composer.err" || true
      if [ -s "$out/raw/composer.json" ]; then _yay_wc_ran "$out" composer-audit SEC3; _yay_wc_convert "$out" composer "$out/raw/composer.json" "$dir"
      else _yay_wc_skip "$out" SEC3 "composer audit failed: see raw/composer.err"; fi
    fi
    local pm=""
    if [ -f "$repo/package-lock.json" ]; then pm=npm; elif [ -f "$repo/pnpm-lock.yaml" ]; then pm=pnpm; fi
    if [ -z "$pm" ]; then _yay_wc_skip "$out" SEC4 "no package-lock.json or pnpm-lock.yaml in the repo"
    elif ! command -v "$pm" >/dev/null 2>&1; then _yay_wc_skip "$out" SEC4 "$pm not on PATH"
    else
      if [ "$pm" = npm ]; then (cd "$repo" && npm audit --omit=dev --json) > "$out/raw/npm.json" 2>"$out/raw/npm.err" || true
      else (cd "$repo" && pnpm audit --prod --json) > "$out/raw/pnpm.json" 2>"$out/raw/pnpm.err" || true; fi
      if [ -s "$out/raw/$pm.json" ]; then _yay_wc_ran "$out" "$pm-audit" SEC4; _yay_wc_convert "$out" "$pm" "$out/raw/$pm.json" "$dir"
      else _yay_wc_skip "$out" SEC4 "$pm audit failed: see raw/$pm.err"; fi
    fi
    bin="$(_yay_wc_bin gitleaks)"
    if [ ! -x "$bin" ]; then _yay_wc_skip "$out" SEC5 "gitleaks not installed: yayh woo-check tools --install"
    else
      "$bin" dir "$dir" --config "$(_yay_wc_kit)/tools/gitleaks.toml" --report-format json --report-path "$out/raw/gitleaks.json" --no-banner --redact --exit-code 0 >/dev/null 2>"$out/raw/gitleaks.err" || true
      if [ -f "$out/raw/gitleaks.json" ]; then _yay_wc_ran "$out" gitleaks SEC5; _yay_wc_convert "$out" gitleaks "$out/raw/gitleaks.json" "$dir"
      else _yay_wc_skip "$out" SEC5 "gitleaks failed: see raw/gitleaks.err"; fi
    fi
  fi

  if _on mal || _on val; then
    _yay_wc_py scan "$dir" --lib "$YAY_WC_LIBS" --requires-wc "$wcreq" --tested-wc "$wctest" --wc-latest "$wclatest" > "$out/raw/woocheck.tsv"
    _on mal && { _yay_wc_ran "$out" woocheck.py MAL1; grep -E '^[A-Z]+	MAL' "$out/raw/woocheck.tsv" >> "$out/findings.tsv" || true; }
    _on val && { _yay_wc_ran "$out" woocheck.py VAL1; grep -E '^[A-Z]+	VAL' "$out/raw/woocheck.tsv" >> "$out/findings.tsv" || true; }
  fi

  printf '%s\n' "$dir" > "$out/plugin-dir.txt"
  yay_woocheck_baseline "$out" >/dev/null
  cat "$out/areas.tsv"
  if grep -qE '^(SEC|MAL)	Failed	' "$out/areas.tsv"; then return 1; fi
  if ! grep -qvE '	Skipped	' "$out/areas.tsv"; then return 3; fi
  return 0
}

# yay_woocheck_baseline <out> [--update]: mark baseline rows BASE in out/findings.tsv, rewrite
# out/areas.tsv, print GONE rows (in the baseline, no longer found); --update rewrites the
# repo's .yay/woo-check-baseline.tsv from out (never with SEC5 or MAL2) and prints KEPT rows.
yay_woocheck_baseline() {
  local out="" upd="" a f
  for a in "$@"; do case "$a" in --update) upd=--update ;; -*) yay_die "unknown option $a" ;; *) out="$a" ;; esac; done
  [ -n "$out" ] && [ -f "$out/findings.tsv" ] || yay_die "usage: yayh woo-check baseline <out dir of a static run> [--update]"
  f="$(_yay_wc_baseline_file)"
  [ -z "$upd" ] || mkdir -p "$(dirname "$f")"
  _yay_wc_py baseline "$out/findings.tsv" "$f" ${upd:+"$upd"} | tee "$out/gone.tsv"
  _yay_wc_py areas "$out/findings.tsv" > "$out/areas.tsv"
}
