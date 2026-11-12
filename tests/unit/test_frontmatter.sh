# front-matter get/set and ID allocation

_doc() {
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

test_fm_get_and_comments() {
  local f="$T_TMP/a.md"
  _doc "$f" <<'EOF'
---
id: B-7
status: open   # open | fixed
editions: [free, pro]
empty:
---
title: not front-matter
EOF
  assert_eq "B-7" "$("$YAYH" fm get "$f" id)"
  assert_eq "open" "$("$YAYH" fm get "$f" status)"
  assert_eq "[free, pro]" "$("$YAYH" fm get "$f" editions)"
  assert_eq "" "$("$YAYH" fm get "$f" empty)"
  assert_exit 3 "$YAYH" fm get "$f" title
}

test_fm_set_replace_append_create() {
  local f="$T_TMP/b.md"
  _doc "$f" <<'EOF'
---
id: P-1
status: draft
---
# Body
status: body text stays
EOF
  "$YAYH" fm set "$f" status ready
  "$YAYH" fm set "$f" pr 42
  assert_eq "ready" "$("$YAYH" fm get "$f" status)"
  assert_eq "42" "$("$YAYH" fm get "$f" pr)"
  assert_contains "$(cat "$f")" "status: body text stays"
  local g="$T_TMP/c.md"; printf '# no fm\n' > "$g"
  "$YAYH" fm set "$g" id BL-1
  assert_eq "BL-1" "$("$YAYH" fm get "$g" id)"
  assert_contains "$(cat "$g")" "# no fm"
}

test_fm_set_rejects_multiline() {
  local f="$T_TMP/d.md"; printf -- '---\nid: P-1\n---\n' > "$f"
  assert_fails "$YAYH" fm set "$f" title "$(printf 'a\nb')"
}

test_id_next_scans_docs_and_roadmap() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  assert_eq "B-1" "$("$YAYH" id next B)"
  _doc "$YAY_REPO/docs/bugs/2026-11-01-x.md" <<< $'---\nid: B-3\n---'
  _doc "$YAY_REPO/docs/bugs/2026-11-02-y.md" <<< $'---\nid: B-12\n---'
  _doc "$YAY_REPO/docs/plans/p.md" <<< $'---\nid: P-2\nfrom: B-40\n---'
  _doc "$YAY_REPO/docs/roadmap.md" <<< $'# Roadmap\n### R-9 Thing\n### R-10 Other'
  assert_eq "B-13" "$("$YAYH" id next B)"
  assert_eq "P-3" "$("$YAYH" id next P)"
  assert_eq "R-11" "$("$YAYH" id next R)"
  assert_eq "BS-1" "$("$YAYH" id next BS)"
  assert_fails "$YAYH" id next X
}

test_id_prefixes_do_not_collide() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  _doc "$YAY_REPO/docs/brainstorms/a.md" <<< $'---\nid: BS-5\n---'
  _doc "$YAY_REPO/docs/backlog/a.md" <<< $'---\nid: BL-8\n---'
  assert_eq "B-1" "$("$YAYH" id next B)"
}

test_id_find() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  _doc "$YAY_REPO/docs/bugs/x.md" <<< $'---\nid: B-1\n---'
  _doc "$YAY_REPO/docs/bugs/y.md" <<< $'---\nid: B-12\n---'
  assert_eq "$YAY_REPO/docs/bugs/x.md" "$("$YAYH" id find B-1)"
  assert_fails "$YAYH" id find B-99
}
