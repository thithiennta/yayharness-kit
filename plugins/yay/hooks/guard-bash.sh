#!/usr/bin/env bash
# PreToolUse Bash: guard `git commit` (base branch, --no-verify, yay:debug
# markers in what is being committed) and `git tag` outside /yay:release.
. "$(dirname "$0")/_hook.sh"

cmd="$(hook_get tool_input.command)"
[ -n "$cmd" ] || exit 0
re="${GIT_RE}(commit|tag)([[:space:]]|\$)"
printf '%s' "$cmd" | grep -Eq "$re" || exit 0
sub="$(printf '%s' "$cmd" | grep -Eo "$re" | sed -n 1p | grep -Eo '(commit|tag)([[:space:]]|$)' | tr -d '[:space:]')"
hook_use_repo "$(hook_cmd_dir "$cmd")"
root="$ROOT"
args="$(hook_sub_args "$cmd" "$sub")"

if [ "$sub" = tag ]; then
  # Listing / deleting local tags is fine; creating one belongs to /yay:release.
  if printf ' %s' "$args" | grep -Eq '^[[:space:]]+(-a|-s|-m|-f|[^-[:space:]])' \
     && ! printf '%s' "$cmd" | grep -q 'YAY_RELEASE=1'; then
    hook_block "release tags are created only by /yay:release (it runs the tag with YAY_RELEASE=1)."
  fi
  exit 0
fi

printf ' %s ' "$args" | grep -Eq -- '[[:space:]](--no-verify|-n|-[a-zA-Z]*n[a-zA-Z]*)[[:space:]]' \
  && hook_block "don't bypass hooks with --no-verify; fix what the hook reports."

br="$(git -C "$root" branch --show-current 2>/dev/null)"
base="$(yay_config_get git.baseBranch 2>/dev/null || true)"
if [ -n "$br" ] && [ "$br" = "$base" ]; then
  hook_block "you're on the base branch '$base'. Commit on a <type>/<slug> branch: yayh git branch-name <type> \"<title>\", then yayh git worktree <branch>."
fi

# Lines being added that still carry a yay:debug marker.
# A marker is a code comment carrying the tag (// # /* <!-- {/* forms), in a
# non-markdown file, so docs and kit text that merely mention it don't count.
if printf ' %s ' "$args" | grep -Eq -- '[[:space:]](--all|-[a-zA-Z]*a[a-zA-Z]*)[[:space:]]'; then
  added="$(git -C "$root" diff HEAD -- . ':(exclude)*.md' ':(exclude)*.mdx' 2>/dev/null)"
else
  added="$(git -C "$root" diff --cached -- . ':(exclude)*.md' ':(exclude)*.mdx' 2>/dev/null)"
fi
hits="$(printf '%s\n' "$added" | grep -E '^\+([^+]|$)' | grep -E '(//|#|/\*|<!--)[[:space:]]*yay:debug' | sed -n '1,3p' || true)"
[ -z "$hits" ] || hook_block "staged changes still contain yay:debug instrumentation; remove it before committing:
$hits"
exit 0
