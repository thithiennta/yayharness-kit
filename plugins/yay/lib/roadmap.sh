# shellcheck shell=bash
# docs/roadmap.md: one `### R-<n> Title` item per entry with `- key: value`
# bullets, grouped under `## Sprint <n> (<start> → <end>)` and `## Later`.
# See reference/artifacts.md (Roadmap).

YAY_ROADMAP_STATUSES='planned brainstorming planned-in in-progress shipped dropped'
YAY_TAB="$(printf '\t')"

yay_roadmap_file() { printf '%s/docs/roadmap.md\n' "$(yay_repo_root)"; }

_yay_roadmap_need() {
  local f; f="$(yay_roadmap_file)"
  [ -f "$f" ] || yay_die "no docs/roadmap.md (run /yay:harness-sync or /yay:roadmap to create it)"
  printf '%s\n' "$f"
}

# yay_date_add <YYYY-MM-DD> <days> (days may be negative), BSD or GNU date.
yay_date_add() {
  local d="$1" n="$2"
  case "$n" in -*) ;; *) n="+$n" ;; esac
  if date -j -f %Y-%m-%d "$d" +%Y-%m-%d >/dev/null 2>&1; then
    date -j -v"${n}d" -f %Y-%m-%d "$d" +%Y-%m-%d
  else
    date -d "$d $n days" +%Y-%m-%d
  fi
}

_yay_is_date() { printf '%s' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; }

# _yay_length_days <2w|10d|14> -> days
_yay_length_days() {
  case "$1" in
    *w) printf '%d\n' $(( ${1%w} * 7 )) ;;
    *d) printf '%d\n' "${1%d}" ;;
    *[!0-9]*|'') yay_die "sprint length '$1' must look like 2w, 10d or 14" ;;
    *) printf '%d\n' "$1" ;;
  esac
}

# yay_roadmap_parse [file] -> records (TSV):
#   F key value                        front-matter
#   S n start end line                 sprint heading
#   I id status size section line title
# Empty fields print as "-" (read with IFS=tab merges empty fields).
# section is the sprint number, or the lowercased first word of another ## heading
# (later, shipped, dropped…), or "unscheduled" before any ## heading.
yay_roadmap_parse() {
  local f="${1:-}"; [ -n "$f" ] || f="$(_yay_roadmap_need)"
  awk '
    function nz(v) { return v == "" ? "-" : v }
    function flush() { if (id != "") printf "I\t%s\t%s\t%s\t%s\t%d\t%s\n", id, nz(st), nz(sz), sec, iline, nz(title); id="" }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    fm && /^---[[:space:]]*$/ { fm = 0; next }
    fm { k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); printf "F\t%s\t%s\n", k, v; next }
    /^```/ { fence = !fence; next }
    fence { next }
    /^## / {
      flush(); h = substr($0, 4)
      if (h ~ /^Sprint [0-9]+/) {
        n = h; sub(/^Sprint /, "", n); sub(/[^0-9].*/, "", n); sec = n
        s = ""; e = ""; rest = h
        if (match(rest, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { s = substr(rest, RSTART, 10); rest = substr(rest, RSTART + 10) }
        if (match(rest, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) { e = substr(rest, RSTART, 10) }
        printf "S\t%s\t%s\t%s\t%d\n", n, nz(s), nz(e), NR
      } else { sec = tolower(h); sub(/[^a-z0-9-].*/, "", sec) }
      next
    }
    /^### R-[0-9]+([[:space:]]|$)/ {
      flush(); id = $2; title = $0; sub(/^### R-[0-9]+[[:space:]]*/, "", title)
      st = ""; sz = ""; iline = NR; if (sec == "") sec = "unscheduled"; next
    }
    /^#/ { flush(); next }
    id != "" && /^- [a-z_]+:/ {
      k = $2; sub(/:$/, "", k); v = $0; sub(/^- [a-z_]+:[[:space:]]*/, "", v); sub(/[[:space:]]+$/, "", v)
      if (k == "status") st = v; else if (k == "size") sz = v
    }
    END { flush() }
  ' "$f"
}

_yay_status_matches() { # <status> <wanted>
  [ -z "$2" ] || [ "$1" = "$2" ] || [ "${1%%:*}" = "$2" ]
}

# yay_roadmap_list [--status=s] [--sprint=n|later|...] -> TSV: id status size section title
yay_roadmap_list() {
  local want_st="" want_sec="" a rec id st sz sec ln ti
  for a in "$@"; do
    case "$a" in
      --status=*) want_st="${a#--status=}" ;; --sprint=*) want_sec="${a#--sprint=}" ;;
      *) yay_die "usage: yayh roadmap list [--status=s] [--sprint=n|later]" ;;
    esac
  done
  while IFS="$YAY_TAB" read -r rec id st sz sec ln ti; do
    [ "$rec" = I ] || continue
    _yay_status_matches "$st" "$want_st" || continue
    [ -z "$want_sec" ] || [ "$sec" = "$want_sec" ] || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$st" "$sz" "$sec" "$ti"
  done <<EOF
$(yay_roadmap_parse)
EOF
}

# _yay_item_range <file> <R-n> -> "<heading line> <last line of the item>"
# The item runs to the next heading outside a code fence.
_yay_item_range() {
  awk -v id="$2" '
    /^```/ { fence = !fence; next }
    fence { next }
    start && /^#/ { print start, NR - 1; found = 1; exit }
    $0 ~ ("^### " id "([[:space:]]|$)") { start = NR }
    END { if (start && !found) print start, NR }
  ' "$1"
}

