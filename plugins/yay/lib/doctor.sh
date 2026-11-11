# shellcheck shell=bash
# `yayh doctor`: is this machine and repo ready for the yay workflow? One line per
# check, so a missing tool shows up before a skill fails halfway (the yaycheckout
# pilot lost its tests and build to a missing test database and the wrong Node).

# _yay_doc <ok|warn|fail> <check> <detail> [fix]
_yay_doc() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}"
  [ "$1" != fail ] || YAY_DOCTOR_FAILS=$((YAY_DOCTOR_FAILS + 1))
}

# _yay_major <version text> -> the first number (v22.3.1 -> 22, >=20 <23 -> 20)
_yay_major() { printf '%s' "$1" | sed -nE 's/^[^0-9]*([0-9]+).*/\1/p'; }

# yay_doctor -> TSV: status check detail fix   (status ok | warn | fail; exit 1 on any fail)
yay_doctor() {
  YAY_DOCTOR_FAILS=0
  local root e v want have cfg=0
  # Tools every skill needs.
  if command -v git >/dev/null 2>&1; then _yay_doc ok git "$(git --version | sed 's/git version //')"
  else _yay_doc fail git "not installed" "install git"; fi
  e=""; for v in jq node php python3; do command -v "$v" >/dev/null 2>&1 && { e="$v"; break; }; done
  if [ -n "$e" ]; then _yay_doc ok json "reads JSON with $e"
  else _yay_doc fail json "none of jq, node, php or python3" "install jq (brew install jq)"; fi
  if ! command -v gh >/dev/null 2>&1; then _yay_doc warn gh "not installed: PRs stay local" "brew install gh && gh auth login"
  elif gh auth status >/dev/null 2>&1; then _yay_doc ok gh "logged in"
  else _yay_doc warn gh "not logged in: PRs stay local" "gh auth login"; fi

  root="$(yay_repo_root 2>/dev/null)" || { _yay_doc fail repo "not inside a git repo" "cd into the plugin repo"; [ "$YAY_DOCTOR_FAILS" -eq 0 ]; return; }
  if git -C "$root" remote get-url origin >/dev/null 2>&1; then _yay_doc ok remote "origin: $(git -C "$root" remote get-url origin)"
  else _yay_doc warn remote "no origin remote: branches and PRs stay local" "git remote add origin <url>"; fi

  # The harness in this repo.
  if [ -f "$root/.yay/config.json" ]; then
    cfg=1
    if ( yay_config_validate >/dev/null 2>&1 ); then _yay_doc ok config ".yay/config.json is valid"
    else _yay_doc fail config ".yay/config.json has errors" "yayh config validate"; fi
    case "$(yay_harness_status 2>/dev/null)" in
      current*) _yay_doc ok harness "$(yay_harness_status)" ;;
      outdated*) _yay_doc warn harness "$(yay_harness_status)" "/yay:harness-update" ;;
      *) _yay_doc warn harness "$(yay_harness_status 2>/dev/null || echo unknown)" "/yay:harness-update" ;;
    esac
    # The skeleton seeds the block with a placeholder, so a marker alone isn't knowledge.
    if [ -f "$root/CLAUDE.md" ] && grep -q 'yay:project:start' "$root/CLAUDE.md" 2>/dev/null \
      && ! grep -q 'has not been written yet' "$root/CLAUDE.md" 2>/dev/null; then _yay_doc ok knowledge "project block present"
    else _yay_doc warn knowledge "no project knowledge yet: Claude knows the workflow, not the plugin" "/yay:knowledge-init"; fi
  else
    _yay_doc warn harness "not set up in this repo (no .yay/config.json)" "/yay:harness-init (one person, then merge the PR)"
  fi

  # PHP against the plugin's floor.
  if command -v php >/dev/null 2>&1; then
    have="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)"
    want=""; [ "$cfg" = 0 ] || want="$(yay_config_get requires.php 2>/dev/null || true)"
    if [ -n "$want" ] && [ "$(printf '%s\n%s\n' "$want" "$have" | sort -t. -k1,1n -k2,2n | sed -n 1p)" != "$want" ]; then
      _yay_doc warn php "PHP $have is older than the plugin's floor $want" "install PHP $want or newer"
    else _yay_doc ok php "PHP $have${want:+ (floor $want)}"; fi
  elif [ -f "$root/composer.json" ]; then _yay_doc warn php "not installed: PHP lint and tests can't run" "brew install php"; fi
  if [ -f "$root/composer.json" ]; then
    if ! command -v composer >/dev/null 2>&1; then _yay_doc warn composer "not installed" "brew install composer"
    elif [ -d "$root/vendor" ]; then _yay_doc ok composer "vendor/ installed"
    else _yay_doc warn composer "vendor/ missing" "yayh run install (or composer install)"; fi
  fi

  # Node against .nvmrc / .node-version / package.json engines.
  if [ -f "$root/package.json" ]; then
    want="$(cat "$root/.nvmrc" 2>/dev/null || cat "$root/.node-version" 2>/dev/null || true)"
    [ -n "$want" ] || want="$(yay_json_get "$root/package.json" engines.node 2>/dev/null || true)"
    have="$(node -v 2>/dev/null || true)"
    if [ -z "$have" ]; then _yay_doc warn node "not installed: the JS build and tests can't run" "install Node ${want:-LTS}"
    elif [ -n "$want" ] && [ "$(_yay_major "$want")" != "$(_yay_major "$have")" ]; then
      if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ] && [ -f "$root/.nvmrc" ]; then _yay_doc ok node "$have active; yayh run switches to $want through nvm"
      else _yay_doc warn node "$have active, the repo wants $want" "nvm install $(_yay_major "$want") (and add .nvmrc so yayh run switches by itself)"; fi
    else _yay_doc ok node "$have${want:+ (wants $want)}"; fi
    if [ -d "$root/node_modules" ]; then _yay_doc ok node_modules "installed"
    else _yay_doc warn node_modules "missing" "yayh run install"; fi
  fi

  # Docker: integration tests and e2e run in wp-env.
  local dk="missing"; command -v docker >/dev/null 2>&1 && { if docker info >/dev/null 2>&1; then dk=running; else dk=stopped; fi; }
  local needs=""
  if [ "$cfg" = 1 ]; then
    yay_config_get commands.test-integration >/dev/null 2>&1 && needs="integration tests"
    yay_config_get commands.e2e >/dev/null 2>&1 && needs="${needs:+$needs and }e2e specs"
  fi
  case "$dk:$needs" in
    running:*) _yay_doc ok docker "running" ;;
    *:) _yay_doc ok docker "$dk (nothing configured needs it yet)" ;;
    *) _yay_doc warn docker "$dk: $needs won't run (written and marked not run)" "start Docker Desktop" ;;
  esac
  [ "$YAY_DOCTOR_FAILS" -eq 0 ]
}
