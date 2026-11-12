#!/usr/bin/env bash
# PostToolUse Bash: after a `git commit`, check the new commit's message and
# branch name. A header the changelog can't read exits 2; style problems are hints.
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
# Only a header the changelog can't read blocks. Style (length, period, scope,
# branch name) is a hint: the commit stands, and Claude amends it if it's worth it.
if ! err="$(yay_commit_shape "$msg" 2>&1)"; then
  printf 'yay: the last commit breaks the git conventions (.claude/rules/yay-git.md):\n%s\nFix it with: git commit --amend -m "<type>(<scope>): <summary>" (keep the trailers).\n' "$err" >&2
  exit 2
fi
hints="$(yay_commit_style "$msg" 2>&1 || true)"
br="$(git -C "$root" branch --show-current 2>/dev/null)"
if [ -n "$br" ] && ! idh="$(yay_commit_id_check "$msg" "$br" 2>&1)"; then
  hints="${hints:+$hints
}$idh"
fi
if [ -n "$br" ] && ! yay_branch_check "$br"; then
  hints="${hints:+$hints
}branch '$br' doesn't follow <type>/<slug> (types: $(yay_config_get git.branchTypes | tr '\n' ' ')). Rename it with 'git branch -m <type>/<slug>' if it's yours and not pushed yet."
fi
[ -n "$hints" ] || exit 0
if [ "$(yay_strictness)" = strict ]; then
  printf 'yay: the last commit breaks the git conventions (.claude/rules/yay-git.md; this repo is strict):\n%s\nFix it with: git commit --amend -m "<type>(<scope>): <summary>" (keep the trailers).\n' "$hints" >&2
  exit 2
fi
msg="yay git hints (not blocking; amend with git commit --amend -m \"…\" if it's still local, keeping the trailers): $(printf '%s' "$hints" | tr '\n' ' ' | sed 's/ $//')"
esc="$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r' | tr '\t' ' ')"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$esc"
exit 0
