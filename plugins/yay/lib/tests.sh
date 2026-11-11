#!/usr/bin/env bash
# tests: PHP unit (PHPUnit + Brain Monkey, no WordPress), PHP integration (the WordPress
# test suite in wp-env's tests site, port+1, its own database) and JS unit tests.
# Which layer a change gets is decided per task: reference/testing.md.
# Commands live in .yay/config.json (commands.test-unit, test-integration, test-js).

YAY_TESTS_TEMPLATES="${YAY_KIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/templates/tests"

yay_tests_php_dir() { yay_config_get tests.php 2>/dev/null || echo tests/php; }
yay_tests_js_dir() { yay_config_get tests.js 2>/dev/null || echo tests/js; }

# vitest | jest | wp-scripts | none: tests.jsRunner, else what package.json already uses.
_tests_js_runner() {
  local r root; r="$(yay_config_get tests.jsRunner 2>/dev/null || true)"
  if [ -n "$r" ]; then printf '%s\n' "$r"; return; fi
  root="$(yay_repo_root)"
  [ -f "$root/package.json" ] || { echo none; return; }
  if grep -q '"vitest"' "$root/package.json"; then echo vitest
  elif grep -q '"jest"' "$root/package.json"; then echo jest
  elif grep -q '"@wordpress/scripts"' "$root/package.json"; then echo wp-scripts
  else echo vitest; fi
}

_tests_up() { # <path> -> ".." per segment
  printf '%s' "$1" | awk -F/ '{ s = ""; for (i = 1; i <= NF; i++) if ($i != "" && $i != ".") s = s (s ? "/" : "") ".."; print s }'
}

# The integration tests run in wp-env's tests site: this checkout's e2e port + 1.
yay_tests_integration_url() { printf 'http://localhost:%s\n' "$(( $(yay_e2e_port) + 1 ))"; }
_tests_integration_up() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$(yay_tests_integration_url)/" 2>/dev/null || true)"
  case "$code" in 2??|3??) return 0 ;; esac
  return 1
}