# yay_roadmap_get <R-n> <key>
yay_roadmap_get() {
  local f r s e; f="$(_yay_roadmap_need)"
  r="$(_yay_item_range "$f" "$1")"; [ -n "$r" ] || yay_die "no roadmap item $1"
  s="${r% *}"; e="${r#* }"
  awk -v s="$s" -v e="$e" -v k="$2" '
    NR > s && /^```/ { exit }
    NR > s && NR <= e && index($0, "- " k ":") == 1 { v = substr($0, length(k) + 4); sub(/^[[:space:]]+/, "", v); print v; f = 1; exit }
    END { exit !f }' "$f" || return 3
}

_yay_roadmap_touch() { yay_fm_set "$1" updated "$(yay_today)" >/dev/null 2>&1 || true; }

# yay_roadmap_set <R-n> <key> <value>: replace or add the item's `- key:` bullet.
yay_roadmap_set() {
  local id="$1" key="$2" val="$3" f r s e tmp
  printf '%s' "$key" | grep -Eq '^[a-z_]+$' || yay_die "key must be lowercase letters"
  f="$(_yay_roadmap_need)"
  r="$(_yay_item_range "$f" "$id")"; [ -n "$r" ] || yay_die "no roadmap item $id"
  s="${r% *}"; e="${r#* }"
  if [ "$key" = status ]; then _yay_roadmap_status_ok "$val" || yay_die "status '$val' is not one of: planned, brainstorming[:BS-n], planned-in:P-n, in-progress, shipped:x.y.z, dropped"; fi
  tmp="$(mktemp)"
  awk -v s="$s" -v e="$e" -v k="$key" -v v="$val" '
    { line[NR] = $0 }
    END {
      last = s
      for (i = s + 1; i <= e; i++) {
        if (line[i] ~ /^```/) break
        if (!hit && index(line[i], "- " k ":") == 1) hit = i
        if (line[i] ~ /^- [a-z_]+:/) last = i
      }
      for (i = 1; i <= NR; i++) {
        if (i == hit) { print "- " k ": " v; continue }
        print line[i]
        if (!hit && i == last) print "- " k ": " v
      }
    }' "$f" > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
  _yay_roadmap_touch "$f"
  printf '%s\t%s\t%s\n' "$id" "$key" "$val"
}

_yay_roadmap_status_ok() {
  case "$1" in
    planned|brainstorming|in-progress|dropped) return 0 ;;
    brainstorming:BS-[0-9]*) printf '%s' "$1" | grep -Eq '^brainstorming:BS-[0-9]+$' ;;
    planned-in:P-[0-9]*) printf '%s' "$1" | grep -Eq '^planned-in:P-[0-9]+$' ;;
    shipped:*) printf '%s' "$1" | grep -Eq '^shipped:[0-9]+\.[0-9]+(\.[0-9]+)?([-+.][0-9A-Za-z.-]+)?$' ;;
    *) return 1 ;;
  esac
}

