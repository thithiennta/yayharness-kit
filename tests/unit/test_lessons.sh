# engine-independent
# lessons: friction log per checkout

test_lessons_add_list_and_count() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  git -C "$YAY_REPO" commit -q --allow-empty -m init
  assert_eq "" "$("$YAYH" lessons list)"
  assert_eq "hook	P-2	commit scope 'ui' not in git.scopes" "$("$YAYH" lessons add "commit scope 'ui' not in git.scopes" kind=hook from=P-2)"
  "$YAYH" lessons add "composer test needs a test database" kind=env >/dev/null
  "$YAYH" lessons add "composer test needs a test database" kind=env from=P-3 >/dev/null
  assert_file "$YAY_REPO/.yay/runs/lessons.md"
  assert_eq "3" "$("$YAYH" lessons list | grep -vc '^count')"
  assert_contains "$("$YAYH" lessons list --counts)" "count	env	2"
  assert_eq "1" "$("$YAYH" lessons list --kind=hook | grep -vc '^count')"
  assert_exit 1 "$YAYH" lessons add "x" kind=nope
  assert_exit 1 "$YAYH" lessons add ""
}
