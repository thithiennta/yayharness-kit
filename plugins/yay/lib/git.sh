# shellcheck shell=bash
# Git helpers shared by implement, fix and release. See reference/git-conventions.md.

yay_git() { git -C "$(yay_repo_root)" "$@"; }

yay_base_branch() {
  local b
  if b="$(yay_config_get git.baseBranch 2>/dev/null)"; then printf '%s\n' "$b"; return; fi
  b="$(yay_git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && { printf '%s\n' "${b#origin/}"; return; }
  for b in dev develop main master; do
    yay_git show-ref --verify --quiet "refs/heads/$b" && { printf '%s\n' "$b"; return; }
  done
  yay_die "cannot tell the base branch; set git.baseBranch in .yay/config.json"
}

# yay_branch_name <type> <text>  -> type/slug, after checking type is allowed.
yay_branch_name() {
  local type="$1"; shift
  yay_in_list "$type" "$(yay_config_get git.branchTypes)" \
    || yay_die "branch type '$type' is not in git.branchTypes ($(yay_config_get git.branchTypes | tr '\n' ' '))"
  printf '%s/%s\n' "$type" "$(yay_slugify "$*")"
}

# yay_branch_check <branch>  -> exit 0 if it follows <type>/<slug>.
yay_branch_check() {
  local br="$1" type slug
  case "$br" in */*) ;; *) return 1;; esac
  type="${br%%/*}"; slug="${br#*/}"
  yay_in_list "$type" "$(yay_config_get git.branchTypes)" || return 1
  printf '%s' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# Tag name for a version, from git.tagFormat.
yay_tag_for() { yay_fill "$(yay_config_get git.tagFormat)" "version=$1"; }

# Latest release tag by version order (not by date), matching git.tagFormat.
yay_last_tag() {
  local fmt glob
  fmt="$(yay_config_get git.tagFormat)"
  glob="$(yay_fill "$fmt" 'version=[0-9]*')"
  yay_git tag --list "$glob" --sort=-v:refname | head -1
}

yay_version_of_tag() {
  local fmt pre post t="$1"
  fmt="$(yay_config_get git.tagFormat)"
  pre="${fmt%%\{version\}*}"; post="${fmt#*\{version\}}"
  t="${t#"$pre"}"; [ -n "$post" ] && t="${t%"$post"}"
  printf '%s\n' "$t"
}

# yay_semver_bump <current> <major|minor|patch|x.y.z>
yay_semver_bump() {
  local cur="$1" part="$2" ma mi pa
  if printf '%s' "$part" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then printf '%s\n' "$part"; return; fi
  cur="${cur%%[-+]*}"
  printf '%s' "$cur" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$' || yay_die "not a version: $1"
  ma="$(printf '%s' "$cur" | cut -d. -f1)"; mi="$(printf '%s' "$cur" | cut -s -d. -f2)"; pa="$(printf '%s' "$cur" | cut -s -d. -f3)"
  mi="${mi:-0}"; pa="${pa:-0}"
  case "$part" in
    major) printf '%d.0.0\n' $((ma + 1)) ;;
    minor) printf '%d.%d.0\n' "$ma" $((mi + 1)) ;;
    patch) printf '%d.%d.%d\n' "$ma" "$mi" $((pa + 1)) ;;
    *) yay_die "bump must be major, minor, patch or x.y.z (got '$part')" ;;
  esac
}

# yay_commit_check <message-file-or-string>  -> 0 if the header is a valid
# conventional commit; prints the reason on stderr otherwise.
yay_commit_check() {
  local msg header type scope
  if [ -f "$1" ]; then msg="$(cat "$1")"; else msg="$1"; fi
  header="$(printf '%s\n' "$msg" | sed -n '/^[^#]/{p;q;}')"
  case "$header" in Merge\ *|Revert\ \"*|fixup!\ *|squash!\ *) return 0;; esac
  if ! printf '%s' "$header" | grep -Eq '^(feat|fix|perf|refactor|docs|test|build|ci|chore|revert)(\([a-z0-9][a-z0-9-]*\))?!?: [^ ].*$'; then
    echo "commit header must be 'type(scope): summary' with type in feat fix perf refactor docs test build ci chore revert: $header" >&2; return 1
  fi
  if [ "${#header}" -gt 72 ]; then echo "commit header is ${#header} chars; keep it at most 72" >&2; return 1; fi
  case "$header" in *.) echo "commit header must not end with a period" >&2; return 1;; esac
  scope="$(printf '%s' "$header" | sed -nE 's/^[a-z]+\(([^)]*)\).*/\1/p')"
  if [ -n "$scope" ]; then
    local scopes; scopes="$(yay_config_get git.scopes 2>/dev/null || true)"
    # Restrict only when the team listed scopes. The kit's own commits use
    # harness, release, changelog and knowledge, so those are always allowed.
    if [ -n "$scopes" ] && ! yay_in_list "$scope" "$scopes
harness
release
changelog
knowledge"; then
      echo "scope '$scope' is not in git.scopes ($(printf '%s' "$scopes" | tr '\n' ' '))" >&2; return 1
    fi
  fi
  return 0
}

yay_worktree_path() { printf '%s/.claude/worktrees/%s\n' "$(yay_repo_root)" "$1"; }

# yay_worktree_create <branch> [from-ref]  -> prints the worktree path.
# Reuses an existing worktree for the same branch.
yay_worktree_create() {
  local branch="$1" from="${2:-}" slug path existing
  slug="${branch#*/}"
  path="$(yay_worktree_path "$slug")"
  existing="$(yay_git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} $0=="branch " b {print p; exit}')"
  if [ -n "$existing" ]; then printf '%s\n' "$existing"; return; fi
  [ -n "$from" ] || from="$(yay_base_branch)"
  mkdir -p "$(dirname "$path")"
  if yay_git show-ref --verify --quiet "refs/heads/$branch"; then
    yay_git worktree add -q "$path" "$branch" >&2
  else
    yay_git worktree add -q -b "$branch" "$path" "$from" >&2
  fi
  printf '%s\n' "$path"
}
