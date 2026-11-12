# asset add/list/move: screenshots kept with an artifact under docs/assets/<ID>/

_srepo() { # initialized fixture, harness merged into dev, on dev
  fixture_repo bare merged
}

_png() { # <path>: a tiny file with an image name
  mkdir -p "$(dirname "$1")"; printf '\211PNG\r\n' > "$1"
}

test_asset_add_copies_numbers_and_links() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  local p shot out
  p="$("$YAYH" artifact new plan "Gift preview")"
  shot="$T_TMP/Screenshot 2026-11-12 at 10.01.png"; _png "$shot"
  out="$("$YAYH" asset add P-1 "$shot" "Preview overlaps the total")"
  assert_eq "added	docs/assets/P-1/1-preview-overlaps-the-total.png	![Preview overlaps the total](../assets/P-1/1-preview-overlaps-the-total.png)" "$out"
  assert_file "$YAY_REPO/docs/assets/P-1/1-preview-overlaps-the-total.png"
  assert_file "$shot"                                        # the original stays
  # no caption: named after the file; .JPEG becomes .jpg
  _png "$T_TMP/Mobile View.JPEG"
  assert_contains "$("$YAYH" asset add P-1 "$T_TMP/Mobile View.JPEG")" "docs/assets/P-1/2-mobile-view.jpg"
  assert_eq "docs/assets/P-1/1-preview-overlaps-the-total.png
docs/assets/P-1/2-mobile-view.jpg" "$("$YAYH" asset list P-1)"
  assert_eq "" "$("$YAYH" asset list P-9)"
  # the link resolves from the plan's folder
  assert_file "$YAY_REPO/$(dirname "$p")/../assets/P-1/2-mobile-view.jpg"
  # screenshot files never count as ids
  assert_eq "P-2" "$("$YAYH" id next P)"
}

test_asset_add_refuses_bad_input() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  "$YAYH" artifact new plan "Gift preview" >/dev/null
  _png "$T_TMP/a.png"; printf 'x' > "$T_TMP/notes.txt"
  assert_fails "$YAYH" asset add P-7 "$T_TMP/a.png"             # no such artifact yet
  assert_fails "$YAYH" asset add plan-1 "$T_TMP/a.png"          # not an id
  assert_fails "$YAYH" asset add P-1 "$T_TMP/notes.txt"         # not an image
  assert_contains "$("$YAYH" asset add P-1 "$T_TMP/missing.png" 2>&1)" "drag the file into the terminal"
  assert_no_file "$YAY_REPO/docs/assets/P-1"
}

test_asset_add_works_for_a_roadmap_item() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  local id; id="$("$YAYH" roadmap add "Gift wrap option" sprint=later size=S | sed -n 's/.*\(R-[0-9]*\).*/\1/p' | sed -n 1p)"
  [ -n "$id" ] || id="$(sed -n 's/^### \(R-[0-9]*\) Gift wrap option.*/\1/p' "$YAY_REPO"/docs/roadmap/*.md | sed -n 1p)"
  _png "$T_TMP/wrap.png"
  assert_contains "$("$YAYH" asset add "$id" "$T_TMP/wrap.png" "Wrap toggle")" "docs/assets/$id/1-wrap-toggle.png"
}

test_asset_move_follows_a_renumber() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  "$YAYH" artifact new plan "Gift preview" >/dev/null
  _png "$T_TMP/a.png"; _png "$T_TMP/b.png"
  "$YAYH" asset add P-1 "$T_TMP/a.png" >/dev/null
  git -C "$YAY_REPO" add docs/assets; git -C "$YAY_REPO" commit -qm "docs: shot" --no-verify
  "$YAYH" asset add P-1 "$T_TMP/b.png" >/dev/null             # untracked
  assert_eq "moved	docs/assets/P-1	docs/assets/P-4" "$("$YAYH" asset move P-1 P-4)"
  assert_eq "docs/assets/P-4/1-a.png
docs/assets/P-4/2-b.png" "$("$YAYH" asset list P-4)"
  assert_no_file "$YAY_REPO/docs/assets/P-1"
  assert_contains "$(git -C "$YAY_REPO" status --porcelain)" "R  docs/assets/P-1/1-a.png -> docs/assets/P-4/1-a.png"
  assert_eq "none	docs/assets/P-2" "$("$YAYH" asset move P-2 P-5)"
  _png "$YAY_REPO/docs/assets/P-6/x.png"
  assert_fails "$YAYH" asset move P-4 P-6
}

test_carry_takes_untracked_screenshots_along() {
  export YAY_REPO; YAY_REPO="$(_srepo)"
  local p wt out
  p="$("$YAYH" artifact new plan "Carry shots")"
  _png "$T_TMP/a.png"; "$YAYH" asset add P-1 "$T_TMP/a.png" >/dev/null
  wt="$("$YAYH" git worktree feat/carry-shots)"
  out="$("$YAYH" artifact carry "$wt" "$p")"
  assert_eq "carried	$p
carried	docs/assets/P-1/1-a.png" "$out"
  assert_file "$wt/docs/assets/P-1/1-a.png"
  assert_no_file "$YAY_REPO/docs/assets/P-1"
  # a folder can be carried on its own (a roadmap item's screenshots)
  mkdir -p "$YAY_REPO/docs/assets/R-9"; _png "$YAY_REPO/docs/assets/R-9/1-x.png"
  assert_eq "carried	docs/assets/R-9/1-x.png" "$("$YAYH" artifact carry "$wt" docs/assets/R-9/)"
  assert_file "$wt/docs/assets/R-9/1-x.png"
}
