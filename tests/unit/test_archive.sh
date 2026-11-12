# engine-independent
# artifact archive: finished work a release shipped leaves docs/, one row each in docs/archive.md

_fm() { # <path> <id> <status> [extra front-matter lines...]
  local p="$1" id="$2" st="$3"; shift 3
  mkdir -p "$(dirname "$p")"
  { printf -- '---\nid: %s\ntitle: %s title\nstatus: %s\n' "$id" "$id" "$st"; printf '%s\n' "$@"; printf -- '---\n# %s\n' "$id"; } > "$p"
}

_xrepo() { # tagged v1.0.0 with shipped work; one bug fixed after the tag
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay"
  printf '{"git":{"baseBranch":"main"}}\n' > "$r/.yay/config.json"
  cat > "$r/docs-roadmap.tmp" <<'MD'
---
sprint_length: 2w
---
# Roadmap: Fixture

## Sprint 1 (2020-01-01 → 2020-01-14)

Goal: ship the first thing.

### R-1 First thing
- status: shipped:1.0.0
- size: S
- from: BS-1

## Sprint 2 (2020-01-15 → 2020-01-28)

### R-2 Second thing
- status: in-progress
- size: M

## Later

### R-3 Someday
- status: planned
- size: L
MD
  mkdir -p "$r/docs"; mv "$r/docs-roadmap.tmp" "$r/docs/roadmap.md"
  _fm "$r/docs/brainstorms/2020-01-01-first.md" BS-1 decided "from: R-1"
  _fm "$r/docs/plans/first.md" P-3 done "from: BS-1" "roadmap: R-1"
  _fm "$r/docs/plans/second.md" P-2 done "roadmap: R-2"
  _fm "$r/docs/backlog/first-note.md" BL-1 decided "from: P-3"
  _fm "$r/docs/backlog/open-note.md" BL-2 open "from: P-3"
  commit_all "$r" "chore: init"
  git -C "$r" tag -a v1.0.0 -m "v1.0.0"
  _fm "$r/docs/bugs/2020-02-01-late.md" B-1 fixed
  commit_all "$r" "fix: late"
  printf '%s\n' "$r"
}

test_archive_dry_run_lists_shipped_work_and_why_the_rest_stays() {
  export YAY_REPO; YAY_REPO="$(_xrepo)"
  local out; out="$("$YAYH" artifact archive)"
  assert_contains "$out" "keep	P-3	linked to BL-2, which stays"
  assert_contains "$out" "keep	P-2	linked to R-2, which stays"
  assert_contains "$out" "keep	B-1	not in the release yet"
  case "$out" in *"BL-2"*"open"*|*"keep	R-2"*|*"keep	R-3"*) _fail "unfinished work listed: $out" ;; *) _pass ;; esac
  assert_eq "" "$(git -C "$YAY_REPO" status --porcelain)"
}

