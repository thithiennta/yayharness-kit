# shellcheck shell=bash
# Shared by the yay hooks. Reads the hook's JSON input from stdin once.
# Every hook exits 0 (no opinion) unless the repo has .yay/config.json.
set -uo pipefail
YAY_KIT_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
YAY_LIB_DIR="$YAY_KIT_ROOT/lib"
. "$YAY_LIB_DIR/common.sh"
. "$YAY_LIB_DIR/config.sh"
. "$YAY_LIB_DIR/manifest.sh"
. "$YAY_LIB_DIR/git.sh"

HOOK_IN="$(mktemp)"; trap 'rm -f "$HOOK_IN"' EXIT
cat > "$HOOK_IN"
hook_get() { yay_json_get "$HOOK_IN" "$1" 2>/dev/null || true; }

# hook_use_repo <dir>: set ROOT and YAY_REPO to the enclosing repo, or exit 0
# (no opinion) when it isn't a yay repo. Not for use inside $(...).
hook_use_repo() {
  local d="$1"
  while [ -n "$d" ] && [ ! -d "$d" ]; do d="$(dirname "$d")"; done
  ROOT="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || exit 0
  [ -f "$ROOT/.yay/config.json" ] || exit 0
  export YAY_REPO="$ROOT"
}

# For Bash hooks: the regex for a git commit/tag, the repo dir the command
# targets, and the command segment after `commit`.
GIT_RE='(^|[;&|(]|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+|[[:space:]]+-c[[:space:]]+[^[:space:]]+)*[[:space:]]+'
hook_cmd_dir() {
  local cmd="$1" dir cwd
  dir="$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|([^[:space:]]+)).*/\2\3/p' | head -1)"
  [ -n "$dir" ] || dir="$(printf '%s' "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+("([^"]+)"|([^[:space:]&;]+)).*/\2\3/p' | head -1)"
  cwd="$(hook_get cwd)"; [ -n "$cwd" ] || cwd="$PWD"
  case "$dir" in "") dir="$cwd" ;; /*) ;; "~"*) dir="$HOME${dir#\~}" ;; *) dir="$cwd/$dir" ;; esac
  printf '%s\n' "$dir"
}
# Flags of the git <sub> invocation only (up to the next ; & |).
hook_sub_args() { printf '%s' "$1" | sed -nE "s/.*git([^;&|]*[[:space:]])?$2([^;&|]*).*/\\2/p" | head -1; }

hook_block() { printf 'yay: %s\n' "$*" >&2; exit 2; }
