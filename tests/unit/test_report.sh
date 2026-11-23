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

test_vietnamese_report_uses_its_headings_limits_and_slug() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f out html
  f="$("$YAYH" report new done "Lưu địa chỉ cho khách quay lại" --lang=vi)"
  assert_contains "$f" "-luu-dia-chi-cho-khach-quay-lai.md"
  assert_eq "vi" "$("$YAYH" fm get "$YAY_REPO/$f" lang)"
  out="$("$YAYH" report check "$f" 2>&1)" || true
  assert_contains "$out" "error: '## Đã xong' is empty"
  cat > "$YAY_REPO/$f" <<'MD'
---
kind: done
lang: vi
title: Lưu địa chỉ cho khách quay lại
author: test
date: 2026-11-23
---
# Lưu địa chỉ cho khách quay lại

## Tóm tắt
Khách quay lại không cần nhập lại địa chỉ nữa. Anh chị không cần làm gì.

## Đã xong
- Địa chỉ lần trước được điền sẵn khi thanh toán
- Khách vẫn sửa được trước khi trả tiền

## Người dùng được gì
Thanh toán nhanh hơn cho khách cũ.

## Tiếp theo
- Đang chờ designer gửi câu báo lỗi

## Dành cho lập trình viên
- Sửa trong `GiftMessage::clean()`.
MD
  assert_eq "" "$("$YAYH" report check "$f" 2>&1)"
  html="$("$YAYH" report render "$f")"
  out="$(cat "$YAY_REPO/$html")"
  assert_contains "$out" '<html lang="vi">'
  assert_contains "$out" '<div class="lead">'
  assert_contains "$out" "<summary>Dành cho lập trình viên</summary>"
  out="$("$YAYH" report render "$f" --text)"
  assert_not_contains "$out" "Tóm tắt"
  assert_contains "$out" "Dành cho lập trình viên"
  # the English headings are not Vietnamese sections; code moves to the developers section
  sed -i.bak 's/^## Tiếp theo$/## What'"'"'s next/; s/^- Khách vẫn sửa được trước khi trả tiền$/- Đã refactor endpoint, xem includes\/Address.php/' "$YAY_REPO/$f"; rm -f "$YAY_REPO/$f.bak"
  out="$("$YAYH" report check "$f" 2>&1)" || true
  assert_contains "$out" "error: no '## Tiếp theo' section"
  assert_contains "$out" "move it to ## Dành cho lập trình viên"
  assert_contains "$out" "jargon on line"
}

test_language_defaults_to_config_and_rejects_unknown() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  mkdir -p "$YAY_REPO/.yay"; printf '{"language":"vi"}\n' > "$YAY_REPO/.yay/local.json"
  local f; f="$("$YAYH" report new idea "Ý tưởng mới")"
  assert_eq "vi" "$("$YAYH" fm get "$YAY_REPO/$f" lang)"
  f="$("$YAYH" report new idea "Another idea" --lang=en)"
  assert_eq "en" "$("$YAYH" fm get "$YAY_REPO/$f" lang)"
  assert_fails "$YAYH" report new idea "Third idea" --lang=fr
}

test_english_limits_stay_at_300_words() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"; mkdir -p "$YAY_REPO/.yay/reports"
  local f="$YAY_REPO/.yay/reports/wordy.md" out
  _rgood "$f"
  awk '/^## My idea$/ { print; for (i = 0; i < 30; i++) print "- Customers can pay a little faster with one more saved step now"; next } { print }' "$f" > "$f.n" && mv "$f.n" "$f"
  out="$("$YAYH" report check wordy 2>&1)" || true
  assert_contains "$out" "(limit 300, ## For developers not counted)"
}

test_config_validate_checks_report_lang() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  python3 -I - "$YAY_REPO/.yay/config.json" vi <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["language"]=sys.argv[2]; json.dump(c,open(p,"w"))
PY
  assert_ok "$YAYH" config validate
  python3 -I - "$YAY_REPO/.yay/config.json" fr <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["language"]=sys.argv[2]; json.dump(c,open(p,"w"))
PY
  local out; out="$("$YAYH" config validate 2>&1 || true)"
  assert_contains "$out" "config: language must be en or vi (got 'fr')"
}

_rguide() { # report file, audience: a guide with a command under step 1
  cat > "$1" <<MD
---
kind: guide
lang: en
for: $2
title: Run the browser tests
author: test
date: 2026-11-23
---
# Run the browser tests

## In one line
Run the browser tests on your machine in about 10 minutes.

## Before you start
- Docker Desktop is running

## Steps
1. Start the test site:
   \`\`\`bash
   yayh e2e env start
   \`\`\`
   The site address is printed at the end.
2. Run the tests with \`yayh e2e run\`.

## Check it worked
The last line says all tests passed.

## If it goes wrong
- Docker does not answer: restart it and run step 1 again.
MD
}

test_guide_for_devs_allows_code_in_steps_only() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f out html
  f="$("$YAYH" report new guide "Run the browser tests" --for=devs)"
  assert_eq "devs" "$("$YAYH" fm get "$YAY_REPO/$f" for)"
  _rguide "$YAY_REPO/$f" devs
  assert_eq "" "$("$YAYH" report check "$f" 2>&1)"
  html="$(cat "$YAY_REPO/$("$YAYH" report render "$f")")"
  assert_contains "$html" "<li>Start the test site:<pre><code>yayh e2e env start</code></pre>"
  assert_contains "$html" "<p>The site address is printed at the end.</p>"
  assert_contains "$html" "<li>Run the tests with <code>yayh e2e run</code>.</li>"
  assert_contains "$("$YAYH" report render "$f" --text)" "   yayh e2e env start"
  # prose paths still need backticks, and the summary stays code-free
  sed -i.bak 's/^- Docker Desktop is running$/- Edit includes\/Setup.php first/; s/^Run the browser tests on your machine in about 10 minutes.$/Run `yayh e2e run` in about 10 minutes./' "$YAY_REPO/$f"; rm -f "$YAY_REPO/$f.bak"
  out="$("$YAYH" report check "$f" 2>&1)" || true
  assert_contains "$out" "put it in backticks so it reads as code"
  assert_contains "$out" "error: code in '## In one line'"
}

test_guide_for_team_keeps_the_plain_rules_and_allows_12_steps() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  local f out
  f="$("$YAYH" report new guide "Run the browser tests")"
  assert_eq "team" "$("$YAYH" fm get "$YAY_REPO/$f" for)"
  _rguide "$YAY_REPO/$f" team
  out="$("$YAYH" report check "$f" 2>&1)" || true
  assert_contains "$out" "error: code block in '## Steps'"
  assert_contains "$out" "error: code in '## Steps'"
  awk '/^## Steps$/ { print; for (i = 1; i <= 12; i++) print i ". Click the next button on the page"; skip = 1; next } /^## / { skip = 0 } !skip { print }' "$YAY_REPO/$f" > "$YAY_REPO/$f.n" && mv "$YAY_REPO/$f.n" "$YAY_REPO/$f"
  assert_eq "" "$("$YAYH" report check "$f" 2>&1)"
  printf '13. One more\n' > /dev/null
  awk '/^12\. / { print; print "13. Click one more button"; next } { print }' "$YAY_REPO/$f" > "$YAY_REPO/$f.n" && mv "$YAY_REPO/$f.n" "$YAY_REPO/$f"
  assert_contains "$("$YAYH" report check "$f" 2>&1)" "'## Steps' has 13 items (limit 12)"
  assert_fails "$YAYH" report new guide "Other guide" --for=boss
  assert_fails "$YAYH" report new idea "An idea" --for=devs
}