# _yay_section_end <file> <section> -> line after which to append to that section
# (empty if the section doesn't exist). section: sprint number or heading word.
_yay_section_end() {
  awk -v want="$2" '
    function key(h,   n) { if (h ~ /^Sprint [0-9]+/) { n = h; sub(/^Sprint /, "", n); sub(/[^0-9].*/, "", n); return n }
                         h = tolower(h); sub(/[^a-z0-9-].*/, "", h); return h }
    /^```/ { fence = !fence }
    !fence && /^## / { if (in_sec) { print last; done = 1; exit } if (key(substr($0, 4)) == want) in_sec = 1 }
    in_sec && /[^[:space:]]/ { last = NR }
    END { if (in_sec && !done) print last }' "$1"
}

# yay_roadmap_move <R-n> <sprint-n|later|...>: move the item block to the end of that section.
# `later` is created at the end of the file if missing.
yay_roadmap_move() {
  local id="$1" to="$2" f r s e tmp blk at
  f="$(_yay_roadmap_need)"
  r="$(_yay_item_range "$f" "$id")"; [ -n "$r" ] || yay_die "no roadmap item $id"
  s="${r% *}"; e="${r#* }"
  tmp="$(mktemp)"; blk="$(mktemp)"
  # trim trailing blank lines from the block
  awk -v s="$s" -v e="$e" 'NR >= s && NR <= e' "$f" | awk '{ l[NR] = $0 } /[^[:space:]]/ { n = NR } END { for (i = 1; i <= n; i++) print l[i] }' > "$blk"
  awk -v s="$s" -v e="$e" 'NR < s || NR > e' "$f" > "$tmp"
  at="$(_yay_section_end "$tmp" "$to")"
  if [ -z "$at" ]; then
    case "$to" in
      [0-9]*) rm -f "$tmp" "$blk"; yay_die "no '## Sprint $to' section in docs/roadmap.md" ;;
    esac
    { cat "$tmp"; printf '\n## %s\n\n' "$(printf '%s' "$to" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')"; cat "$blk"; } > "$f"
  else
    awk -v at="$at" -v b="$blk" '{ print } NR == at { print ""; while ((getline l < b) > 0) print l }' "$tmp" > "$f"
  fi
  # collapse runs of blank lines
  awk 'NF { blank = 0; print; next } !blank++ { print }' "$f" > "$tmp"; cat "$tmp" > "$f"
  rm -f "$tmp" "$blk"
  _yay_roadmap_touch "$f"
  printf '%s\t%s\n' "$id" "$to"
}

# yay_roadmap_add "<title>" [sprint=n|later] [status=planned] [size=M] [why=…] [key=value…]
# -> prints the new R-n.
yay_roadmap_add() {
  local title="$1"; shift
  local f to="later" id kv k v bullets="" have_status=0
  f="$(_yay_roadmap_need)"
  [ -n "$title" ] || yay_die "title is empty"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    [ "$k" != "$kv" ] || yay_die "expected key=value, got '$kv'"
    case "$k" in
      sprint) to="$v"; continue ;;
      status) _yay_roadmap_status_ok "$v" || yay_die "bad status '$v'"; have_status=1 ;;
      size) case "$v" in S|M|L) ;; *) yay_die "size must be S, M or L" ;; esac ;;
    esac
    printf '%s' "$k" | grep -Eq '^[a-z_]+$' || yay_die "bad key '$k'"
    bullets="$bullets- $k: $v
"
  done
  [ "$have_status" = 1 ] || bullets="- status: planned
$bullets"
  id="$(yay_id_next R)"
  printf '\n### %s %s\n%s' "$id" "$title" "$bullets" >> "$f"
  yay_roadmap_move "$id" "$to" >/dev/null
  printf '%s\n' "$id"
}

# yay_roadmap_sprints start=YYYY-MM-DD length=2w (until=YYYY-MM-DD | count=N) [--md]
# -> TSV: n start end   (--md: `## Sprint n (start → end)` headings)
yay_roadmap_sprints() {
  local start="" len="" until="" count="" md=0 a days n s e
  for a in "$@"; do
    case "$a" in
      start=*) start="${a#start=}" ;; length=*) len="${a#length=}" ;;
      until=*) until="${a#until=}" ;; count=*) count="${a#count=}" ;;
      first=*) n="${a#first=}" ;; --md) md=1 ;;
      *) yay_die "usage: yayh roadmap sprints start=YYYY-MM-DD length=2w until=YYYY-MM-DD|count=N [first=1] [--md]" ;;
    esac
  done
  [ -n "$start" ] || start="$(yay_today)"
  [ -n "$len" ] || len="$(yay_fm_get "$(yay_roadmap_file)" sprint_length 2>/dev/null || echo 2w)"
  _yay_is_date "$start" || yay_die "start must be YYYY-MM-DD"
  [ -n "$until$count" ] || yay_die "give until=YYYY-MM-DD or count=N"
  [ -z "$until" ] || _yay_is_date "$until" || yay_die "until must be YYYY-MM-DD"
  days="$(_yay_length_days "$len")"; [ "$days" -gt 0 ] || yay_die "sprint length must be positive"
  n="${n:-1}"; s="$start"; local i=0
  while :; do
    if [ -n "$count" ]; then [ "$i" -lt "$count" ] || break; else [ ! "$s" \> "$until" ] || break; fi
    e="$(yay_date_add "$s" $((days - 1)))"
    if [ -n "$until" ] && [ "$e" \> "$until" ]; then e="$until"; fi
    if [ "$md" = 1 ]; then printf '## Sprint %d (%s → %s)\n' "$n" "$s" "$e"; else printf '%d\t%s\t%s\n' "$n" "$s" "$e"; fi
    s="$(yay_date_add "$e" 1)"; n=$((n + 1)); i=$((i + 1))
  done
}

