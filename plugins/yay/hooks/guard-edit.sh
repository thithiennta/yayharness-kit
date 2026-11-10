#!/usr/bin/env bash
# PreToolUse Edit|Write|MultiEdit|NotebookEdit: block generated and kit-owned files.
. "$(dirname "$0")/_hook.sh"

file="$(hook_get tool_input.file_path)"; [ -n "$file" ] || file="$(hook_get tool_input.notebook_path)"
[ -n "$file" ] || exit 0
case "$file" in /*) ;; *) file="$(hook_get cwd)/$file" ;; esac
hook_use_repo "$(dirname "$file")"
root="$ROOT"
rel="${file#"$root"/}"

while IFS= read -r g; do
  [ -n "$g" ] || continue
  case "$g" in
    */) case "$rel" in "$g"*) hook_block "$rel is generated output (generatedPaths in .yay/config.json). Change its source and rerun the command that builds it (yayh config get commands.build).";; esac ;;
    *)  case "$rel" in "$g"|"$g"/*) hook_block "$rel is generated output (generatedPaths in .yay/config.json). Change its source and rerun the command that builds it.";; esac ;;
  esac
done <<LIST
$(yay_config_get generatedPaths 2>/dev/null || true)
LIST

case "$rel" in
  .yay/manifest.json)
    hook_block ".yay/manifest.json is written only by yayh (harness sync / manifest record)." ;;
  .claude/settings.json)
    hook_block ".claude/settings.json is kit-owned. Put repo settings in .yay/settings.extra.json, then run 'yayh harness sync --only=settings'. Personal settings go in .claude/settings.local.json." ;;
  .claude/rules/yay-*.md|.github/pull_request_template.md)
    hook_block "$rel is kit-owned. Run /yay:harness-update to change it, or add a repo rule in .claude/rules/ without the yay- prefix." ;;
esac

# The managed CLAUDE.md block: block edits that touch its text.
if [ "$rel" = CLAUDE.md ]; then
  old="$(hook_get tool_input.old_string)"
  if [ -n "$old" ] && [ -f "$file" ]; then
    block="$(awk '/<!-- yay:managed:start/{on=1} on{print} /<!-- yay:managed:end -->/{on=0}' "$file")"
    first="$(printf '%s\n' "$old" | sed -n '/[^[:space:]]/{p;q;}')"
    if [ -n "$first" ] && case "$block" in *"$first"*) true;; *) false;; esac; then
      hook_block "that text is in the kit-managed block of CLAUDE.md. Edit the yay:project block (or outside both blocks) instead, or change the kit and run /yay:harness-update."
    fi
  fi
  # A whole-file Write must keep the managed block byte-for-byte.
  content="$(hook_get tool_input.content)"
  if [ -n "$content" ] && [ -f "$file" ] && grep -q '<!-- yay:managed:start' "$file"; then
    cur="$(awk '/<!-- yay:managed:start/{on=1} on{print} /<!-- yay:managed:end -->/{on=0}' "$file")"
    new="$(printf '%s\n' "$content" | awk '/<!-- yay:managed:start/{on=1} on{print} /<!-- yay:managed:end -->/{on=0}')"
    [ "$cur" = "$new" ] || hook_block "writing CLAUDE.md would change its kit-managed block. Keep that block exactly as it is, or use Edit on the project block."
  fi
fi
exit 0
