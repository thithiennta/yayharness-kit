# manifest record/status, per JSON engine

_mf_repo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/.claude/rules"
  printf '# git rules\n' > "$r/.claude/rules/yay-git.md"
  cat > "$r/CLAUDE.md" <<'EOF'
# Team intro (team-owned)
<!-- yay:managed:start v=0.1.0 -->
managed text
<!-- yay:managed:end -->
<!-- yay:project:start -->
project text
<!-- yay:project:end -->
EOF
  printf '%s\n' "$r"
}

test_record_then_clean() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  "$YAYH" manifest record .claude/rules/yay-git.md rules/yay-git.md
  "$YAYH" manifest record "CLAUDE.md#managed" CLAUDE.managed.md
  assert_eq "clean	.claude/rules/yay-git.md
clean	CLAUDE.md#managed" "$("$YAYH" manifest status | sort)"
  assert_contains "$(cat "$YAY_REPO/.yay/manifest.json")" '"kitVersion"'
}

test_modified_and_missing() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  "$YAYH" manifest record .claude/rules/yay-git.md rules/yay-git.md
  "$YAYH" manifest record "CLAUDE.md#managed" CLAUDE.managed.md
  echo "edit" >> "$YAY_REPO/.claude/rules/yay-git.md"
  assert_eq "modified	.claude/rules/yay-git.md" "$("$YAYH" manifest status .claude/rules/yay-git.md)"
  rm "$YAY_REPO/.claude/rules/yay-git.md"
  assert_eq "missing	.claude/rules/yay-git.md" "$("$YAYH" manifest status .claude/rules/yay-git.md)"
}

test_managed_block_ignores_edits_outside_it() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  "$YAYH" manifest record "CLAUDE.md#managed"
  sed -i.bak 's/project text/project text changed/; s/Team intro/Team intro edited/' "$YAY_REPO/CLAUDE.md"
  assert_eq "clean	CLAUDE.md#managed" "$("$YAYH" manifest status)"
  sed -i.bak 's/managed text/managed text hand-edited/' "$YAY_REPO/CLAUDE.md"
  assert_eq "modified	CLAUDE.md#managed" "$("$YAYH" manifest status)"
}

test_missing_managed_block_is_missing() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  "$YAYH" manifest record "CLAUDE.md#managed"
  printf '# all custom now\n' > "$YAY_REPO/CLAUDE.md"
  assert_eq "missing	CLAUDE.md#managed" "$("$YAYH" manifest status)"
}

test_forget() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  "$YAYH" manifest record .claude/rules/yay-git.md
  "$YAYH" manifest forget .claude/rules/yay-git.md
  assert_eq "" "$("$YAYH" manifest status)"
}

test_record_unknown_file_fails() {
  export YAY_REPO; YAY_REPO="$(_mf_repo)"
  assert_fails "$YAYH" manifest record nope.md
}
