# git helpers (base branch, branch/commit checks, tags, bump, worktrees)

_git_repo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay"
  cat > "$r/.yay/config.json" <<'EOF'
{ "schemaVersion": 1, "plugin": { "name": "F", "slug": "f", "mainFile": "f.php" }, "editions": ["free"],
  "git": { "baseBranch": "main", "tagFormat": "v{version}", "scopes": ["core", "admin"] }, "commands": {} }
EOF
  echo x > "$r/f.php"; commit_all "$r"
  printf '%s\n' "$r"
}

test_base_branch_from_config() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  assert_eq "main" "$("$YAYH" git base)"
}

test_branch_name_and_check() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  assert_eq "fix/coupon-field-vanishes" "$("$YAYH" git branch-name fix "Coupon field vanishes!")"
  assert_fails "$YAYH" git branch-name wip "x"
  assert_ok "$YAYH" git branch-check feat/express-checkout
  assert_fails "$YAYH" git branch-check express-checkout
  assert_fails "$YAYH" git branch-check feat/Express_Checkout
  assert_fails "$YAYH" git branch-check wip/x
}

test_commit_check() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  assert_ok "$YAYH" git commit-check "feat(core): add express buttons"
  assert_ok "$YAYH" git commit-check "fix!: drop php 7.3"
  assert_ok "$YAYH" git commit-check "Merge branch 'dev'"
  assert_fails "$YAYH" git commit-check "Added stuff"
  assert_fails "$YAYH" git commit-check "feat: trailing period."
  assert_fails "$YAYH" git commit-check "feat(Core): bad scope case"
  assert_fails "$YAYH" git commit-check "feat(blocks): scope not allowed"
  assert_fails "$YAYH" git commit-check "feat(core): $(printf 'x%.0s' $(seq 1 70))"
  local m="$T_TMP/msg"; printf '# comment\nfix(admin): keep coupon field\n\nFixes: B-7\n' > "$m"
  assert_ok "$YAYH" git commit-check "$m"
}

test_tags_and_versions() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  assert_eq "" "$("$YAYH" git last-tag)"
  git -C "$YAY_REPO" tag -a v1.9.0 -m x; git -C "$YAY_REPO" tag -a v1.10.0 -m x; git -C "$YAY_REPO" tag -a other -m x
  assert_eq "v1.10.0" "$("$YAYH" git last-tag)"
  assert_eq "1.10.0" "$("$YAYH" git version-of-tag v1.10.0)"
  assert_eq "v2.0.0" "$("$YAYH" git tag-for 2.0.0)"
}

test_bump() {
  assert_eq "1.2.4" "$("$YAYH" git bump 1.2.3 patch)"
  assert_eq "1.3.0" "$("$YAYH" git bump 1.2.3 minor)"
  assert_eq "2.0.0" "$("$YAYH" git bump 1.2.3 major)"
  assert_eq "1.3.0" "$("$YAYH" git bump 1.2 minor)"
  assert_eq "1.2.4" "$("$YAYH" git bump 1.2.3-beta.1 patch)"
  assert_eq "5.0.1" "$("$YAYH" git bump 1.2.3 5.0.1)"
  assert_fails "$YAYH" git bump abc patch
  assert_fails "$YAYH" git bump 1.2.3 huge
}

test_worktree_create_and_reuse() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  local p p2
  p="$("$YAYH" git worktree feat/express-checkout)"
  assert_eq "$YAY_REPO/.claude/worktrees/express-checkout" "$p"
  assert_eq "feat/express-checkout" "$(git -C "$p" branch --show-current)"
  p2="$("$YAYH" git worktree feat/express-checkout)"
  assert_eq "$p" "$p2" "reuses existing worktree"
}

test_worktree_from_tag_for_hotfix() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  git -C "$YAY_REPO" tag -a v1.0.0 -m x
  echo y >> "$YAY_REPO/f.php"; commit_all "$YAY_REPO" "feat: after tag"
  local p; p="$("$YAYH" git worktree hotfix/urgent v1.0.0)"
  assert_eq "$(git -C "$YAY_REPO" rev-parse v1.0.0^{commit})" "$(git -C "$p" rev-parse HEAD)"
}

test_kit_scopes_always_allowed() {
  export YAY_REPO; YAY_REPO="$(_git_repo)"
  assert_ok "$YAYH" git commit-check "chore(harness): update yay harness to v0.2.0"
  assert_ok "$YAYH" git commit-check "chore(release): 1.4.0"
  assert_fails "$YAYH" git commit-check "feat(blocks): not allowed here"
}
