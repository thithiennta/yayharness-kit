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

# yay_branch_name <type> <text> [--id=P-4]  -> type/slug, after checking type is
# allowed. With an id, the slug leads with it: feat/p-4-refund-window.
yay_branch_name() {
  local type="$1" id="" a text=""; shift
  for a in "$@"; do case "$a" in --id=*) id="${a#--id=}";; *) text="${text:+$text }$a";; esac; done
  yay_in_list "$type" "$(yay_config_get git.branchTypes)" \
    || yay_die "branch type '$type' is not in git.branchTypes ($(yay_config_get git.branchTypes | tr '\n' ' '))"
  if [ -n "$id" ]; then
    printf '%s' "$id" | grep -Eq '^(P|B|R)-[0-9]+$' || yay_die "branch id must be P-<n>, B-<n> or R-<n> (got '$id')"
    # Don't double it when the title already starts with the id.
    case "$text" in "$id"|"$id "*|"$id:"*) ;; *) text="$id $text";; esac
  fi
  printf '%s/%s\n' "$type" "$(yay_slugify "$text")"
}

# yay_branch_id <branch>  -> the artifact id a branch leads with (feat/p-4-x -> P-4), or exit 1.
yay_branch_id() {
  local slug="${1#*/}" id
  case "$1" in */*) ;; *) return 1;; esac
  id="$(printf '%s' "$slug" | sed -nE 's/^(p|b|r)-([0-9]+)(-.*)?$/\1-\2/p')"
  [ -n "$id" ] || return 1
  printf '%s\n' "$id" | tr '[:lower:]' '[:upper:]'
}

# yay_commit_id_check <message> <branch>: on a branch that leads with an id, the
# summary leads with it too (`feat(scope): P-4 add …`). A hint, never a block.
yay_commit_id_check() {
  local header id summary; header="$(_yay_commit_header "$1")"
  id="$(yay_branch_id "$2")" || return 0
  case "$header" in Merge\ *|Revert\ \"*|fixup!\ *|squash!\ *) return 0;; esac
  summary="${header#*: }"
  case "$summary" in "$id"|"$id "*) return 0;; esac
  echo "branch '$2' is for $id; lead the summary with it: <type>(<scope>): $id <summary>" >&2
  return 1
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
  yay_git tag --list "$glob" --sort=-v:refname | sed -n 1p
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
# conventional commit with the kit's style; prints the reasons on stderr otherwise.
yay_commit_check() { yay_commit_shape "$1" && yay_commit_style "$1"; }

_yay_commit_header() {
  local msg; if [ -f "$1" ]; then msg="$(cat "$1")"; else msg="$1"; fi
  printf '%s\n' "$msg" | sed -n '/^[^#]/{p;q;}'
}

# yay_commit_shape <message>: the header is `type(scope): summary`. The changelog
# and release notes are built from it, so the post-commit hook blocks on this one.
yay_commit_shape() {
  local header; header="$(_yay_commit_header "$1")"
  case "$header" in Merge\ *|Revert\ \"*|fixup!\ *|squash!\ *) return 0;; esac
  printf '%s' "$header" | grep -Eq '^(feat|fix|perf|refactor|docs|test|build|ci|chore|revert)(\([a-z0-9][a-z0-9-]*\))?!?: [^ ].*$' && return 0
  echo "commit header must be 'type(scope): summary' with type in feat fix perf refactor docs test build ci chore revert: $header" >&2
  return 1
}

# yay_commit_style <message>: length, final period and allowed scope. The
# post-commit hook only hints about these. Prints every problem; exit 1 if any.
yay_commit_style() {
  local header scope bad=0; header="$(_yay_commit_header "$1")"
  case "$header" in Merge\ *|Revert\ \"*|fixup!\ *|squash!\ *) return 0;; esac
  if [ "${#header}" -gt 72 ]; then echo "commit header is ${#header} chars; keep it at most 72" >&2; bad=1; fi
  case "$header" in *.) echo "commit header must not end with a period" >&2; bad=1;; esac
  scope="$(printf '%s' "$header" | sed -nE 's/^[a-z]+\(([^)]*)\).*/\1/p')"
  if [ -n "$scope" ]; then
    local scopes; scopes="$(yay_config_get git.scopes 2>/dev/null || true)"
    # Restrict only when the team listed scopes. The kit's own commits use
    # harness, release, changelog, knowledge and roadmap, so those are always allowed.
    if [ -n "$scopes" ] && ! yay_in_list "$scope" "$scopes
harness
release
changelog
knowledge
roadmap"; then
      echo "scope '$scope' is not in git.scopes ($(printf '%s' "$scopes" | tr '\n' ' '))" >&2; bad=1
    fi
  fi
  return "$bad"
}

# yay_merged_worktrees [base] -> "<path><TAB><branch>" for .claude/worktrees/*
# whose branch is fully merged into base (safe to remove).
yay_merged_worktrees() {
  local base="${1:-$(yay_base_branch)}" root path br
  root="$(yay_repo_root)"
  yay_git worktree list --porcelain | awk '/^worktree /{p=substr($0,10)} /^branch refs\/heads\//{print p "\t" substr($0,19)}' \
  | while IFS="$(printf '\t')" read -r path br; do
      case "$path" in "$root"/.claude/worktrees/*) ;; *) continue;; esac
      if yay_git merge-base --is-ancestor "$br" "$base" 2>/dev/null; then printf '%s\t%s\n' "$path" "$br"; fi
    done
}

# yay_worktree_roots -> this checkout, then every other worktree of the repo (one path per line).
yay_worktree_roots() {
  local root p; root="$(cd "$(yay_repo_root)" && pwd -P)"
  printf '%s\n' "$root"
  git -C "$root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | while IFS= read -r p; do
    [ -d "$p" ] || continue
    p="$(cd "$p" && pwd -P)"
    [ "$p" = "$root" ] || printf '%s\n' "$p"
  done
}

# yay_id_lock / yay_id_unlock: a repo-wide lock (shared by all worktrees) so two
# agents creating artifacts at once can't take the same id. Stale after 60s.
yay_id_lock() {
  local d i=0
  d="$(git -C "$(yay_repo_root)" rev-parse --git-common-dir 2>/dev/null)" || return 0
  case "$d" in /*) ;; *) d="$(yay_repo_root)/$d" ;; esac
  YAY_ID_LOCK="$d/yay-id.lock"
  while ! mkdir "$YAY_ID_LOCK" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 300 ]; then rmdir "$YAY_ID_LOCK" 2>/dev/null; i=0; continue; fi
    sleep 0.2
  done
}
yay_id_unlock() { [ -z "${YAY_ID_LOCK:-}" ] || rmdir "$YAY_ID_LOCK" 2>/dev/null; YAY_ID_LOCK=""; }

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
