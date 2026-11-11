#!/usr/bin/env bash
# PostToolUse Edit|Write: non-blocking hints for reuse and comment discipline
# (reference/code-rules.md). Never blocks: it adds context for Claude, then exits 0.
#  - a new function whose name looks like an existing one -> "reuse X?"
#  - an edit that changes only comments, rewrites existing comments, or adds several
#    inline comment lines -> "leave comments alone"
. "$(dirname "$0")/_hook.sh"
. "$YAY_LIB_DIR/code.sh"

file="$(hook_get tool_input.file_path)"
[ -n "$file" ] || exit 0
case "$file" in *.php|*.js|*.jsx|*.ts|*.tsx|*.mjs) ;; *) exit 0 ;; esac
hook_use_repo "$(dirname "$file")"
rel="${file#"$ROOT"/}"
case "$rel" in vendor/*|*/vendor/*|node_modules/*|*/node_modules/*|tests/*|*/tests/*) exit 0 ;; esac

old="$(hook_get tool_input.old_string)"
new="$(hook_get tool_input.new_string)"
[ -n "$new" ] || new="$(hook_get tool_input.content)"
[ -n "$new" ] || exit 0

TAB="$(printf '\t')"
hints=""
add_hint() { hints="$hints$1
"; }

# --- new functions that look like existing ones -------------------------------
_defs() { # names defined in a code snippet
  printf '%s\n' "$1" | sed -nE \
    -e 's/.*function[[:space:]]+&?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' \
    -e 's/^[[:space:]]*(export[[:space:]]+)?const[[:space:]]+([A-Za-z_$][A-Za-z0-9_$]*)[[:space:]]*=[[:space:]]*(async[[:space:]]*)?\(.*=>.*/\2/p'
}
new_defs="$(_defs "$new")"
old_defs="$(_defs "$old")"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  case "$name" in __*) continue ;; esac
  if yay_in_list "$name" "$old_defs"; then continue; fi
  hits="$(yay_code_similar "$name" --limit=8 2>/dev/null | awk -F "$TAB" -v n="$name" -v f="$rel" '
    { split($2, loc, ":"); short = $4; sub(/.*(::|\.)/, "", short) }
    $1 >= 3 && !(short == n && loc[1] == f) && ($3 == "function" || $3 == "method") { printf "%s%s (%s)", (c++ ? "; " : ""), $4, $2; if (c == 3) exit }')"
  [ -z "$hits" ] || add_hint "You just added $name(). Similar code already exists: $hits. If one of these does the job, call it (or extend it) instead, and remove $name(). If not, be ready to say why in the PR."
done <<EOF
$new_defs
EOF

# --- comments ------------------------------------------------------------------
_is_exempt() { case "$1" in *translators:*|*phpcs:*|*@premium-*|*eslint-disable*|*@ts-*) return 0 ;; esac; return 1; }
_cmt_lines() { # inline comment lines (trimmed), exemptions removed
  printf '%s\n' "$1" | sed -nE 's/^[[:space:]]*((\/\/|#[^[]|\/\*[^*]).*)$/\1/p' | while IFS= read -r l; do _is_exempt "$l" || printf '%s\n' "$l"; done
}
_code_lines() { # non-comment, non-blank lines (trimmed)
  printf '%s\n' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -vE '^$|^(//|#|/\*|\*)' || true
}
if [ -n "$old" ]; then
  oc="$(_cmt_lines "$old")"; nc="$(_cmt_lines "$new")"
  ocode="$(_code_lines "$old")"; ncode="$(_code_lines "$new")"
  n_old="$(printf '%s' "$oc" | grep -c . || true)"; n_new="$(printf '%s' "$nc" | grep -c . || true)"
  gone=0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    yay_in_list "$l" "$nc" || gone=$((gone + 1))
  done <<EOF
$oc
EOF
  if [ "$ocode" = "$ncode" ] && [ "$oc" != "$nc" ]; then
    add_hint "This edit to $rel changes only comments. Change a comment only when the code it describes changed in this task. If it didn't, restore the original comment text."
  elif [ "$gone" -gt 0 ]; then
    add_hint "This edit rewrote or removed $gone existing comment line(s) in $rel. Keep existing comments word for word unless the code they describe changed."
  fi
  added=$((n_new - n_old)); [ "$added" -ge 0 ] || added=0
else
  added="$(_cmt_lines "$new" | grep -c . || true)"
fi
if [ "${added:-0}" -ge 2 ]; then
  ncode_n="$(_code_lines "$new" | grep -c . || true)"
  [ -z "$old" ] || ncode_n=$(( ncode_n - $(_code_lines "$old" | grep -c . || true) ))
  if [ "$added" -ge "${ncode_n:-0}" ] || [ "$added" -ge 4 ]; then
    add_hint "This edit adds $added inline comment line(s) to $rel. Comment only a non-obvious why about the line right below, never what the code plainly does or how other files behave. Put design reasoning in the commit or PR."
  fi
fi

[ -n "$hints" ] || exit 0
msg="yay code hints (not blocking): $(printf '%s' "$hints" | tr '\n' ' ' | sed 's/ $//')"
esc="$(printf '%s' "$msg" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r' | tr '\t' ' ')"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$esc"
exit 0
