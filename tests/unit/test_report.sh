# reports: report new/check/render/list (.yay/reports/, never committed)

_rgood() { # report file: a passing idea report
  cat > "$1" <<'EOF'
---
kind: idea
title: Faster checkout for returning customers
author: test
date: 2026-11-23
---
# Faster checkout for returning customers

## In one line
Returning customers type their address every time. I'd like to save it. Can I spend 3 days on it next sprint?

## The problem
- 40% of orders come from returning customers
- Support got 12 complaints this month

## My idea
- Remember the last address and fill it in
- Customers can still change it

## What I need from you
A **yes or no** for next sprint. See the [support thread](https://example.com/t/1).

## For developers
- Uses `WC_Customer::get_shipping()` in includes/Checkout/Address.php, R-12.
```php
$x = 1 < 2;
```
EOF
}

test_new_writes_template_outside_git() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f; f="$("$YAYH" report new idea "Faster checkout for returning customers")"
  assert_contains "$f" ".yay/reports/"
  assert_contains "$f" "-faster-checkout-for-returning-customers.md"
  assert_eq "idea" "$("$YAYH" fm get "$YAY_REPO/$f" kind)"
  assert_eq "test" "$("$YAYH" fm get "$YAY_REPO/$f" author)"
  assert_fails grep -q '{{' "$YAY_REPO/$f"
  assert_eq "" "$(git -C "$YAY_REPO" status --porcelain)"
  assert_fails "$YAYH" report new memo "Something"
  assert_fails "$YAYH" report new idea "Faster checkout for returning customers"
  assert_contains "$("$YAYH" report list)" "$f"
}

test_check_fails_on_the_empty_template() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f out rc=0; f="$("$YAYH" report new done "Saved addresses")"
  out="$("$YAYH" report check "$f" 2>&1)" || rc=$?
  assert_eq 1 "$rc"
  assert_contains "$out" "error: template hint left"
  assert_contains "$out" "error: '## What's done' is empty"
  assert_contains "$out" "error: '## In one line' is empty"
}

test_check_passes_a_plain_report_and_allows_code_for_developers() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"; mkdir -p "$YAY_REPO/.yay/reports"
  local f="$YAY_REPO/.yay/reports/good.md"; _rgood "$f"
  assert_eq "" "$("$YAYH" report check good 2>&1)"
  assert_ok "$YAYH" report check "$f"
}

test_check_rejects_technical_and_decorated_text() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"; mkdir -p "$YAY_REPO/.yay/reports"
  local f="$YAY_REPO/.yay/reports/bad.md" out rc=0
  _rgood "$f"
  awk '/^## My idea$/ { print; print "- Changed includes/Repo/Address.php and `save_address`"; print "- getAddress() is cached \342\234\205"; print "<span style=\"color:red\">Done</span>"; print "| a | b |"; print "### More"; print "- The endpoint payload now waits for P-4"; next } { print }' "$f" > "$f.n" && mv "$f.n" "$f"
  out="$("$YAYH" report check bad 2>&1)" || rc=$?
  assert_eq 1 "$rc"
  assert_contains "$out" "error: code in '## My idea'"
  assert_contains "$out" "error: file or folder name"
  assert_contains "$out" "error: code name"
  assert_contains "$out" "error: HTML on line"
  assert_contains "$out" "error: table on line"
  assert_contains "$out" "error: sub-heading on line"
  assert_contains "$out" "error: emoji or symbols on line"
  assert_contains "$out" "warn: jargon on line"
  assert_contains "$out" "endpoint, payload"
  assert_contains "$out" "warn: an internal id"
}

test_check_limits_words_and_the_first_line() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"; mkdir -p "$YAY_REPO/.yay/reports"
  local f="$YAY_REPO/.yay/reports/long.md" out long i
  _rgood "$f"
  long=""; for i in $(seq 1 45); do long="$long word"; done
  awk -v l="$long." '/^Returning customers/ { print l; next } { print }' "$f" > "$f.n" && mv "$f.n" "$f"
  out="$("$YAYH" report check long 2>&1)" || true
  assert_contains "$out" "error: '## In one line' has 45 words"
  out="$("$YAYH" report check long --max-words=40 2>&1)" || true
  assert_contains "$out" "(limit 40, ## For developers not counted)"
  # a section after For developers, and one twice
  printf '\n## The problem\n- again\n' >> "$f"
  out="$("$YAYH" report check long 2>&1)" || true
  assert_contains "$out" "comes after ## For developers"
  assert_contains "$out" "appears twice"
}

test_render_writes_the_plain_page_and_text() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"; mkdir -p "$YAY_REPO/.yay/reports"
  local f="$YAY_REPO/.yay/reports/good.md" html out
  _rgood "$f"
  html="$("$YAYH" report render good)"
  assert_eq ".yay/reports/good.html" "$html"
  out="$(cat "$YAY_REPO/$html")"
  assert_contains "$out" "<title>Faster checkout for returning customers</title>"
  assert_contains "$out" '<div class="lead">'
  assert_contains "$out" "<h2>The problem</h2>"
  assert_contains "$out" "<li>40% of orders come from returning customers</li>"
  assert_contains "$out" "<strong>yes or no</strong>"
  assert_contains "$out" '<a href="https://example.com/t/1">support thread</a>'
  assert_contains "$out" "<summary>For developers</summary>"
  assert_contains "$out" "<code>WC_Customer::get_shipping()</code>"
  assert_contains "$out" '<pre><code>$x = 1 &lt; 2;'
  assert_contains "$out" "prefers-color-scheme: dark"
  assert_not_contains "$out" "{{"
  out="$("$YAYH" report render good --text)"
  assert_contains "$out" "Faster checkout for returning customers"
  assert_contains "$out" "test · 2026-11-23"
  assert_contains "$out" "- 40% of orders come from returning customers"
  assert_contains "$out" "A yes or no for next sprint. See the support thread (https://example.com/t/1)."
  assert_not_contains "$out" "## "
}

test_render_refuses_a_failing_report() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f; f="$("$YAYH" report new feature "Gift wrap option")"
  assert_fails "$YAYH" report render "$f"
  assert_no_file "$YAY_REPO/${f%.md}.html"
}
