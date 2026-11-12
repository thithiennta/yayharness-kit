# shellcheck shell=bash
# Read .yay/config.json. See reference/config.md.

yay_config_file() { printf '%s/.yay/config.json\n' "$(yay_repo_root)"; }
# Per-developer overrides (gitignored), read before the shared config.
yay_config_local_file() { printf '%s/.yay/local.json\n' "$(yay_repo_root)"; }

# Defaults for keys a repo may omit. Prints nothing when there is no default.
yay_config_default() {
  case "$1" in
    git.tagFormat)    echo 'v{version}' ;;
    git.branchTypes)  printf '%s\n' feat fix chore hotfix docs refactor test ;;
    git.mergeMethod)  echo merge ;;
    changelog.readme) echo 'readme.txt' ;;
    changelog.notesDir) echo 'docs/releases' ;;
    requires.php)     echo '7.4' ;;
    # Model tiers (lib/model.sh, reference/models.md). Step defaults live in lib/model.sh.
    models.tiers.veryfast.model) echo sonnet ;;  models.tiers.veryfast.effort) echo medium ;;
    models.tiers.fast.model)     echo opus ;;    models.tiers.fast.effort)     echo low ;;
    models.tiers.balanced.model) echo opus ;;    models.tiers.balanced.effort) echo medium ;;
    models.tiers.deep.model)     echo opus ;;    models.tiers.deep.effort)     echo high ;;
    models.sizeBump.S) echo -1 ;; models.sizeBump.M) echo 0 ;; models.sizeBump.L) echo 1 ;;
    site.wpPath)      # a checkout inside <wp>/wp-content/plugins/ (worktrees included)
      local r; r="$(yay_repo_root)"
      case "$r" in */wp-content/plugins/*) printf '%s\n' "${r%%/wp-content/plugins/*}" ;; esac ;;
    site.debugLog)
      local w; w="$(yay_config_get site.wpPath 2>/dev/null)" && [ -n "$w" ] && printf '%s/wp-content/debug.log\n' "$w" ;;
  esac
  return 0
}

# yay_config_get <key> [fallback]  -> exit 3 if missing with no default/fallback.
yay_config_get() {
  local key="$1" file out
  file="$(yay_config_file)"
  if out="$(yay_json_get "$(yay_config_local_file)" "$key" 2>/dev/null)"; then printf '%s\n' "$out"; return 0; fi
  if out="$(yay_json_get "$file" "$key")"; then printf '%s\n' "$out"; return 0; fi
  out="$(yay_config_default "$key")"
  if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  if [ $# -ge 2 ]; then printf '%s\n' "$2"; return 0; fi
  return 3
}

yay_config_require() {
  [ -f "$(yay_config_file)" ] || yay_die "no .yay/config.json in $(yay_repo_root); run /yay:harness-init first"
}

# Substitute {version} {edition} {slug} {zip} in a template string.
# Usage: yay_fill "<template>" version=1.2.3 edition=pro
yay_fill() {
  local s="$1"; shift
  local kv k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    s="$(printf '%s' "$s" | awk -v k="{$k}" -v v="$v" '{ while ((i = index($0, k)) > 0) $0 = substr($0, 1, i-1) v substr($0, i+length(k)); print }')"
  done
  printf '%s\n' "$s"
}

# yay_strictness -> relaxed | standard | strict (workflow.strictness; anything else is standard)
yay_strictness() {
  local v; v="$(yay_config_get workflow.strictness 2>/dev/null || true)"
  case "$v" in relaxed|strict) printf '%s\n' "$v" ;; *) printf 'standard\n' ;; esac
}
