# shellcheck shell=bash
# yayh artifact archive: delete the finished artifacts a release has shipped and
# keep one row each in docs/archive.md, so their ids stay taken and their text is one
# `git show <commit>:<path>` away. See reference/artifacts.md (Archive).
#
# An artifact can go when:
#   - its status was already final in the release tag's tree, and still is (plan done
#     or dropped, brainstorm decided or dropped, bug fixed, wontfix or duplicate, a
#     settled backlog note, a roadmap item shipped or dropped, a dropped design);
#   - it has no uncommitted changes;
#   - nothing that stays links to it, and it links to nothing that stays (ids in
#     front-matter, or in a roadmap item's bullets). A ready design goes with the
#     plans that built it, never before one does.
# A past sprint left with no items goes too, and so does the release brief of a
# released version once none of its items remain.

YAY_ARCHIVE_FILE=docs/archive.md
YAY_ARCHIVE_HEAD='| ID | Title | Status | Archived | File | Commit |'

# _yay_archive_ids -> the artifact ids named in stdin, one per line. A prefix needs a
# non-word character before it, so BS-3 is never read as B-3.
_yay_archive_ids() {
  awk '{ s = $0
    while (match(s, /(BS|BL|UX|P|B|R)-[0-9]+/)) {
      pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
      if (pre !~ /[A-Za-z0-9_-]/) print substr(s, RSTART, RLENGTH)
      s = substr(s, RSTART + RLENGTH)
    } }'
}
_yay_archive_fm() { awk 'NR == 1 && $0 != "---" { exit } NR == 1 { next } $0 == "---" { exit } { print }' "$1"; }

# _yay_archive_status_in <text-file> -> the front-matter status.
_yay_archive_status_in() { _yay_archive_fm "$1" | sed -n 's/^status:[[:space:]]*//p' | sed -n 1p | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'; }

# _yay_archive_roadmap_at <tag> -> every roadmap file at that tag, concatenated.
_yay_archive_roadmap_at() {
  local p
  yay_git show "$1:docs/roadmap.md" 2>/dev/null || true; echo
  { yay_git ls-tree --name-only "$1" docs/roadmap/ 2>/dev/null || true; } | while IFS= read -r p; do
    case "$p" in *.md) yay_git show "$1:$p" 2>/dev/null || true; echo ;; esac
  done
}