# yay_roadmap_current [date] -> "n start end" of the sprint containing date (exit 3 if none)
yay_roadmap_current() {
  local d="${1:-$(yay_today)}" rec n s e _
  while IFS="$YAY_TAB" read -r rec n s e _; do
    [ "$rec" = S ] || continue
    if [ "$s" != - ] && [ "$e" != - ] && [ ! "$d" \< "$s" ] && [ ! "$d" \> "$e" ]; then printf '%s\t%s\t%s\n' "$n" "$s" "$e"; return 0; fi
  done <<EOF
$(yay_roadmap_parse)
EOF
  return 3
}

# yay_roadmap_check [--today=YYYY-MM-DD] -> error:/warn: lines; exit 1 on errors.
yay_roadmap_check() {
  local today f errs=0 a rec x1 x2 x3 x4 x5 x6 ids="" prev_n=0 prev_e="" ends="" plan
  today="$(yay_today)"
  for a in "$@"; do case "$a" in --today=*) today="${a#--today=}" ;; esac; done
  f="$(_yay_roadmap_need)"
  _re() { echo "error: $*"; errs=$((errs + 1)); }
  _rw() { echo "warn: $*"; }
  local horizon="" have_len=0
  while IFS="$YAY_TAB" read -r rec x1 x2 x3 x4 x5 x6; do
    case "$rec" in
      F)
        case "$x1" in
          horizon) horizon="$x2"; [ -z "$x2" ] || _yay_is_date "$x2" || _re "front-matter horizon '$x2' must be YYYY-MM-DD" ;;
          sprint_length) have_len=1; ( _yay_length_days "$x2" >/dev/null 2>&1 ) || _re "front-matter sprint_length '$x2' must look like 2w or 10d" ;;
        esac ;;
      S)
        [ "$x2" != - ] && [ "$x3" != - ] || { _re "line $x4: sprint heading must be '## Sprint $x1 (YYYY-MM-DD → YYYY-MM-DD)'"; continue; }
        [ "$x1" -gt "$prev_n" ] || _re "line $x4: Sprint $x1 is out of order"
        [ ! "$x2" \> "$x3" ] || _re "line $x4: Sprint $x1 ends before it starts"
        [ -z "$prev_e" ] || [ "$x2" \> "$prev_e" ] || _re "line $x4: Sprint $x1 overlaps the previous sprint"
        prev_n="$x1"; prev_e="$x3"
        ends="$ends$x1 $x3