# yay_tests_detect -> TSV: kind<TAB>where<TAB>detail. What the repo already has.
yay_tests_detect() {
  local root f p n
  root="$(yay_repo_root)"
  cd "$root" || return 1
  find . -maxdepth 3 \( -name node_modules -o -name vendor -o -name .git -o -path ./.claude \) -prune -o -type f \
    \( -name 'phpunit*.xml' -o -name 'phpunit*.xml.dist' -o -name '*.xml.dist' -path './tests/*' -o -name 'vitest.config.*' -o -name 'jest.config.*' \) -print \
    | sed 's|^\./||' | sort -u | while IFS= read -r f; do
      case "$f" in
        *vitest.config.*) printf 'js-config\t%s\tvitest\n' "$f" ;;
        *jest.config.*) printf 'js-config\t%s\tjest\n' "$f" ;;
        *) grep -q '<phpunit' "$f" 2>/dev/null && printf 'phpunit\t%s\t%s\n' "$f" "$(sed -nE 's/.*bootstrap="([^"]+)".*/bootstrap=\1/p' "$f" | sed -n 1p)" ;;
      esac
    done
  if [ -f composer.json ]; then
    for p in phpunit/phpunit yoast/phpunit-polyfills brain/monkey 10up/wp_mock wp-phpunit/wp-phpunit mockery/mockery; do
      grep -q "\"$p\"" composer.json && printf 'composer-dev\tcomposer.json\t%s\n' "$p"
    done
    tr ',{}' '\n\n\n' < composer.json | sed -nE 's/^[[:space:]]*"([^"/]*test[^"/]*)"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1	\2/p' \
      | while IFS="$(printf '\t')" read -r p n; do printf 'script\tcomposer.json\t%s: %s\n' "$p" "$n"; done
  fi
  find . \( -name node_modules -o -name vendor -o -name .git -o -path ./.claude \) -prune -o -type f -name '*Test.php' -print \
    | sed -e 's|^\./||' -e 's|/[^/]*$||' | sort | uniq -c | while read -r n p; do printf 'php-tests\t%s\t%s files\n' "$p" "$n"; done
  if [ -f package.json ]; then
    printf 'js-runner\tpackage.json\t%s\n' "$(_tests_js_runner)"
    tr ',{}' '\n\n\n' < package.json | sed -nE 's/^[[:space:]]*"([^"/]*test[^"/]*)"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1	\2/p' \
      | while IFS="$(printf '\t')" read -r p n; do
          case "$n" in *playwright*|*wp-env*|*cypress*) continue ;; esac
          printf 'script\tpackage.json\t%s: %s\n' "$p" "$n"
        done
    n="$(find . \( -name node_modules -o -name vendor -o -name .git -o -path "./$(yay_e2e_dir)" \) -prune -o -type f \
      \( -name '*.test.js' -o -name '*.test.jsx' -o -name '*.test.ts' -o -name '*.test.tsx' -o -path '*/__tests__/*' \) -print | grep -c . || true)"
    [ "$n" = 0 ] || printf 'js-tests\t.\t%s files\n' "$n"
  fi
  for f in .github/workflows/*; do
    [ -f "$f" ] || continue
    if grep -qiE 'phpunit|vitest|jest|test-unit' "$f"; then printf 'ci\t%s\t\n' "$f"; fi
  done
}

# yay_tests_scaffold [php=tests/php] [js=tests/js] [js-runner=vitest|jest|wp-scripts|none]
#   [--no-integration] [--no-js] [--no-ci]: writes the missing files, adds missing config keys,
#   and prints created/exists/updated/config lines plus deps lines (packages to install).
yay_tests_scaffold() {
  local php="" js="" runner="" integ=1 ci=1 a root cfg
  for a in "$@"; do
    case "$a" in
      php=*) php="${a#php=}" ;;
      js=*) js="${a#js=}" ;;
      js-runner=*) runner="${a#js-runner=}" ;;
      --no-integration) integ=0 ;;
      --no-js) runner=none ;;
      --no-ci) ci=0 ;;
      *) yay_die "usage: yayh test scaffold [php=tests/php] [js=tests/js] [js-runner=vitest|jest|wp-scripts|none] [--no-integration] [--no-js] [--no-ci]" ;;
    esac
  done
  root="$(yay_repo_root)"; cfg="$(yay_config_file)"
  [ -f "$cfg" ] || yay_die "no .yay/config.json: run /yay:harness-init first"
  [ -n "$php" ] || php="$(yay_tests_php_dir)"
  [ -n "$js" ] || js="$(yay_tests_js_dir)"
  php="${php%/}"; js="${js%/}"
  for a in "$php" "$js"; do case "$a" in /*|*..*) yay_die "test dirs must be relative paths inside the repo" ;; esac; done
  [ -n "$runner" ] || runner="$(_tests_js_runner)"
  case "$runner" in vitest|jest|wp-scripts|none) ;; *) yay_die "js-runner must be vitest, jest, wp-scripts or none" ;; esac

  local pm wc flags levels jsroot e2e node jsinstall prepare v unitcmd jscmd="" integcmd extra slug
  pm="$(yay_detect_pm 2>/dev/null || echo npm)"
  case "$pm" in
    pnpm) jsinstall="pnpm install --frozen-lockfile" ;;
    yarn) jsinstall="yarn install --frozen-lockfile" ;;
    *) pm=npm; jsinstall="npm ci" ;;
  esac
  wc="$(yay_config_get requires.wc 2>/dev/null || true)"
  flags="$pm"; case "$wc" in ''|null) ;; *) flags="$flags,woo" ;; esac
  [ "$runner" = none ] || flags="$flags,js"
  [ "$integ" = 1 ] && flags="$flags,integration"
  levels="$(( $(printf '%s' "$php" | awk -F/ '{ n = 0; for (i = 1; i <= NF; i++) if ($i != "" && $i != ".") n++; print n }') + 1 ))"
  jsroot="$(_tests_up "$js")/"
  e2e="$(yay_e2e_dir)"
  slug="$(yay_config_get plugin.slug)"
  extra="$(yay_config_get e2e.wpEnvArgs 2>/dev/null || true)"
  if [ -f "$root/.nvmrc" ]; then node="node-version-file: .nvmrc"; else node="node-version: 20"; fi
  prepare=""
  for a in install build; do
    v="$(yay_config_get "commands.$a" 2>/dev/null || true)"
    [ -n "$v" ] && prepare="${prepare:+$prepare && }$v"
  done
  case "$prepare" in *composer*) ;; *) prepare="composer install --no-interaction${prepare:+ && $prepare}" ;; esac

  unitcmd="vendor/bin/phpunit -c $php/unit.xml.dist"
  integcmd="cd $e2e && ./node_modules/.bin/wp-env run ${extra:+$extra }tests-cli --env-cwd=wp-content/plugins/$slug vendor/bin/phpunit -c $php/integration.xml.dist"
  local own_vitest=0
  case "$runner" in
    vitest)
      if ls "$root"/vitest.config.* >/dev/null 2>&1; then jscmd="./node_modules/.bin/vitest run"
      else own_vitest=1; jscmd="./node_modules/.bin/vitest run --config $js/vitest.config.mjs"; fi ;;
    jest) jscmd="./node_modules/.bin/jest $js" ;;
    wp-scripts) jscmd="./node_modules/.bin/wp-scripts test-unit-js $js" ;;
  esac

  # Integration runs in wp-env's tests site, which lives in the e2e package.
  if [ "$integ" = 1 ] && [ ! -f "$root/$e2e/.wp-env.json" ]; then
    if [ "$ci" = 1 ]; then yay_e2e_scaffold "dir=$e2e"; else yay_e2e_scaffold "dir=$e2e" --no-ci; fi
  fi
  if [ "$integ" = 1 ] && grep -q '"testsEnvironment":[[:space:]]*false' "$root/$e2e/.wp-env.json" 2>/dev/null; then
    sed -i.bak -E 's/"testsEnvironment":[[:space:]]*false/"testsEnvironment": true/' "$root/$e2e/.wp-env.json" && rm -f "$root/$e2e/.wp-env.json.bak"
    printf 'updated\t%s\ttestsEnvironment: true (integration tests get their own site and database)\n' "$e2e/.wp-env.json"
  fi

  local rel dest
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in
      ci/tests.yml) [ "$ci" = 1 ] || continue; dest=".github/workflows/tests.yml" ;;
      php/integration*|php/integration/*) [ "$integ" = 1 ] || continue; dest="$php/${rel#php/}" ;;
      php/*) dest="$php/${rel#php/}" ;;
      js/vitest.config.mjs) [ "$own_vitest" = 1 ] || continue; dest="$js/vitest.config.mjs" ;;
      *) continue ;;
    esac
    if [ -e "$root/$dest" ]; then printf 'exists\t%s\n' "$dest"; continue; fi
    mkdir -p "$(dirname "$root/$dest")"
    _YAY_TPL_NS=tests _e2e_render "$YAY_TESTS_TEMPLATES/$rel" "$flags" "levels=$levels" "php=$php" "js=$js" "jsRoot=$jsroot" \
      "e2e=$e2e" "node=$node" "jsInstall=$jsinstall" "e2eInstall=$( [ "$pm" = pnpm ] && echo 'pnpm install --ignore-workspace --frozen-lockfile' || { [ "$pm" = yarn ] && echo 'yarn install --frozen-lockfile' || echo 'npm ci'; })" \
      "prepare=$prepare" "unitCmd=$unitcmd" "jsCmd=$jscmd" > "$root/$dest"
    printf 'created\t%s\n' "$dest"
  done <<EOF
$(cd "$YAY_TESTS_TEMPLATES" && find . -type f | sed 's|^\./||' | sort)
EOF
  [ "$runner" = none ] || mkdir -p "$root/$js"

  # Config: add only what's missing, so hand-tuned commands survive a re-run.
  local snippet="" key cmd tmp cmds="" tcfg=""
  for key in test-unit test-integration test-js test; do
    yay_json_get "$cfg" "commands.$key" >/dev/null 2>&1 && continue
    case "$key" in
      test-unit) cmd="$unitcmd" ;;
      test-integration) [ "$integ" = 1 ] || continue; cmd="$integcmd" ;;
      test-js) [ -n "$jscmd" ] || continue; cmd="$jscmd" ;;
      test) cmd="$unitcmd${jscmd:+ && $jscmd}" ;;
    esac
    cmds="$cmds${cmds:+,}$(yay_json_str "$key"):$(yay_json_str "$cmd")"
    printf 'config\tcommands.%s\n' "$key"
  done
  [ -z "$cmds" ] || snippet="\"commands\":{$cmds}"
  for key in php js jsRunner; do
    yay_json_get "$cfg" "tests.$key" >/dev/null 2>&1 && continue
    case "$key" in php) v="$php" ;; js) [ "$runner" = none ] && continue; v="$js" ;; jsRunner) v="$runner" ;; esac
    tcfg="$tcfg${tcfg:+,}$(yay_json_str "$key"):$(yay_json_str "$v")"
    printf 'config\ttests.%s\n' "$key"
  done
  [ -z "$tcfg" ] || snippet="$snippet${snippet:+,}\"tests\":{$tcfg}"
  if [ -n "$snippet" ]; then
    tmp="$(mktemp)"; printf '{%s}\n' "$snippet" > "$tmp"
    yay_json_merge "$cfg" "$tmp" > "$tmp.out" && mv "$tmp.out" "$cfg"
    rm -f "$tmp"
  fi

  # Packages the layers need that the repo doesn't declare yet (the skill installs them).
  local need="" p
  for p in phpunit/phpunit:^9.6 yoast/phpunit-polyfills:^2.0 brain/monkey:^2.6; do
    grep -q "\"${p%%:*}\"" "$root/composer.json" 2>/dev/null || need="$need $p"
  done
  [ -z "$need" ] || printf 'deps\tcomposer\tcomposer require --dev --no-interaction -W%s\n' "$need"
  if [ "$runner" != none ]; then
    case "$runner" in vitest) p=vitest ;; jest) p=jest ;; wp-scripts) p=@wordpress/scripts ;; esac
    if ! grep -q "\"$p\"" "$root/package.json" 2>/dev/null; then
      case "$pm" in npm) printf 'deps\tnpm\tnpm install --save-dev %s\n' "$p" ;; *) printf 'deps\t%s\t%s add -D %s\n' "$pm" "$pm" "$p" ;; esac
    fi
  fi
}

# Test files per layer.
_tests_files() { # unit | integration | js
  local root dir; root="$(yay_repo_root)"
  case "$1" in
    unit|integration) dir="$(yay_tests_php_dir)/$1"; [ -d "$root/$dir" ] || return 0
      (cd "$root" && find "$dir" -type f -name '*Test.php' | sort) ;;
    js) dir="$(yay_tests_js_dir)"
      (cd "$root" && find . \( -name node_modules -o -name vendor -o -name .git -o -path "./$(yay_e2e_dir)" -o -path ./.claude \) -prune -o -type f \
        \( -name '*.test.js' -o -name '*.test.jsx' -o -name '*.test.ts' -o -name '*.test.tsx' \) -print | sed 's|^\./||' | sort) ;;
  esac
}

_tests_id_re() { # <layer> <ID>: PHP tests carry @group ID, JS tests @ID in the test name. P-1 never matches P-12.
  case "$1" in js) printf '@%s([^0-9A-Za-z-]|$)' "$2" ;; *) printf '@group[[:space:]]+%s([^0-9A-Za-z-]|$)' "$2" ;; esac
}

# yay_tests_list [ID] -> without ID: layer<TAB>tests<TAB>file; with ID: layer<TAB>file:line:text.
yay_tests_list() {
  local id="${1:-}" root l f n re
  root="$(yay_repo_root)"
  for l in unit integration js; do
    _tests_files "$l" | while IFS= read -r f; do
      if [ -z "$id" ]; then
        case "$l" in
          js) n="$(grep -cE '^[[:space:]]*(it|test)(\.(only|skip|each[^(]*))?\(' "$root/$f" || true)" ;;
          *) n="$(grep -cE 'function[[:space:]]+test|@test' "$root/$f" || true)" ;;
        esac
        printf '%s\t%s\t%s\n' "$l" "$n" "$f"
      else
        re="$(_tests_id_re "$l" "$id")"
        grep -nE "$re" "$root/$f" 2>/dev/null | sed "s|^|$l	$f:|" || true
      fi
    done
  done
}

_tests_configured() { yay_config_get "commands.test-$1" >/dev/null 2>&1; }

# One layer. Exit 3 when the integration site is down; 0 with a note when --id matches nothing there.
_tests_run_layer() {
  local layer="$1" id="$2"; shift 2
  _tests_configured "$layer" || yay_die "no commands.test-$layer: run /yay:test-init (or yayh test scaffold)"
  local -a extra=()
  if [ -n "$id" ]; then
    if [ -z "$(yay_tests_list "$id" | awk -F'\t' -v l="$layer" '$1 == l' | sed -n 1p)" ]; then
      printf 'yayh: no %s tests tagged %s\n' "$layer" "$id" >&2; return 0
    fi
    case "$layer" in js) extra=(-t "@$id") ;; *) extra=(--group "$id") ;; esac
  fi
  if [ "$layer" = integration ]; then
    if ! _tests_integration_up; then
      printf 'yayh: the integration tests site is down at %s: run yayh e2e env start (Docker) first\n' "$(yay_tests_integration_url)" >&2
      return 3
    fi
    _e2e_exec test-integration ${extra[@]+"${extra[@]}"} "$@"
    return
  fi
  local app="" a
  for a in ${extra[@]+"${extra[@]}"} "$@"; do app="$app $(printf '%q' "$a")"; done
  YAY_RUN_APPEND="${app# }" yay_run "test-$layer"
}

# yay_tests_run unit|integration|js|all [--id=ID] [runner args...]
# all: every configured layer; integration is skipped (not failed) when its site is down.
yay_tests_run() {
  local layer="${1:-}" id="" a rc worst=0 l
  [ $# -gt 0 ] && shift
  local -a rest=()
  for a in "$@"; do case "$a" in --id=*) id="${a#--id=}" ;; *) rest+=("$a") ;; esac; done
  case "$layer" in
    unit|integration|js) _tests_run_layer "$layer" "$id" ${rest[@]+"${rest[@]}"} ;;
    all)
      [ ${#rest[@]} -eq 0 ] || yay_die "yayh test run all takes only --id=<ID>; pass runner arguments to one layer"
      if ! _tests_configured unit && ! _tests_configured js && ! _tests_configured integration; then
        yay_config_get commands.test >/dev/null 2>&1 || yay_die "no test commands configured: run /yay:test-init"
        yay_run test; return
      fi
      local summary=""
      for l in unit integration js; do
        _tests_configured "$l" || continue
        rc=0; _tests_run_layer "$l" "$id" || rc=$?
        case "$rc" in
          0) summary="$summary$l	passed"$'\n' ;;
          3) summary="$summary$l	skipped	tests site down (Docker)"$'\n' ;;
          *) summary="$summary$l	failed	exit $rc"$'\n'; worst=1 ;;
        esac
      done
      printf '%s' "$summary"
      return "$worst" ;;
    *) yay_die "usage: yayh test run unit|integration|js|all [--id=P-4] [runner args...]" ;;
  esac
}

# yay_tests_status -> key<TAB>value<TAB>detail
yay_tests_status() {
  local root php js runner v l a
  root="$(yay_repo_root)"; php="$(yay_tests_php_dir)"; js="$(yay_tests_js_dir)"; runner="$(_tests_js_runner)"
  for l in unit integration js; do
    if _tests_configured "$l"; then v=yes; else v=no; fi
    case "$l" in
      unit) printf 'unit\t%s\t%s\n' "$v" "$php/unit" ;;
      integration)
        local site=down; _tests_configured integration && _tests_integration_up && site=up
        printf 'integration\t%s\tsite %s %s\n' "$v" "$site" "$(yay_tests_integration_url)" ;;
      js) printf 'js\t%s\t%s\n' "$v" "$runner" ;;
    esac
  done
  if command -v php >/dev/null 2>&1; then v="$(php -r 'echo PHP_VERSION;' 2>/dev/null)"; else v=missing; fi
  printf 'php\t%s\t\n' "$v"
  if [ -x "$root/vendor/bin/phpunit" ]; then v=installed; else v=missing; fi
  printf 'deps\t%s\tvendor/bin/phpunit\n' "$v"
  if [ "$runner" != none ]; then
    case "$runner" in wp-scripts) a=wp-scripts ;; *) a="$runner" ;; esac
    if [ -x "$root/node_modules/.bin/$a" ]; then v=installed; else v=missing; fi
    printf 'jsdeps\t%s\tnode_modules/.bin/%s\n' "$v" "$a"
  fi
  printf 'docker\t%s\t\n' "$(_e2e_docker)"
  for l in unit integration js; do
    printf 'files\t%s\t%s\n' "$(_tests_files "$l" | grep -c . || true)" "$l"
  done
}
