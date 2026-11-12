# engine-independent
# hooks: feed the JSON Claude Code sends on stdin, check exit codes

H="$KIT/hooks"

_repo() { # initialized bare fixture on a feature branch
  # As after the init PR merges: the base branch has the harness too.
  local d; d="$(fixture_repo bare merged)" || return 1
  git -C "$d" switch -q chore/yay-harness
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
  # roadmap: version lists are generated, sprint files are edited
  assert_exit 2 _edit guard-edit.sh "$r/docs/roadmap/v1.5.0.md"
  assert_exit 0 _edit guard-edit.sh "$r/docs/roadmap/sprint-2.md"
  assert_exit 0 _edit guard-edit.sh "$r/docs/roadmap/README.md"
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
  # style problems are hints: exit 0, with the hint as additional context
  local out; out="$(_bash check-commit.sh "$r" 'git commit -am "feat: more"' 2>&1)"
  assert_exit 0 _bash check-commit.sh "$r" 'git commit -am "feat: more"'
  assert_contains "$out" '"additionalContext":"yay git hints (not blocking'
  assert_contains "$out" "branch 'my-branch'"
  git -C "$r" switch -q -c feat/ok
  echo c >> "$r/a.txt"; git -C "$r" commit -qam "feat(core): a header that ends with a period." --no-verify
  assert_exit 0 _bash check-commit.sh "$r" 'git commit -am x'
  assert_contains "$(_bash check-commit.sh "$r" 'git commit -am x')" "must not end with a period"
  assert_eq "" "$(git -C "$r" commit -q --amend -m "feat(core): clean" --no-verify; _bash check-commit.sh "$r" 'git commit --amend')"
  # a strict repo blocks on style again
  printf '{ "workflow": { "strictness": "strict" } }\n' > "$r/.yay/local.json"
  git -C "$r" commit -q --amend -m "feat(core): ends with a period." --no-verify
  assert_exit 2 _bash check-commit.sh "$r" 'git commit --amend'
  assert_exit 0 _bash check-commit.sh "$r" 'git status'
}

test_session_start_reports_outdated() {
  local r; r="$(_repo)"
  case "$(_bash session-start.sh "$r" '')" in *harness-update*) _fail "current harness reported outdated" ;; *) _pass ;; esac
  sed -i.bak 's/"kitVersion": *"[^"]*"/"kitVersion": "0.0.1"/' "$r/.yay/manifest.json"
  assert_contains "$(_bash session-start.sh "$r" '')" "/yay:harness-update"
}

test_session_start_loads_code_rules_only_in_yay_repos() {
  local r out; r="$(_repo)"
  out="$(_bash session-start.sh "$r" '')"
  assert_contains "$out" "yay code rules (loaded by the yay plugin for this repo):"
  assert_contains "$out" "Never edit, extend or reword an existing comment"
  assert_contains "$out" "Search before creating"
  assert_contains "$out" "yay asking rules (loaded by the yay plugin for this repo):"
  assert_contains "$out" "At most one round of 1–3 questions, and only the hardest ones."
  case "$out" in *"# yay code rules"*) _fail "title line leaked" ;; *) _pass ;; esac
  assert_eq "" "$(_bash session-start.sh "$(mk_repo)" '')"
}

test_session_start_says_where_the_work_stands() {
  local r out; r="$(_repo)"
  case "$(_bash session-start.sh "$r" '')" in *"work in flight"*|*"this branch is"*) _fail "nothing in flight was reported" ;; *) _pass ;; esac
  mkdir -p "$r/docs/plans" "$r/docs/bugs"
  printf -- '---\nid: P-1\ntitle: Gift wrap\nstatus: in-progress\nbranch: chore/yay-harness\n---\n## Tasks\n- [x] T1 a\n- [ ] T2 b\n' > "$r/docs/plans/gift.md"
  printf -- '---\nid: B-1\ntitle: Crash\nstatus: root-caused\nseverity: high\n---\n' > "$r/docs/bugs/b1.md"
  out="$(_bash session-start.sh "$r" '')"
  assert_contains "$out" 'yay: this branch is P-1 "Gift wrap · 1/2 tasks" (in-progress). Next: /yay:implement P-1 --continue'
  git -C "$r" switch -q -c feat/other
  out="$(_bash session-start.sh "$r" '')"
  assert_contains "$out" "yay: work in flight"
  assert_contains "$out" "- P-1 Gift wrap · 1/2 tasks (plan, continue): /yay:implement P-1 --continue"
  assert_contains "$out" "- B-1 Crash (high) (bug, fix): /yay:fix B-1"
}

