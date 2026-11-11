#!/usr/bin/env bash
# e2e: browser tests with Playwright against a wp-env (Docker) WordPress site.
# One site per checkout: the main checkout uses the plugin's base port, each
# worktree gets its own port, so parallel features never share a database.
# Contract: reference/e2e.md. Commands live in .yay/config.json (commands.e2e*).

YAY_E2E_TEMPLATES="${YAY_KIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/templates/e2e"

yay_e2e_dir() { yay_config_get e2e.dir 2>/dev/null || echo tests/e2e; }

# 0 when the repo root is the main checkout (not a linked worktree).
_e2e_main_checkout() {
  local root gd cd
  root="$(yay_repo_root)"
  gd="$(cd "$root" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || return 0
  cd="$(cd "$root" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || return 0
  [ "$gd" = "$cd" ]
}

_e2e_cksum() { printf '%s' "$1" | cksum | cut -d' ' -f1; }

# Stable per plugin (CI and every developer agree): 8900-9890, step 10.
yay_e2e_base_port() {
  local p
  p="$(yay_config_get e2e.port 2>/dev/null || true)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; return; fi
  printf '%s\n' "$((8900 + ($(_e2e_cksum "$(yay_config_get plugin.slug)") % 100) * 10))"
}

# This checkout's port: YAY_E2E_PORT, else the base port in the main checkout,
# else 10000-13998 (even) from the worktree path. wp-env also takes port+1.
yay_e2e_port() {
  if [ -n "${YAY_E2E_PORT:-}" ]; then printf '%s\n' "$YAY_E2E_PORT"; return; fi
  if _e2e_main_checkout; then yay_e2e_base_port; return; fi
  printf '%s\n' "$((10000 + ($(_e2e_cksum "$(cd "$(yay_repo_root)" && pwd -P)") % 2000) * 2))"
}

# e2e.baseUrl (an external site that yayh doesn't manage) or the wp-env URL.
yay_e2e_url() {
  local u; u="$(yay_config_get e2e.baseUrl 2>/dev/null || true)"
  if [ -n "$u" ]; then printf '%s\n' "${u%/}"; return; fi
  printf 'http://localhost:%s\n' "$(yay_e2e_port)"
}

_e2e_external() { [ -n "$(yay_config_get e2e.baseUrl 2>/dev/null || true)" ]; }

yay_e2e_up() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$(yay_e2e_url)/" 2>/dev/null || true)"
  case "$code" in 2??|3??) return 0 ;; esac
  return 1
}

_e2e_docker() { # running | stopped | missing
  command -v docker >/dev/null 2>&1 || { echo missing; return; }
  if docker info >/dev/null 2>&1; then echo running; else echo stopped; fi
}

# Run commands.<name> with this checkout's port and URL exported, extra
# arguments appended (shell-quoted).
_e2e_exec() {
  local name="$1" app="" a port url
  shift
  for a in "$@"; do app="$app $(printf '%q' "$a")"; done
  port="$(yay_e2e_port)"; url="$(yay_e2e_url)"
  (
    export WP_ENV_PORT="$port" WP_ENV_TESTS_PORT="$((port + 1))" E2E_BASE_URL="$url" WP_BASE_URL="$url"
    YAY_RUN_APPEND="${app# }" yay_run "$name"
  )
}

_e2e_need_setup() {
  yay_config_get commands.e2e >/dev/null 2>&1 || yay_die "e2e is not set up here (no commands.e2e): run /yay:e2e-init"
}

# yay_e2e_env start|stop|reset
yay_e2e_env() {
  local sub="${1:-}"
  case "$sub" in start|stop|reset) ;; *) yay_die "usage: yayh e2e env start|stop|reset" ;; esac
  _e2e_need_setup
  if _e2e_external; then echo "e2e.baseUrl is set ($(yay_e2e_url)): that site is managed outside yayh, nothing to $sub"; return 0; fi
  [ "$(_e2e_docker)" = running ] || yay_die "Docker isn't running (wp-env needs it). Start Docker Desktop, then retry."
  _e2e_exec "e2e-$sub"
  if [ "$sub" != stop ]; then
    local i=0
    while ! yay_e2e_up; do
      i=$((i + 1)); [ "$i" -le 30 ] || yay_die "the site didn't answer at $(yay_e2e_url) after start"
      sleep 2
    done
    echo "e2e site up: $(yay_e2e_url)"
  fi
}

