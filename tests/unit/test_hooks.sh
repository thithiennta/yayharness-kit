# engine-independent
# hooks: feed the JSON Claude Code sends on stdin, check exit codes

FIX="${KIT%/plugins/yay}/tests/fixtures/build.sh"
H="$KIT/hooks"

_repo() { # initialized bare fixture on a feature branch
  local d="$T_TMP/h.$RANDOM"
  "$FIX" bare "$d" >/dev/null
  git -C "$d" switch -q -c chore/yay-harness
  YAY_REPO="$d" "$YAYH" harness wipe --yes >/dev/null
  mkdir -p "$d/.yay"; YAY_REPO="$d" "$YAYH" harness detect 2>/dev/null > "$d/.yay/config.json"
  YAY_REPO="$d" "$YAYH" harness sync >/dev/null
  git -C "$d" add -A; git -C "$d" commit -q -m "chore(harness): install" --no-verify
  # As after the init PR merges: the base branch has the harness too.
  git -C "$d" switch -q dev; git -C "$d" merge -q --ff-only chore/yay-harness; git -C "$d" switch -q chore/yay-harness
  printf '%s\n' "$d"
}

_edit() { # hook file_path [old_string]
  local p; p="$(jq -nc --arg f "$2" --arg o "${3:-}" --arg c "$PWD" '{tool_name:"Edit",cwd:$c,tool_input:{file_path:$f,old_string:$o,new_string:"x"}}')"
  printf '%s' "$p" | CLAUDE_PLUGIN_ROOT="$KIT" "$H/$1"
}
_bash() { # hook cwd command
  local p; p="$(jq -nc --arg c "$2" --arg cmd "$3" '{tool_name:"Bash",cwd:$c,tool_input:{command:$cmd}}')"
  printf '%s' "$p" | CLAUDE_PLUGIN_ROOT="$KIT" "$H/$1"
}

test_hooks_json_is_valid_and_scripts_exist() {
  assert_ok jq -e '.hooks.PreToolUse and .hooks.PostToolUse and .hooks.SessionStart' "$H/hooks.json"
  local s
  for s in guard-edit.sh guard-bash.sh check-commit.sh session-start.sh; do
    if [ -x "$H/$s" ]; then _pass; else _fail "$s not executable"; fi
  done
}

test_edit_outside_yay_repo_is_ignored() {
  local d; d="$(mk_repo)"
  assert_exit 0 _edit guard-edit.sh "$d/assets/dist/x.js"
  assert_exit 0 _edit guard-edit.sh "/tmp/not-a-repo/file.txt"
}

test_edit_generated_and_kit_owned_blocked() {
  local r; r="$(_repo)"
  mkdir -p "$r/vendor"
  assert_exit 2 _edit guard-edit.sh "$r/vendor/autoload.php"
  assert_exit 2 _edit guard-edit.sh "$r/release/x.zip"
  assert_exit 2 _edit guard-edit.sh "$r/.yay/manifest.json"
  assert_exit 2 _edit guard-edit.sh "$r/.claude/settings.json"
  assert_exit 2 _edit guard-edit.sh "$r/.claude/rules/yay-git.md"
  assert_exit 0 _edit guard-edit.sh "$r/.claude/rules/team-rule.md"
  assert_exit 0 _edit guard-edit.sh "$r/includes/Plugin.php"
  assert_exit 0 _edit guard-edit.sh "$r/.yay/config.json"
  assert_exit 0 _edit guard-edit.sh "$r/vendorish/file.php"
}

test_edit_in_worktree_is_guarded_too() {
  local r p; r="$(_repo)"
  p="$(YAY_REPO="$r" "$YAYH" git worktree feat/x)"
  assert_exit 2 _edit guard-edit.sh "$p/vendor/a.php"
  assert_exit 0 _edit guard-edit.sh "$p/includes/Plugin.php"
}

test_claude_md_managed_block_protected() {
  local r; r="$(_repo)"
  assert_exit 2 _edit guard-edit.sh "$r/CLAUDE.md" "This repo uses the **yay** harness."
  assert_exit 0 _edit guard-edit.sh "$r/CLAUDE.md" "_Project knowledge has not been written yet."
}