" ;;
      I)
        [ "$x2" != - ] || x2=""; [ "$x3" != - ] || x3=""
        if yay_in_list "$x1" "$ids"; then _re "$x1 appears twice"; fi
        ids="$ids$x1
"
        if [ -z "$x2" ]; then _re "$x1 (line $x5) has no '- status:' bullet"
        elif ! _yay_roadmap_status_ok "$x2"; then _re "$x1 status '$x2' is not planned, brainstorming[:BS-n], planned-in:P-n, in-progress, shipped:x.y.z or dropped"; fi
        case "$x3" in S|M|L) ;; '') _rw "$x1 has no '- size:' (S, M or L)" ;; *) _re "$x1 size '$x3' must be S, M or L" ;; esac
        case "$x2" in
          planned-in:P-*|brainstorming:BS-*)
            plan="${x2#*:}"
            yay_id_find "$plan" >/dev/null 2>&1 || _rw "$x1 points at $plan, which no file in docs/ declares" ;;
        esac
        case "$x4" in
          [0-9]*)
            local end; end="$(printf '%s' "$ends" | awk -v n="$x4" '$1 == n { print $2 }')"
            case "$x2" in shipped*|dropped) ;; *)
              if [ -n "$end" ] && [ "$end" \< "$today" ]; then _rw "$x1 slipped: Sprint $x4 ended $end and it is still '${x2:-no status}'"; fi ;;
            esac ;;
        esac ;;
    esac
  done <<EOF
$(yay_roadmap_parse "$f")
EOF
  [ "$have_len" = 1 ] || _rw "front-matter has no sprint_length"
  if [ -n "$horizon" ] && [ "$horizon" \< "$today" ]; then _rw "horizon $horizon has passed: re-plan with /yay:roadmap"; fi
  [ "$errs" -eq 0 ]
}

