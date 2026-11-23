# item briefs: brief new/path/check/checks/render/list (docs/briefs/, linked from the roadmap item)

_brepo() { # a repo with a one-file roadmap: R-1 Gift wrap, R-2 Gói quà
  local d; d="$(mk_repo)"; mkdir -p "$d/docs"
  printf -- '---\nhorizon: 2027-01-01\nsprint_length: 2w\n---\n# Roadmap\n\n## Later\n\n### R-1 Gift wrap\n- status: todo\n- size: M\n\n### R-2 Gói quà tặng\n- status: todo\n- size: S\n' > "$d/docs/roadmap.md"
  printf '%s\n' "$d"
}

_bfill() { # brief file: a complete English brief
  cat > "$1" <<'EOF'
---
item: R-1
title: Gift wrap
status: draft
lang: en
author: test
created: 2026-11-23
---
# R-1 Gift wrap

## In one line
Shoppers can add gift wrap to an order at checkout for a small fee the store sets.

## Problem
- 14 support tickets this year asked for gift wrap

## What the user sees
1. At checkout the shopper sees "Add gift wrap (+$3)"
2. Ticking it adds the fee to the total

## Rules and edge cases
- Hidden when the cart only has downloads

## Out of scope
- Choosing a paper style

## Done when
- [ ] The option shows on both checkouts
- [ ] Ticking it adds the fee before paying
- [ ] The order email shows it

## Open questions
None
EOF
}

test_new_links_the_item_and_path_finds_it() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local f; f="$("$YAYH" brief new R-1)"
  assert_eq "docs/briefs/R-1-gift-wrap.md" "$f"
  assert_eq "$f" "$("$YAYH" roadmap get R-1 brief)"
  assert_eq "$f" "$("$YAYH" brief path R-1)"
  assert_eq "R-1" "$("$YAYH" fm get "$YAY_REPO/$f" item)"
  assert_eq "draft" "$("$YAYH" fm get "$YAY_REPO/$f" status)"
  assert_fails grep -q '{{' "$YAY_REPO/$f"
  assert_fails grep -q '^id:' "$YAY_REPO/$f"
  assert_eq "docs/roadmap.md" "$("$YAYH" artifact resolve R-1)"
  assert_exit 3 "$YAYH" brief path R-2
  assert_fails "$YAYH" brief new R-1
  assert_fails "$YAYH" brief new R-9
  assert_fails "$YAYH" brief new gift
  assert_contains "$("$YAYH" brief list)" "R-1	draft	Gift wrap	$f"
}

test_check_fails_on_the_template_and_passes_a_filled_brief() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local f out rc=0; f="$("$YAYH" brief new R-1)"
  out="$("$YAYH" brief check R-1 2>&1)" || rc=$?
  assert_eq 1 "$rc"
  assert_contains "$out" "error: '## What the user sees' is empty"
  assert_contains "$out" "error: '## Done when' has 0 checks"
  _bfill "$YAY_REPO/$f"
  assert_eq "" "$("$YAYH" brief check R-1 2>&1)"
  assert_eq 3 "$("$YAYH" brief checks R-1)"
}

test_check_enforces_done_when_out_of_scope_and_plain_words() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local f out; f="$YAY_REPO/$("$YAYH" brief new R-1)"
  _bfill "$f"
  sed -i.bak '/^- \[ \] The order email shows it$/d; s/^- Choosing a paper style$/None/; s/^- Hidden when the cart only has downloads$/- Hidden when is_virtual() is true/' "$f"; rm -f "$f.bak"
  out="$("$YAYH" brief check R-1 2>&1)" || true
  assert_contains "$out" "error: '## Done when' has 2 checks"
  assert_contains "$out" "warn: '## Out of scope' says nothing is out of scope"
  assert_contains "$out" "error: code name in '## Rules and edge cases'"
  printf '\n' > /dev/null
  awk '/^## Done when$/ { print; print "- The option shows"; next } { print }' "$f" > "$f.n" && mv "$f.n" "$f"
  assert_contains "$("$YAYH" brief check R-1 2>&1)" "write each check as - [ ]"
  "$YAYH" fm set "$f" status shipped
  assert_contains "$("$YAYH" brief check R-1 2>&1)" "error: front-matter status 'shipped' is not draft or ready"
}

test_render_writes_a_gitignored_page_with_checkboxes() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  local f html out; f="$YAY_REPO/$("$YAYH" brief new R-1)"
  _bfill "$f"
  html="$("$YAYH" brief render R-1)"
  assert_eq ".yay/briefs/R-1.html" "$html"
  out="$(cat "$YAY_REPO/$html")"
  assert_contains "$out" "<title>Gift wrap</title>"
  assert_contains "$out" '<li><input type="checkbox" disabled> The option shows on both checkouts</li>'
  assert_contains "$out" '<ol>'
  assert_eq "" "$(git -C "$YAY_REPO" status --porcelain -- .yay)"
  out="$("$YAYH" brief render R-1 --text)"
  assert_contains "$out" "- [ ] Ticking it adds the fee before paying"
  assert_not_contains "$out" "In one line"
}

test_vietnamese_brief_from_config() {
  export YAY_REPO; YAY_REPO="$(_brepo)"
  mkdir -p "$YAY_REPO/.yay"; printf '{"language":"vi"}\n' > "$YAY_REPO/.yay/local.json"
  local f out; f="$("$YAYH" brief new R-2)"
  assert_eq "docs/briefs/R-2-goi-qua-tang.md" "$f"
  assert_eq "vi" "$("$YAYH" fm get "$YAY_REPO/$f" lang)"
  out="$("$YAYH" brief check R-2 2>&1)" || true
  assert_contains "$out" "error: '## Xong khi' has 0 checks"
  assert_contains "$out" "error: '## Người dùng thấy gì' is empty"
}

test_plan_check_wants_a_verify_check_per_done_when() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  local id id2 b p out
  id="$("$YAYH" roadmap add "Gift wrap" sprint=later size=M)"; id2="$("$YAYH" roadmap add "Gift box" sprint=later size=S)"
  b="$YAY_REPO/$("$YAYH" brief new "$id")"; _bfill "$b"; "$YAYH" fm set "$b" item "$id"
  p="$YAY_REPO/$("$YAYH" artifact new plan "Gift wrap" from="$id" roadmap="$id")"
  awk '/^## Verify/ { print; print "- Manual: the option shows on both checkouts"; skip = 1; next } /^## / { skip = 0 } !skip { print }' "$p" > "$p.n" && mv "$p.n" "$p"
  out="$("$YAYH" plan check P-1 2>&1)" || true
  assert_contains "$out" "warn: the brief for $id has 3 Done when checks but Verify has 1"
  awk '/^## Verify/ { print; print "- Manual: ticking it adds the fee"; print "- Manual: the order email shows it"; next } { print }' "$p" > "$p.n" && mv "$p.n" "$p"
  assert_not_contains "$("$YAYH" plan check P-1 2>&1)" "Done when checks"
  # no brief, no warning
  "$YAYH" artifact new plan "Gift box" roadmap="$id2" >/dev/null
  assert_not_contains "$("$YAYH" plan check P-2 2>&1)" "Done when checks"
}