# _yay_archive_items <roadmap text file> -> TSV: id status line refs(space-separated)
_yay_archive_items() {
  awk '
    function flush() { if (id != "") printf "%s\t%s\t%d\t%s\n", id, (st == "" ? "-" : st), line, refs; id = "" }
    /^```/ { fence = !fence; next }
    fence { next }
    /^### R-[0-9]+([[:space:]]|$)/ { flush(); id = $2; st = ""; refs = ""; line = NR; next }
    /^#/ { flush(); next }
    id != "" && /^- [a-z_]+:/ {
      if ($2 == "status:") { st = $0; sub(/^- status:[[:space:]]*/, "", st); sub(/[[:space:]]+$/, "", st) }
      s = $0
      while (match(s, /(BS|BL|UX|P|B|R)-[0-9]+/)) {
        pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
        r = substr(s, RSTART, RLENGTH); if (pre !~ /[A-Za-z0-9_-]/ && r != id) refs = refs " " r
        s = substr(s, RSTART + RLENGTH)
      }
    }
    END { flush() }' "$1"
}

_yay_archive_clean() { # <rel path>: tracked and unchanged since HEAD
  yay_git ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && yay_git diff --quiet HEAD -- "$1" 2>/dev/null
}

# _yay_archive_records <tag> -> TSV: id type now at-tag clean(1|0) path line refs
_yay_archive_records() {
  local tag="$1" root d type f rel id now at clean refs tmp doc atdoc
  root="$(yay_repo_root)"; tmp="$(mktemp)"
  for d in brainstorms plans bugs backlog designs; do
    case "$d" in brainstorms) type=brainstorm ;; plans) type=plan ;; bugs) type=bug ;; backlog) type=backlog ;; designs) type=design ;; esac
    for f in "$root/docs/$d"/*.md; do
      [ -f "$f" ] || continue
      rel="${f#"$root"/}"
      id="$(yay_fm_get "$f" id 2>/dev/null || true)"; [ -n "$id" ] || continue
      now="$(_yay_archive_status_in "$f")"
      if yay_git show "$tag:$rel" > "$tmp" 2>/dev/null; then at="$(_yay_archive_status_in "$tmp")"; else at=""; fi
      if _yay_archive_clean "$rel"; then clean=1; else clean=0; fi
      refs="$(_yay_archive_fm "$f" | { grep -v '^id:' || true; } | _yay_archive_ids | { grep -vx "$id" || true; } | tr '\n' ' ')"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t0\t%s\n' "$id" "$type" "${now:--}" "${at:--}" "$clean" "$rel" "$refs"
    done
  done
  if [ "$(yay_roadmap_layout)" != none ]; then
    doc="$(yay_roadmap_file)"; atdoc="$(mktemp)"
    _yay_archive_roadmap_at "$tag" > "$atdoc"
    _yay_archive_items "$atdoc" | cut -f1,2 > "$tmp"
    _yay_archive_items "$doc" | while IFS="$YAY_TAB" read -r id now line refs; do
      at="$(awk -F '\t' -v id="$id" '$1 == id { print $2; exit }' "$tmp")"
      rel="$(yay_roadmap_source)"
      if [ "$(yay_roadmap_layout)" = split ]; then
        rel="$(cd "$root" && grep -lE "^### $id([[:space:]]|\$)" docs/roadmap/*.md 2>/dev/null | sed -n 1p)" || true
      fi
      if _yay_archive_clean "$rel"; then clean=1; else clean=0; fi
      printf '%s\troadmap\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$now" "${at:--}" "$clean" "$rel" "$line" "$refs"
    done
    rm -f "$atdoc"
  fi
  rm -f "$tmp"
}

# _yay_archive_decide <records file> -> TSV: archive id type status path line | keep id reason
# Only artifacts that are finished now are listed.
_yay_archive_decide() {
  awk -F '\t' '
    function final(t, s) {
      if (t == "brainstorm") return s == "decided" || s == "dropped"
      if (t == "plan") return s == "done" || s == "dropped"
      if (t == "bug") return s == "fixed" || s == "wontfix" || s == "duplicate"
      if (t == "design") return s == "dropped" || s == "ready"
      if (t == "backlog") return s != "idea" && s != "open" && s != "-" && s != ""
      if (t == "roadmap") return s == "dropped" || s ~ /^shipped:/
      return 0
    }
    {
      n++; id[n] = $1; ty[$1] = $2; st[$1] = $3; path[$1] = $6; ln[$1] = $7; ex[$1] = 1
      nr = split($8, r, " "); for (i = 1; i <= nr; i++) if (r[i] != "") { ne++; ea[ne] = $1; eb[ne] = r[i] }
      if (!final($2, $3)) next
      fin[$1] = 1
      if ($4 != $3) why[$1] = ($4 == "-" ? "not in the release yet" : "was \"" $4 "\" in the release")
      else if ($5 != 1) why[$1] = "has uncommitted changes"
      else cand[$1] = 1
    }
    END {
      # A ready design goes only with a plan that built it.
      for (i = 1; i <= n; i++) { x = id[i]; if (!(x in cand) || ty[x] != "design" || st[x] != "ready") continue
        built = 0; for (e = 1; e <= ne; e++) if (eb[e] == x && ty[ea[e]] == "plan") built = 1
        if (!built) { delete cand[x]; why[x] = "no plan has built it yet" } }
      do {
        changed = 0
        for (e = 1; e <= ne; e++) {
          a = ea[e]; b = eb[e]; if (!(a in ex) || !(b in ex)) continue
          if ((a in cand) && !(b in cand)) { delete cand[a]; why[a] = "linked to " b ", which stays"; changed = 1 }
          if ((b in cand) && !(a in cand)) { delete cand[b]; why[b] = "linked to " a ", which stays"; changed = 1 }
        }
      } while (changed)
      for (i = 1; i <= n; i++) { x = id[i]
        if (x in cand) printf "archive\t%s\t%s\t%s\t%s\t%s\n", x, ty[x], st[x], path[x], ln[x]
        else if (x in fin) printf "keep\t%s\t%s\n", x, why[x] }
    }' "$1"
}

_yay_archive_row() { # <id> <title> <status> <path> <commit>
  printf '| %s | %s | %s | %s | %s | %s |\n' "$1" "$(printf '%s' "$2" | tr '|' '/')" "$3" "$(yay_today)" "$4" "$5"
}

# yay_artifact_archive [--release=<tag>] [--yes] -> without --yes, what would go
# (archive / keep lines); with --yes, deletes it and appends rows to docs/archive.md.
yay_artifact_archive() {
  local tag="" yes=0 a root rec dec ver
  for a in "$@"; do
    case "$a" in --release=*) tag="${a#--release=}" ;; --yes) yes=1 ;; *) yay_die "usage: yayh artifact archive [--release=<tag>] [--yes]" ;; esac
  done
  root="$(yay_repo_root)"
  [ -n "$tag" ] || tag="$(yay_last_tag)"
  [ -n "$tag" ] || yay_die "no release tag yet: archive only removes work a tagged release has shipped (--release=<tag> to pick one)"
  yay_git rev-parse -q --verify "refs/tags/$tag" >/dev/null || yay_git rev-parse -q --verify "$tag^{commit}" >/dev/null || yay_die "no tag or ref '$tag'"
  rec="$(mktemp)"; dec="$(mktemp)"
  _yay_archive_records "$tag" > "$rec"
  _yay_archive_decide "$rec" > "$dec"
  ver="$(yay_version_of_tag "$tag")"

  # Release briefs of released versions whose items are all gone after this run.
  local b v left
  for b in "$root"/docs/roadmap/release-*.md; do
    [ -f "$b" ] || continue
    v="${b##*/release-}"; v="${v%.md}"
    _yay_semver_gt "$v" "$ver" && continue
    left="$(yay_roadmap_list --target="$v" 2>/dev/null | cut -f1 | while IFS= read -r a; do
      grep -q "^archive	$a	" "$dec" || echo "$a"; done)"
    if [ -n "$left" ]; then printf 'keep\trelease-%s\tits items stay: %s\n' "$v" "$(printf '%s' "$left" | tr '\n' ' ' | sed 's/ $//')" >> "$dec"
    elif _yay_archive_clean "${b#"$root"/}"; then printf 'archive\trelease-%s\tbrief\treleased\t%s\t0\n' "$v" "${b#"$root"/}" >> "$dec"
    else printf 'keep\trelease-%s\thas uncommitted changes\n' "$v" >> "$dec"; fi
  done

  if [ "$yes" = 0 ]; then
    awk -F '\t' '$1 == "archive" { printf "archive\t%s\t%s\t%s\n", $2, $4, $5; next } { print }' "$dec"
    rm -f "$rec" "$dec"; return 0
  fi

  local rows kind id type st path line sha title doc ranges
  rows="$(mktemp)"; ranges="$(mktemp)"
  while IFS="$YAY_TAB" read -r kind id type st path line; do
    [ "$kind" = archive ] || continue
    sha="$(yay_git log -1 --format=%h --abbrev=12 -- "$path")"
    case "$type" in
      roadmap) doc="$(yay_roadmap_file)"
               title="$(awk -v n="$line" 'NR == n { sub(/^### R-[0-9]+[[:space:]]*/, ""); print; exit }' "$doc")"
               _yay_item_range "$doc" "$id" >> "$ranges" ;;
      brief) title="Release brief ${id#release-}"; rm -f "$root/$path" ;;
      *) title="$(yay_fm_get "$root/$path" title 2>/dev/null || true)"; rm -f "$root/$path" ;;
    esac
    _yay_archive_row "$id" "$title" "$st" "$path" "$sha" >> "$rows"
    printf 'archived\t%s\t%s\n' "$id" "$path"
  done < "$dec"

  if [ -s "$ranges" ]; then
    doc="$(yay_roadmap_file)"
    _yay_archive_cut "$doc" "$ranges"
    if [ "$(yay_roadmap_layout)" = split ]; then _yay_roadmap_save "$doc" >/dev/null; fi
  fi

  if [ -s "$rows" ]; then
    if [ ! -f "$root/$YAY_ARCHIVE_FILE" ]; then
      printf '# Archive\n\nFinished work that `yayh artifact archive` removed from `docs/` after a release shipped it. These ids stay taken. Read a file with `git show <commit>:<file>`.\n\n%s\n|---|---|---|---|---|---|\n' "$YAY_ARCHIVE_HEAD" > "$root/$YAY_ARCHIVE_FILE"
    fi
    cat "$rows" >> "$root/$YAY_ARCHIVE_FILE"
  fi
  rm -f "$rec" "$dec" "$rows" "$ranges"
}

# _yay_archive_cut <doc> <ranges file>: delete those item line ranges, then every past
# sprint section left with no items.
_yay_archive_cut() {
  local doc="$1" tmp; tmp="$(mktemp)"
  awk -v today="$(yay_today)" '
    FNR == NR { for (i = $1; i <= $2; i++) cut[i] = 1; next }
    !(FNR in cut) { l[++n] = $0 }
    END {
      # sections: a "## Sprint" heading through the line before the next "## "
      i = 1
      while (i <= n) {
        if (l[i] ~ /^## Sprint [0-9]+/) {
          j = i + 1; items = 0; fence = 0
          while (j <= n && !(l[j] ~ /^## / && !fence)) { if (l[j] ~ /^```/) fence = !fence; if (!fence && l[j] ~ /^### R-[0-9]+/) items = 1; j++ }
          e = ""; h = l[i]
          if (match(h, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { h = substr(h, RSTART + 10); if (match(h, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) e = substr(h, RSTART, 10) }
          if (!items && e != "" && e < today) { i = j; continue }
          for (k = i; k < j; k++) out[++m] = l[k]; i = j; continue
        }
        out[++m] = l[i]; i++
      }
      blank = 0
      for (k = 1; k <= m; k++) { if (out[k] ~ /^[[:space:]]*$/) { if (blank++) continue } else blank = 0; print out[k] }
    }' "$2" "$doc" > "$tmp"
  cat "$tmp" > "$doc"; rm -f "$tmp"
}

# yay_archive_find <ID> -> its docs/archive.md row as TSV: id title status archived file commit
yay_archive_find() {
  local f; f="$(yay_repo_root)/$YAY_ARCHIVE_FILE"
  [ -f "$f" ] || return 3
  awk -F '|' -v id="$1" '{ x = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", x) } x == id {
      for (i = 2; i <= 7; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); printf "%s%s", $i, (i < 7 ? "\t" : "\n") } found = 1; exit }
    END { exit !found }' "$f"
}