test_debug_check_ignores_mentions_and_markdown() {
  local r; r="$(_repo)"
  printf '# notes\nUse `// yay:debug` markers.\n' > "$r/docs/x.md"
  printf '<?php\n// Run /yay:debug first; see yay:debug docs.\n' > "$r/includes/Doc.php"
  git -C "$r" add -A
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "docs: x"'
  for m in '// yay:debug' '# yay:debug' '/* yay:debug */' '<!-- yay:debug -->' '{/* yay:debug */}'; do
    printf 'x %s\n' "$m" > "$r/includes/M.php"; git -C "$r" add includes/M.php
    assert_exit 2 _bash guard-bash.sh "$r" 'git commit -m "fix: x"'
  done
}

test_kit_install_is_committable_through_hooks() {
  local r; r="$(_repo)"
  echo "tweak" > "$r/new.txt"; git -C "$r" add -A
  YAY_REPO="$r" "$YAYH" harness sync --force >/dev/null; git -C "$r" add -A
  assert_exit 0 _bash guard-bash.sh "$r" 'git commit -m "chore(harness): update"'
}

_hint() { # repo file old new  (Edit; empty old = Write)
  local p
  if [ -n "$3" ]; then p="$(jq -nc --arg f "$1/$2" --arg o "$3" --arg n "$4" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}')"
  else p="$(jq -nc --arg f "$1/$2" --arg n "$4" '{tool_name:"Write",tool_input:{file_path:$f,content:$n}}')"; fi
  printf '%s' "$p" | CLAUDE_PLUGIN_ROOT="$KIT" "$H/hint-edit.sh"
}

test_hint_edit_reuse_and_comments() {
  local r; r="$(_repo)"
  mkdir -p "$r/includes"
  printf '<?php\nfinal class Format {\n\t/** A fee as a store price. */\n\tpublic static function price( float $a ): string { return wc_price( $a ); }\n}\n' > "$r/includes/Format.php"
  git -C "$r" add -A; git -C "$r" commit -qm "feat: format" --no-verify
  # new look-alike function (file already written, as PostToolUse sees it)
  printf '<?php\nfunction giftly_format_price( $a ) { return wc_price( $a ); }\n' > "$r/includes/fee.php"
  local out; out="$(_hint "$r" includes/fee.php "" "$(cat "$r/includes/fee.php")")"
  assert_contains "$out" '"additionalContext":"yay code hints (not blocking): You just added giftly_format_price(). Similar code already exists: Format::price (includes/Format.php:4)'
  assert_ok jq -e . <<<"$out"
  # comment-only edit
  out="$(_hint "$r" includes/Format.php $'\t// Old wording.\n\t$x = 1;' $'\t// New, better wording.\n\t$x = 1;')"
  assert_contains "$out" "changes only comments"
  # code change that also rewrites an existing comment
  out="$(_hint "$r" includes/Format.php $'\t// Keep me.\n\t$x = 1;' $'\t// Keep me, and more.\n\t$x = 2;')"
  assert_contains "$out" "rewrote or removed 1 existing comment line(s)"
  # several new inline comments for little code
  out="$(_hint "$r" includes/Format.php $'\t$x = 1;' $'\t// This sets x.\n\t// It is one.\n\t$x = 1;\n\t$y = 2;')"
  assert_contains "$out" "adds 2 inline comment line(s)"
  # clean edits and exemptions say nothing
  assert_eq "" "$(_hint "$r" includes/Format.php $'\t$x = 1;' $'\t$x = 2;')"
  assert_eq "" "$(_hint "$r" includes/Format.php $'\t$x = 1;' $'\t/* translators: %s: name */\n\t// phpcs:ignore WordPress.Security -- escaped above\n\t$x = 1;')"
  assert_eq "" "$(_hint "$r" readme.txt 'a' 'b // c // d')"
  assert_eq "" "$(_hint "$(mk_repo)" x.php $'$x;' $'// a\n// b\n$x;')"
}
