# doctor: machine and repo readiness

test_doctor_reports_each_check_and_fails_only_on_fails() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  local out; out="$("$YAYH" doctor)"; assert_eq 0 $?
  assert_contains "$out" "ok	git	"
  assert_contains "$out" "ok	config	.yay/config.json is valid"
  assert_contains "$out" "warn	remote	no origin remote"
  # the seeded placeholder block isn't knowledge yet; a written one is
  assert_contains "$out" "warn	knowledge	no project knowledge yet"
  sed -i.bak 's/_Project knowledge has not been written yet.*/Checkout builder./' "$YAY_REPO/CLAUDE.md"
  assert_contains "$("$YAYH" doctor)" "ok	knowledge	project block present"
  # a broken config is a fail, and doctor exits 1
  printf '{ "schemaVersion": 1 }\n' > "$YAY_REPO/.yay/config.json"
  assert_exit 1 "$YAYH" doctor
  assert_contains "$("$YAYH" doctor || true)" "fail	config	"
}

test_doctor_node_version_and_unharnessed_repo() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  git -C "$YAY_REPO" commit -q --allow-empty -m init
  assert_contains "$("$YAYH" doctor)" "warn	harness	not set up in this repo"
  command -v node >/dev/null 2>&1 || { _pass; return; }
  printf '{ "name": "x", "engines": { "node": ">=999" } }\n' > "$YAY_REPO/package.json"
  assert_contains "$("$YAYH" doctor)" "warn	node	"
  assert_contains "$("$YAYH" doctor)" "the repo wants >=999"
}