# yay_roadmap_status [--today=…] -> human summary: sprints with counts, slipped items,
# open bugs by severity, plans in progress.
yay_roadmap_status() {
  local today f rec n s e ln cur="" a
  today="$(yay_today)"
  for a in "$@"; do case "$a" in --today=*) today="${a#--today=}" ;; esac; done
  f="$(yay_roadmap_file)"
  if [ -f "$f" ]; then
    printf 'roadmap\tdocs/roadmap.md\thorizon=%s\tupdated=%s\n' \
      "$(yay_fm_get "$f" horizon 2>/dev/null || true)" "$(yay_fm_get "$f" updated 2>/dev/null || true)"
    cur="$(yay_roadmap_current "$today" 2>/dev/null || true)"
    [ -z "$cur" ] || printf 'current\tSprint %s\t%s → %s\n' "$(printf '%s' "$cur" | cut -f1)" "$(printf '%s' "$cur" | cut -f2)" "$(printf '%s' "$cur" | cut -f3)"
    printf 'section\topen\tin-progress\tshipped\tdropped\n'
    yay_roadmap_parse "$f" | awk -F '\t' '
      $1 == "I" { sec = $5; if (!(sec in seen)) { seen[sec] = 1; order[++k] = sec }
        st = $3; sub(/:.*/, "", st)
        if (st == "in-progress") ip[sec]++; else if (st == "shipped") sh[sec]++; else if (st == "dropped") dr[sec]++; else op[sec]++ }
      END { for (i = 1; i <= k; i++) { s = order[i]; printf "%s\t%d\t%d\t%d\t%d\n", (s ~ /^[0-9]+$/ ? "Sprint " s : s), op[s], ip[s], sh[s], dr[s] } }'
    yay_roadmap_check --today="$today" 2>/dev/null | sed -n 's/^warn: \(R-[0-9]* slipped.*\)/slipped\t\1/p' || true
  else
    printf 'roadmap\tnone\n'
  fi
  local root b id st sev ti
  root="$(yay_repo_root)"
  for sev in critical high medium low; do
    for b in "$root"/docs/bugs/*.md; do
      [ -f "$b" ] || continue
      st="$(yay_fm_get "$b" status 2>/dev/null || true)"
      case "$st" in open|root-caused) ;; *) continue ;; esac
      [ "$(yay_fm_get "$b" severity 2>/dev/null || true)" = "$sev" ] || continue
      id="$(yay_fm_get "$b" id 2>/dev/null || true)"; ti="$(yay_fm_get "$b" title 2>/dev/null || true)"
      printf 'bug\t%s\t%s\t%s\t%s\n' "$id" "$sev" "$st" "$ti"
    done
  done
  yay_artifact_list plan --status=in-progress | awk -F '\t' '{ printf "plan\t%s\tin-progress\t%s\n", $1, $3 }'
  yay_artifact_list plan --status=ready | awk -F '\t' '{ printf "plan\t%s\tready\t%s\n", $1, $3 }'
}

# yay_roadmap_peers -> TSV: dir name slug harnessed(yes|no) path
# Sibling plugin folders of this repo (e.g. the other wp-content/plugins/ entries).
yay_roadmap_peers() {
  local root parent d name slug h main
  root="$(yay_repo_root)"; parent="$(dirname "$root")"
  for d in "$parent"/*/; do
    d="${d%/}"; [ -d "$d" ] || continue
    if [ -f "$d/.yay/config.json" ]; then
      h=yes
      name="$(YAY_REPO="$d" yay_config_get plugin.name 2>/dev/null || basename "$d")"
      slug="$(YAY_REPO="$d" yay_config_get plugin.slug 2>/dev/null || basename "$d")"
    else
      h=no
      main="$( { grep -l -E '^[[:space:]*#@]*Plugin Name:' "$d"/*.php 2>/dev/null || true; } | sed -n 1p)"
      [ -n "$main" ] || continue
      name="$(sed -n -E 's/^[[:space:]*#@]*Plugin Name:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' "$main" | sed -n 1p)"
      slug="$(basename "$d")"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$d")" "$name" "$slug" "$h" "$d"
  done
}

# yay_roadmap_links -> TSV: id current suggested via
# For each roadmap item that a brainstorm (from: R-n) or plan (roadmap: R-n or
# from: R-n) points at, the status the item should have. Shipped and dropped
# items keep theirs. Only the latest plan/brainstorm counts.
yay_roadmap_links() {
  local root rec id st _ f fid fst kind best via sug
  root="$(yay_repo_root)"
  while IFS="$YAY_TAB" read -r rec id st _; do
    [ "$rec" = I ] || continue
    [ "$st" != - ] || st=""
    best=""; via=""
    for f in "$root"/docs/plans/*.md "$root"/docs/brainstorms/*.md; do
      [ -f "$f" ] || continue
      case "$f" in */plans/*) kind=plan ;; *) kind=bs ;; esac
      if [ "$(yay_fm_get "$f" roadmap 2>/dev/null || true)" != "$id" ] && [ "$(yay_fm_get "$f" from 2>/dev/null || true)" != "$id" ]; then continue; fi
      fid="$(yay_fm_get "$f" id 2>/dev/null || true)"; fst="$(yay_fm_get "$f" status 2>/dev/null || true)"
      [ "$fst" != dropped ] || continue
      if [ "$kind" = plan ]; then
        case "$fst" in in-progress|done) sug=in-progress ;; *) sug="planned-in:$fid" ;; esac
        # a plan beats a brainstorm; an active plan beats a draft one
        if [ -z "$best" ] || [ "${via%%-*}" = BS ] || [ "$sug" = in-progress ]; then best="$sug"; via="$fid"; fi
      else
        [ "$fst" != dropped ] || continue
        if [ -z "$best" ]; then best="brainstorming:$fid"; via="$fid"; fi
      fi
    done
    [ -n "$best" ] || continue
    case "$st" in shipped*|dropped) best="$st" ;; esac
    printf '%s\t%s\t%s\t%s\n' "$id" "${st:--}" "$best" "$via"
  done <<EOT
$(yay_roadmap_parse)
EOT
}