test_archive_yes_removes_files_items_and_empty_past_sprints() {
  export YAY_REPO; YAY_REPO="$(_xrepo)"
  # settle the open note, as a later branch would; the cluster can then go
  python3 -I - "$YAY_REPO/docs/backlog/open-note.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read().replace("status: open","status: dropped"); open(p,"w").write(s)
PY
  git -C "$YAY_REPO" tag -d v1.0.0 >/dev/null
  commit_all "$YAY_REPO" "docs: drop note"
  git -C "$YAY_REPO" tag -a v1.0.0 -m "v1.0.0"
  local dry; dry="$("$YAYH" artifact archive)"
  assert_contains "$dry" "archive	P-3	done	docs/plans/first.md"
  assert_contains "$dry" "archive	R-1	shipped:1.0.0	docs/roadmap.md"
  local out; out="$("$YAYH" artifact archive --yes)"
  assert_contains "$out" "archived	BS-1	docs/brainstorms/2020-01-01-first.md"
  for f in docs/plans/first.md docs/brainstorms/2020-01-01-first.md docs/backlog/first-note.md docs/backlog/open-note.md; do
    [ ! -e "$YAY_REPO/$f" ] && _pass || _fail "$f still there"
  done
  [ -e "$YAY_REPO/docs/plans/second.md" ] && _pass || _fail "linked plan removed"
  local rm; rm="$(cat "$YAY_REPO/docs/roadmap.md")"
  case "$rm" in *"R-1 First"*|*"Sprint 1 ("*) _fail "R-1 or its empty past sprint left: $rm" ;; *) _pass ;; esac
  assert_contains "$rm" "### R-2 Second thing"
  assert_contains "$rm" "### R-3 Someday"
  local sha; sha="$(git -C "$YAY_REPO" log -1 --format=%h --abbrev=12 -- docs/plans/first.md)"
  assert_contains "$(cat "$YAY_REPO/docs/archive.md")" "| P-3 | P-3 title | done | $(date +%Y-%m-%d) | docs/plans/first.md | $sha |"
  assert_eq "P-4" "$("$YAYH" id next P)"
  assert_eq "BL-3" "$("$YAYH" id next BL)"
  local err; err="$("$YAYH" artifact resolve P-3 2>&1 || true)"
  assert_contains "$err" "P-3 is archived (done): git show $sha:docs/plans/first.md"
  "$YAYH" roadmap check >/dev/null && _pass || _fail "roadmap check fails after archive: $("$YAYH" roadmap check 2>&1)"
}

test_archive_needs_a_release_tag() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  mkdir -p "$YAY_REPO/.yay"; printf '{"git":{"baseBranch":"main"}}\n' > "$YAY_REPO/.yay/config.json"
  commit_all "$YAY_REPO"
  assert_exit 1 "$YAYH" artifact archive
}

test_archive_split_roadmap_drops_sprint_file_and_released_brief() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  mkdir -p "$YAY_REPO/.yay" "$YAY_REPO/docs"
  printf '{"git":{"baseBranch":"main"}}\n' > "$YAY_REPO/.yay/config.json"
  cat > "$YAY_REPO/docs/roadmap.md" <<'MD'
---
sprint_length: 2w
---
# Roadmap: Fixture

## Sprint 1 (2020-01-01 → 2020-01-14)

### R-1 First thing
- status: shipped:1.0.0
- size: S
- target: 1.0.0

## Sprint 2 (2099-01-01 → 2099-01-14)

### R-2 Future thing
- status: planned
- size: M
- target: 2.0.0
MD
  "$YAYH" roadmap split >/dev/null
  "$YAYH" roadmap brief 1.0.0 >/dev/null
  "$YAYH" roadmap brief 2.0.0 >/dev/null
  commit_all "$YAY_REPO"
  git -C "$YAY_REPO" tag -a v1.0.0 -m v1.0.0
  local dry; dry="$("$YAYH" artifact archive)"
  assert_contains "$dry" "archive	R-1	shipped:1.0.0	docs/roadmap/sprint-1.md"
  assert_contains "$dry" "archive	release-1.0.0	released	docs/roadmap/release-1.0.0.md"
  case "$dry" in *release-2.0.0*) _fail "unreleased brief listed: $dry" ;; *) _pass ;; esac
  "$YAYH" artifact archive --yes >/dev/null
  for f in sprint-1.md release-1.0.0.md v1.0.0.md; do [ ! -e "$YAY_REPO/docs/roadmap/$f" ] && _pass || _fail "docs/roadmap/$f still there"; done
  for f in sprint-2.md release-2.0.0.md v2.0.0.md; do [ -e "$YAY_REPO/docs/roadmap/$f" ] && _pass || _fail "docs/roadmap/$f removed"; done
  assert_contains "$(cat "$YAY_REPO/docs/archive.md")" "| release-1.0.0 | Release brief 1.0.0 | released |"
  "$YAYH" roadmap check >/dev/null && _pass || _fail "roadmap check: $("$YAYH" roadmap check 2>&1)"
  assert_eq "R-3" "$("$YAYH" id next R)"
}
