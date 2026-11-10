#!/usr/bin/env bash
# PostToolUse Bash: after a `git commit`, check the new commit's message and
# branch name. Exit 2 tells Claude what to amend.
. "$(dirname "$0")/_hook.sh"

cmd="$(hook_get tool_input.command)"
re="${GIT_RE}commit([[:space:]]|\$)"
printf '%s' "$cmd" | grep -Eq "$re" || exit 0
hook_use_repo "$(hook_cmd_dir "$cmd")"
root="$ROOT"

# Only judge a commit made in the last 2 minutes (the command may have failed).
now="$(date +%s)"; ct="$(git -C "$root" log -1 --format=%ct 2>/dev/null || echo 0)"
[ $((now - ct)) -le 120 ] || exit 0

msg="$(git -C "$root" log -1 --format=%B)"
problems=""
if ! err="$(yay_commit_check "$msg" 2>&1)"; then problems="$err"; fi
br="$(git -C "$root" branch --show-current 2>/dev/null)"
if [ -n "$br" ] && ! yay_branch_check "$br"; then
  problems="${problems:+$problems
}branch '$br' doesn't follow <type>/<slug> (types: $(yay_config_get git.branchTypes | tr '\n' ' ')). Rename it with 'git branch -m <type>/<slug>' if it's yours."
fi
[ -z "$problems" ] && exit 0
printf 'yay: the last commit breaks the git conventions (.claude/rules/yay-git.md):\n%s\nFix it with: git commit --amend -m "<type>(<scope>): <summary>" (keep the trailers).\n' "$problems" >&2
exit 2