# yay_e2e_run [playwright args...]: needs the site up (start it with yayh e2e env start).
yay_e2e_run() {
  _e2e_need_setup
  if ! yay_e2e_up; then printf 'yayh: the e2e site is down at %s: run yayh e2e env start first\n' "$(yay_e2e_url)" >&2; exit 3; fi
  _e2e_exec e2e "$@"
}

# yay_e2e_cli <cmd...>: a command in the wp-env cli container (wp ..., tail ...).
yay_e2e_cli() {
  [ $# -gt 0 ] || yay_die "usage: yayh e2e cli <command...>   e.g. yayh e2e cli wp option get blogname"
  _e2e_need_setup
  _e2e_external && yay_die "e2e.baseUrl is an external site: run WP-CLI there (site.wpPath), not through wp-env"
  local root dir extra
  root="$(yay_repo_root)"; dir="$(yay_e2e_dir)"
  [ -x "$root/$dir/node_modules/.bin/wp-env" ] || yay_die "wp-env isn't installed in $dir: yayh run e2e-install"
  extra="$(yay_config_get e2e.wpEnvArgs 2>/dev/null || true)"
  # shellcheck disable=SC2086
  (cd "$root/$dir" && ./node_modules/.bin/wp-env run $extra cli "$@")
}

# Spec files under the e2e dir.
_e2e_spec_files() {
  local root dir; root="$(yay_repo_root)"; dir="$(yay_e2e_dir)"
  [ -d "$root/$dir" ] || return 0
  (cd "$root" && find "$dir" -name node_modules -prune -o -type f \( -name '*.spec.ts' -o -name '*.spec.js' -o -name '*.spec.mjs' -o -name '*.test.ts' \) -print | sort)
}

# yay_e2e_specs [ID] -> without ID: tests<TAB>file per spec file; with an
# artifact ID: file:line:text of every test tagged @ID (@P-1 never matches @P-12).
yay_e2e_specs() {
  local id="${1:-}" root f n
  root="$(yay_repo_root)"
  if [ -z "$id" ]; then
    _e2e_spec_files | while IFS= read -r f; do
      n="$(grep -cE '^[[:space:]]*test(\.(only|skip|fixme|fail))?\(' "$root/$f" || true)"
      printf '%s\t%s\n' "$n" "$f"
    done
    return 0
  fi
  _e2e_spec_files | while IFS= read -r f; do
    grep -nE "@${id}([^0-9A-Za-z-]|\$)" "$root/$f" 2>/dev/null | sed "s|^|$f:|" || true
  done
}

# yay_e2e_status -> key<TAB>value<TAB>detail
yay_e2e_status() {
  local root dir setup=no deps=missing env n
  root="$(yay_repo_root)"; dir="$(yay_e2e_dir)"
  if yay_config_get commands.e2e >/dev/null 2>&1 && [ -d "$root/$dir" ]; then setup=yes; fi
  [ -x "$root/$dir/node_modules/.bin/playwright" ] && deps=installed
  printf 'setup\t%s\t%s\n' "$setup" "$dir"
  printf 'deps\t%s\t%s\n' "$deps" "$dir/node_modules"
  if _e2e_external; then env=external; elif yay_e2e_up; then env=up; else env=down; fi
  printf 'docker\t%s\t\n' "$(_e2e_docker)"
  printf 'env\t%s\t%s\n' "$env" "$(yay_e2e_url)"
  printf 'port\t%s\t%s\n' "$(yay_e2e_port)" "$(_e2e_main_checkout && echo main || echo worktree)"
  n="$(_e2e_spec_files | grep -c . || true)"
  printf 'specs\t%s\t%s\n' "$n" "files"
}

# yay_e2e_detect -> kind<TAB>path<TAB>detail for an existing browser-test setup
# (playwright, wp-env, cypress, script, ci), so /yay:e2e-init can adopt it.
yay_e2e_detect() {
  local root f
  root="$(yay_repo_root)"
  cd "$root" || return 1
  find . -maxdepth 4 \( -name node_modules -o -name vendor -o -name .git -o -path ./.claude \) -prune -o -type f \
    \( -name 'playwright.config.*' -o -name '.wp-env*.json' -o -name 'cypress.config.*' -o -name 'package.json' \) -print \
    | sed 's|^\./||' | sort | while IFS= read -r f; do
      case "$f" in
        */playwright.config.*|playwright.config.*) printf 'playwright\t%s\t\n' "$f" ;;
        */.wp-env*.json|.wp-env*.json) printf 'wp-env\t%s\t\n' "$f" ;;
        */cypress.config.*|cypress.config.*) printf 'cypress\t%s\t\n' "$f" ;;
        *package.json)
          sed -nE 's/^[[:space:]]*"([^"]+)"[[:space:]]*:[[:space:]]*"([^"]*(playwright|wp-env|cypress|e2e)[^"]*)".*/\1	\2/p' "$f" \
            | while IFS="$(printf '\t')" read -r k v; do
                case "$k" in @*|name|description|version) continue ;; esac
                printf 'script\t%s\t%s: %s\n' "$f" "$k" "$v"
              done ;;
      esac
    done
  for f in .github/workflows/*; do
    [ -f "$f" ] || continue
    if grep -qiE 'playwright|wp-env|cypress|e2e' "$f"; then printf 'ci\t%s\t\n' "$f"; fi
  done
}

# Render an e2e template: #if-<flag> / #end-<flag> blocks kept only when the
# flag is in <flags> (comma list), {{e2e.k}} from k=v pairs, then config keys.
_e2e_render() {
  local tpl="$1" flags="$2" tmp kv k v
  shift 2
  tmp="$(mktemp)"
  awk -v flags=",$flags," '
    /^[[:space:]]*#if-[a-z]+[[:space:]]*$/ { f = $0; gsub(/[[:space:]]|#if-/, "", f); skip[++d] = (index(flags, "," f ",") == 0); next }
    /^[[:space:]]*#end-[a-z]+[[:space:]]*$/ { d--; next }
    { for (i = 1; i <= d; i++) if (skip[i]) next; print }' "$tpl" > "$tmp"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    awk -v k="{{${_YAY_TPL_NS:-e2e}.$k}}" -v v="$v" 'BEGIN{gsub(/\\/,"\\\\",v)} { while ((i = index($0, k)) > 0) $0 = substr($0, 1, i-1) v substr($0, i+length(k)); print }' "$tmp" > "$tmp.n" && mv "$tmp.n" "$tmp"
  done
  yay_render "$tmp"
  rm -f "$tmp"
}

# yay_e2e_scaffold [dir=tests/e2e] [--no-ci]: write the starter files that don't
# exist yet (never overwrites) and add the missing e2e keys to .yay/config.json.
# Prints created|exists<TAB>path and config<TAB>key lines.
yay_e2e_scaffold() {
  local dir="" ci=1 a v root cfg pm wc flags port folder up plugins node install ci_install prepare
  for a in "$@"; do
    case "$a" in
      dir=*) dir="${a#dir=}" ;;
      --no-ci) ci=0 ;;
      *) yay_die "usage: yayh e2e scaffold [dir=tests/e2e] [--no-ci]" ;;
    esac
  done
  root="$(yay_repo_root)"; cfg="$(yay_config_file)"
  [ -f "$cfg" ] || yay_die "no .yay/config.json: run /yay:harness-init first"
  [ -n "$dir" ] || dir="$(yay_e2e_dir)"
  dir="${dir%/}"
  case "$dir" in /*|*..*) yay_die "dir must be a relative path inside the repo" ;; esac

  pm="$(yay_detect_pm 2>/dev/null || echo npm)"
  case "$pm" in
    pnpm) install="pnpm install --ignore-workspace"; ci_install="pnpm install --ignore-workspace --frozen-lockfile" ;;
    yarn) install="yarn install"; ci_install="yarn install --frozen-lockfile" ;;
    *) pm=npm; install="npm install"; ci_install="npm ci" ;;
  esac
  wc="$(yay_config_get requires.wc 2>/dev/null || true)"
  flags="$pm"; case "$wc" in ''|null) ;; *) flags="$flags,woo" ;; esac
  port="$(yay_e2e_base_port)"
  folder="$(yay_config_get plugin.slug)"
  up="$(printf '%s' "$dir" | awk -F/ '{ s = ""; for (i = 1; i <= NF; i++) if ($i != "" && $i != ".") s = s (s ? "/" : "") ".."; print s }')"
  plugins=""; case ",$flags," in *,woo,*) plugins='"https://downloads.wordpress.org/plugin/woocommerce.zip"' ;; esac
  if [ -f "$root/.nvmrc" ]; then node="node-version-file: .nvmrc"; else node="node-version: 20"; fi
  prepare=""
  for a in install build; do
    v="$(yay_config_get "commands.$a" 2>/dev/null || true)"
    [ -n "$v" ] && prepare="${prepare:+$prepare && }$v"
  done
  [ -n "$prepare" ] || prepare="true"

  local rel src dest
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src="$YAY_E2E_TEMPLATES/$rel"
    case "$rel" in
      ci/e2e.yml) [ "$ci" = 1 ] || continue; dest=".github/workflows/e2e.yml" ;;
      gitignore) dest="$dir/.gitignore" ;;
      *) dest="$dir/$rel" ;;
    esac
    if [ -e "$root/$dest" ]; then printf 'exists\t%s\n' "$dest"; continue; fi
    mkdir -p "$(dirname "$root/$dest")"
    _e2e_render "$src" "$flags" "port=$port" "dir=$dir" "root=$up" "folder=$folder" "plugins=$plugins" \
      "node=$node" "ciInstall=$ci_install" "prepare=$prepare" > "$root/$dest"
    case "$dest" in *.sh) chmod +x "$root/$dest" ;; esac
    printf 'created\t%s\n' "$dest"
  done <<EOF
$(cd "$YAY_E2E_TEMPLATES" && find . -type f | sed 's|^\./||' | sort)
EOF

  # Config: add only what's missing, so hand-tuned commands survive a re-run.
  local snippet="" key cmd tmp cmds=""
  for key in e2e e2e-install e2e-start e2e-stop e2e-reset; do
    yay_json_get "$cfg" "commands.$key" >/dev/null 2>&1 && continue
    case "$key" in
      e2e) cmd="cd $dir && ./node_modules/.bin/playwright test" ;;
      e2e-install) cmd="cd $dir && $install && ./node_modules/.bin/playwright install chromium" ;;
      e2e-start) cmd="cd $dir && ./node_modules/.bin/wp-env start" ;;
      e2e-stop) cmd="cd $dir && ./node_modules/.bin/wp-env stop" ;;
      e2e-reset) cmd="cd $dir && ./node_modules/.bin/wp-env clean all" ;;
    esac
    cmds="$cmds${cmds:+,}$(yay_json_str "$key"):$(yay_json_str "$cmd")"
    printf 'config\tcommands.%s\n' "$key"
  done
  [ -z "$cmds" ] || snippet="\"commands\":{$cmds}"
  if ! yay_json_get "$cfg" e2e.dir >/dev/null 2>&1; then
    snippet="$snippet${snippet:+,}\"e2e\":{\"dir\":$(yay_json_str "$dir")}"
    printf 'config\te2e.dir\n'
  fi
  if [ -n "$snippet" ]; then
    tmp="$(mktemp)"; printf '{%s}\n' "$snippet" > "$tmp"
    yay_json_merge "$cfg" "$tmp" > "$tmp.out" && mv "$tmp.out" "$cfg"
    rm -f "$tmp"
  fi
}

# yay_e2e_surfaces -> TSV: kind<TAB>file:line<TAB>name. Every place a user can reach the plugin:
# the starting map for /yay:e2e-init's scouts. Plain grep over tracked source (code.sh's file list).
yay_e2e_surfaces() {
  local root f
  root="$(yay_repo_root)"
  cd "$root" || return 1
  _yay_code_files | while IFS= read -r f; do
    awk -v f="$f" '
      function out(kind, re,   s, n) {
        if (match($0, re)) {
          s = substr($0, RSTART, RLENGTH)
          n = s; sub(/^[^"\x27]*["\x27]/, "", n); sub(/["\x27].*$/, "", n)
          if (n == s) { n = s; gsub(/[[:space:]]+/, " ", n); n = substr(n, 1, 70) }
          printf "%s\t%s:%d\t%s\n", kind, f, FNR, n
          return 1
        }
        return 0
      }
      /^[[:space:]]*(\/\/|\*|#)/ { next }
      {
        out("admin-page", "add_(sub)?menu_page[[:space:]]*\\([^;]*") ||
        out("admin-page", "add_(options|management|theme|users|dashboard|plugins)_page[[:space:]]*\\([^;]*")
        out("shortcode", "add_shortcode[[:space:]]*\\([[:space:]]*[\"\x27][^\"\x27]+")
        out("block", "register_block_type(_from_metadata)?[[:space:]]*\\([^)]*")
        out("block", "registerBlockType[[:space:]]*\\([[:space:]]*[\"\x27][^\"\x27]+")
        out("rest", "register_rest_route[[:space:]]*\\([^;]*")
        out("ajax", "[\"\x27]wp_ajax_(nopriv_)?[a-z0-9_]+")
        out("account", "add_rewrite_endpoint[[:space:]]*\\([[:space:]]*[\"\x27][^\"\x27]+") ||
        out("account", "[\"\x27]woocommerce_account_[a-z0-9_]+")
        out("wc-settings", "[\"\x27]woocommerce_(settings_tabs_array|get_settings_pages|get_sections_[a-z0-9_]+)")
        out("checkout", "[\"\x27]woocommerce_(review_order|checkout|cart|before_cart|after_cart|proceed_to_checkout|blocks_)[a-z0-9_]*")
        out("checkout", "woocommerce_store_api_register_endpoint_data|registerCheckoutFilters|ExperimentalOrderMeta|registerPaymentMethod")
        out("product", "[\"\x27](woocommerce_(single_product|before_add_to_cart|after_add_to_cart|product_options|product_data_)|product_type_selector)[a-z0-9_]*")
        out("email", "extends[[:space:]]+WC_Email|[\"\x27]woocommerce_email_classes")
        out("gateway", "extends[[:space:]]+WC_Payment_Gateway|[\"\x27]woocommerce_payment_gateways")
        out("shipping", "extends[[:space:]]+WC_Shipping_Method|[\"\x27]woocommerce_shipping_methods")
        out("widget", "extends[[:space:]]+WP_Widget|register_widget[[:space:]]*\\(")
        out("metabox", "add_meta_box[[:space:]]*\\([[:space:]]*[\"\x27][^\"\x27]+")
        out("assets", "wp_enqueue_script[[:space:]]*\\([[:space:]]*[\"\x27][^\"\x27]+")
        out("cron", "wp_schedule_(single_)?event[[:space:]]*\\(|as_schedule_[a-z_]+action[[:space:]]*\\(")
      }' "$f"
  done
  git ls-files -- '*block.json' 2>/dev/null | while IFS= read -r f; do
    case "$f" in node_modules/*|*/node_modules/*|vendor/*|*/vendor/*|build/*|*/build/*|dist/*|*/dist/*) continue ;; esac
    printf 'block\t%s:1\t%s\n' "$f" "$(sed -nE 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$f" | sed -n 1p)"
  done
}