test_commit_on_base_branch_blocked() {
  local r; r="$(_repo)"
  git -C "$r" switch -q dev
  assert_exit 2 _bash guard-bash.sh "$r" 'git commit -m "feat: x"'
  assert_exit 2 _bash guard-bash.sh "/" "git -C $r commit -m 'feat: x'"
  assert_exit 2 _bash guard-bash.sh "/" "cd $r && git add -A && git commit -m 'feat: x'"
  git -C "$r" switch -q chore/yay-harness
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "feat: x"'
}

test_no_verify_blocked_but_unrelated_flags_fine() {
  local r; r="$(_repo)"
  assert_exit 2 _bash guard-bash.sh "$r" 'git commit --no-verify -m "feat: x"'
  assert_exit 2 _bash guard-bash.sh "$r" 'git commit -nm "feat: x"'
  assert_exit 0 _bash guard-bash.sh "$r" 'head -n 5 file && git commit -m "feat: x"'
  assert_exit 0 _bash guard-bash.sh "$r" 'git status && ls -la'
}

test_debug_markers_block_commit() {
  local r; r="$(_repo)"
  printf '<?php\nerror_log( "x" ); // yay:debug\n' > "$r/includes/Debug.php"
  git -C "$r" add includes/Debug.php
  assert_exit 2 _bash guard-bash.sh "$r" 'git commit -m "fix: x"'
  git -C "$r" reset -q
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "fix: x"'        # untracked, not committed
  printf '\n// yay:debug\n' >> "$r/includes/Plugin.php"                  # tracked, unstaged
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "fix: x"'
  assert_exit 2 _bash guard-bash.sh "$r" 'git commit -am "fix: x"'       # -a includes it
  git -C "$r" checkout -q -- includes/Plugin.php
  git -C "$r" add includes/Debug.php; git -C "$r" commit -qm "test: seed" --no-verify
  printf '<?php\n// clean\n' > "$r/includes/Debug.php"; git -C "$r" add -A
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "fix: remove debug"'   # removing markers is fine
}

test_tag_creation_reserved_for_release() {
  local r; r="$(_repo)"
  assert_exit 2 _bash guard-bash.sh "$r" 'git tag -a v1.3.0 -m v1.3.0'
  assert_exit 2 _bash guard-bash.sh "$r" 'git tag v1.3.0'
  assert_exit 0 _bash guard-bash.sh "$r" 'YAY_RELEASE=1 git tag -a v1.3.0 -m v1.3.0'
  assert_exit 0 _bash guard-bash.sh "$r" 'git tag --list "v*"'
  assert_exit 0 _bash guard-bash.sh "$r" 'git tag'
}

test_post_commit_checks_message_and_branch() {
  local r; r="$(_repo)"
  echo a >> "$r/a.txt"; git -C "$r" add -A; git -C "$r" commit -qm "Added stuff" --no-verify
  assert_exit 2 _bash check-commit.sh "$r" 'git commit -m "Added stuff"'
  git -C "$r" commit -q --amend -m "feat(core): add stuff" --no-verify
  assert_exit 0 _bash check-commit.sh "$r" 'git commit --amend -m "feat(core): add stuff"'
  git -C "$r" switch -q -c "my-branch"
  echo b >> "$r/a.txt"; git -C "$r" commit -qam "feat: more" --no-verify
  local err; err="$(_bash check-commit.sh "$r" 'git commit -am "feat: more"' 2>&1)"
  assert_contains "$err" "branch 'my-branch'"
  assert_exit 0 _bash check-commit.sh "$r" 'git status'
}

test_session_start_reports_outdated() {
  local r; r="$(_repo)"
  assert_eq "" "$(_bash session-start.sh "$r" '')"
  sed -i.bak 's/"kitVersion": *"[^"]*"/"kitVersion": "0.0.1"/' "$r/.yay/manifest.json"
  assert_contains "$(_bash session-start.sh "$r" '')" "/yay:harness-update"
}
