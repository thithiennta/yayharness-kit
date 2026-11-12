# shellcheck shell=bash
# `yayh status` and `yayh next`: every piece of work in flight (roadmap items,
# plans, brainstorms, bugs, across all worktrees) with the one command that moves
# it forward. Skills end their report with `yayh next <id>`, and the SessionStart
# hook shows the checkout's own work from here.

# _yay_st_arts -> TSV per artifact, deduped by id (most advanced copy wins, this
# checkout first): kind id status roadmap from branch pr severity done total title path
# kind: plan | bs | bug. Empty fields print as "-".
_yay_st_arts() {
  local wt files="" f
  while IFS= read -r wt; do
    for f in "$wt"/docs/plans/*.md "$wt"/docs/brainstorms/*.md "$wt"/docs/bugs/*.md; do
      [ -f "$f" ] || continue
      files="$files$f
"
    done
  done <<EOT
$(yay_worktree_roots)
EOT
  [ -n "$files" ] || return 0
  printf '%s' "$files" | tr '\n' '\0' | xargs -0 awk '
    function nz(v) { return v == "" ? "-" : v }
    function emit() {
      if (id == "") return
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\n", kind, id, nz(st), nz(rm), nz(fr), nz(br), nz(pr), nz(sev), td, tt, nz(ti), path
    }
    FNR == 1 {
      emit(); path = FILENAME; infm = 0; intasks = 0; td = 0; tt = 0
      id = st = rm = fr = br = pr = sev = ti = ""
      kind = (path ~ /\/plans\//) ? "plan" : (path ~ /\/brainstorms\//) ? "bs" : "bug"
      if ($0 == "---") { infm = 1; next }
    }
    infm && $0 == "---" { infm = 0; next }
    infm {
      i = index($0, ":"); if (i == 0) next
      k = substr($0, 1, i - 1); v = substr($0, i + 1)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v); gsub(/\t/, " ", v)
      if (k == "id") id = v; else if (k == "status") st = v; else if (k == "roadmap") rm = v
      else if (k == "from") fr = v; else if (k == "branch") br = v; else if (k == "pr") pr = v
      else if (k == "severity") sev = v; else if (k == "title") ti = v
      next
    }
    /^## / { intasks = ($0 ~ /^## Tasks/) }
    intasks && /^- \[[ xX]\] T[0-9]+/ { tt++; if (substr($0, 4, 1) != " ") td++ }
    END { emit() }
  ' | awk -F '\t' '
    function rank(k, s) {
      if (s == "dropped") return 0
      if (k == "plan") return s == "done" ? 5 : s == "in-progress" ? 4 : s == "ready" ? 3 : 2
      if (k == "bs") return s == "decided" ? 3 : 2
      return (s == "fixed" || s == "wontfix" || s == "duplicate") ? 4 : s == "root-caused" ? 3 : 2
    }
    !($2 in best) { order[++n] = $2; best[$2] = rank($1, $3); row[$2] = $0; next }
    rank($1, $3) > best[$2] { best[$2] = rank($1, $3); row[$2] = $0 }
    END { for (i = 1; i <= n; i++) print row[order[i]] }'
}

# _yay_st_plan_next <id> <status> -> the command for a plan, or nothing when it's finished.
_yay_st_plan_next() {
  case "$2" in
    draft|ready|-) printf '/yay:implement %s\n' "$1" ;;
    in-progress) printf '/yay:implement %s --continue\n' "$1" ;;
  esac
}

# _yay_st_stage_next <stage> <artifact> <R-n> -> the command for a roadmap queue stage.
_yay_st_stage_next() {
  case "$1" in
    brainstorm) printf '/yay:brainstorm --from=%s\n' "$3" ;;
    decide|plan) printf '/yay:plan --from=%s\n' "$2" ;;
    implement) printf '/yay:implement %s\n' "$2" ;;
    continue) printf '/yay:implement %s --continue\n' "$2" ;;
    review) printf '/yay:autopilot %s\n' "$3" ;;
  esac
}

# yay_status [--today=YYYY-MM-DD] -> TSV, most urgent first: scope id stage next title
# scope: here (this checkout's branch) | active (in progress) | slipped | bug | sprint
#        (current sprint) | plan | brainstorm (not tied to a listed roadmap item)
yay_status() {
  local today a root arts branch base rows="" covered=" "
  today="$(yay_today)"
  for a in "$@"; do
    case "$a" in --today=*) today="${a#--today=}" ;; *) yay_die "usage: yayh status [--today=YYYY-MM-DD]" ;; esac
  done
  root="$(yay_repo_root)"
  arts="$(_yay_st_arts)"
  _row() { rows="$rows$1	$2	$3	$4	$5	$6
"; }
  _cover() { local x; for x in "$@"; do [ "$x" = - ] || [ -z "$x" ] || covered="$covered$x "; done; }
  _tasks() { printf '%s\n' "$arts" | awk -F '\t' -v i="$1" '$2 == i && $10 > 0 { printf " · %d/%d tasks", $9, $10; exit }'; }

  # 1. The work this checkout's branch belongs to.
  branch="$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  base="$( (yay_base_branch) 2>/dev/null || echo main)"
  if [ -n "$branch" ] && [ "$branch" != "$base" ]; then
    local hrow k id st pr ti nx
    hrow="$(printf '%s\n' "$arts" | awk -F '\t' -v b="$branch" '$6 == b && $1 == "plan" { print; exit }')"
    [ -n "$hrow" ] || hrow="$(printf '%s\n' "$arts" | awk -F '\t' -v b="$branch" '$6 == b && $1 == "bug" { print; exit }')"
    if [ -n "$hrow" ]; then
      k="$(printf '%s' "$hrow" | cut -f1)"; id="$(printf '%s' "$hrow" | cut -f2)"; st="$(printf '%s' "$hrow" | cut -f3)"
      pr="$(printf '%s' "$hrow" | cut -f7)"; ti="$(printf '%s' "$hrow" | cut -f11)"
      if [ "$k" = plan ]; then
        nx="$(_yay_st_plan_next "$id" "$st")"
        if [ -z "$nx" ]; then
          if [ "$pr" = - ]; then nx="git push -u origin $branch && gh pr create --head $branch --assignee @me"; st=finished
          else nx="gh pr view $pr"; st=in-review; fi
        fi
        ti="$ti$(_tasks "$id")"
      else
        case "$st" in
          fixed|wontfix|duplicate)
            if [ "$pr" = - ]; then nx="git push -u origin $branch && gh pr create --head $branch --assignee @me"; st=finished
            else nx="gh pr view $pr"; st=in-review; fi ;;
          *) nx="/yay:fix $id" ;;
        esac
      fi
      _row 1 here "$id" "$st" "$nx" "$ti"
      _cover "$id" "$(printf '%s' "$hrow" | cut -f4)"
    fi
  fi

  # 2. Roadmap items: in progress anywhere, slipped, and the current sprint.
  local f cur="" ids="" secs=""
  f="$( (yay_roadmap_file) 2>/dev/null || true)"
  if [ -f "$f" ]; then
    cur="$(yay_roadmap_current "$today" 2>/dev/null | cut -f1 || true)"
    # Between sprints, or before the first one: the next sprint counts as current.
    [ -n "$cur" ] || cur="$(yay_roadmap_parse "$f" | awk -F '\t' -v today="$today" '$1 == "S" && $3 != "-" && $3 > today { print $2; exit }')"
    secs="$(yay_roadmap_parse "$f" | awk -F '\t' -v cur="$cur" -v today="$today" '
      $1 == "S" { end[$2] = $4 }
      $1 == "I" {
        st = $3; sec = $5; done = (st ~ /^shipped/ || st == "dropped" || st == "done")
        if (done) next
        if (st == "in-progress") print $2 "\tactive"
        else if (sec ~ /^[0-9]+$/ && end[sec] != "-" && end[sec] < today) print $2 "\tslipped"
        else if (sec == cur && cur != "") print $2 "\tsprint"
      }')"
    ids="$(printf '%s\n' "$secs" | awk -F '\t' 'NF { print $1 }' | tr '\n' ' ')"
  fi
  if [ -n "${ids// /}" ]; then
    local qid stage art after waits qti scope pri extra
    while IFS="$YAY_TAB" read -r qid stage art after waits qti; do
      [ -n "$qid" ] || continue
      case "$stage" in done|dropped) continue ;; esac
      case " $covered " in *" $qid "*) continue ;; esac
      scope="$(printf '%s\n' "$secs" | awk -F '\t' -v i="${qid%%/*}" '$1 == i { print $2; exit }')"
      case "$stage" in continue|review) scope=active ;; esac
      case "$scope" in active) pri=2 ;; slipped) pri=3 ;; *) pri=5 ;; esac
      extra=""
      [ "$after" = - ] || extra="$extra (after $after)"
      [ "$waits" = - ] || extra="$extra (waits on $waits)"
      [ "$art" = - ] || case "$art" in P-*) extra="$(_tasks "$art")$extra" ;; esac
      _row "$pri" "$scope" "$qid" "$stage" "$(_yay_st_stage_next "$stage" "$art" "$qid")" "$qti$extra"
      _cover "$qid" "$art" "${qid%%/*}"
    done <<EOT
$( (yay_roadmap_queue $ids --today="$today") 2>/dev/null || true)
EOT
  fi

  # 3. Bugs, plans and brainstorms the rows above don't cover.
  local kind id st rm fr br pr sev td tt ti path
  while IFS="$YAY_TAB" read -r kind id st rm fr br pr sev td tt ti path; do
    [ -n "$kind" ] || continue
    case " $covered " in *" $id "*) continue ;; esac
    case "$kind" in
      bug)
        case "$st" in open|root-caused) ;; *) continue ;; esac
        # a live plan made from the bug carries it
        printf '%s\n' "$arts" | awk -F '\t' -v b="$id" '$1 == "plan" && $5 == b && $3 != "dropped" { f = 1 } END { exit !f }' && continue
        case "$sev" in critical|high) pri=4 ;; *) pri=6 ;; esac
        if [ "$st" = open ]; then nx="/yay:debug $id"; stage=debug; else nx="/yay:fix $id"; stage=fix; fi
        [ "$sev" = - ] || ti="$ti ($sev)"
        _row "$pri" bug "$id" "$stage" "$nx" "$ti" ;;
      plan)
        case " $covered " in *" $rm "*) continue ;; esac
        nx="$(_yay_st_plan_next "$id" "$st")"; [ -n "$nx" ] || continue
        if [ "$st" = in-progress ]; then pri=2; stage=continue; else pri=7; stage=implement; fi
        _row "$pri" plan "$id" "$stage" "$nx" "$ti$(_tasks "$id")" ;;
      bs)
        case "$st" in open|decided) ;; *) continue ;; esac
        case " $covered " in *" $fr "*) continue ;; esac
        printf '%s\n' "$arts" | awk -F '\t' -v b="$id" '$1 == "plan" && $5 == b && $3 != "dropped" { f = 1 } END { exit !f }' && continue
        _row 8 brainstorm "$id" "$([ "$st" = decided ] && echo plan || echo decide)" "/yay:plan --from=$id" "$ti" ;;
    esac
  done <<EOT
$arts
EOT
  [ -n "$rows" ] || return 0
  printf '%s' "$rows" | sort -t "$YAY_TAB" -k1,1n -s | cut -f2-
}

# yay_next [ID] [--today=] -> one command.
#   no ID: the next step for this checkout's branch, else the most urgent work in flight.
#   ID (R-n, P-n, BS-n, B-n, UX-n): the next step of that piece of work; when it's
#   finished, the most urgent other work. Exit 3 when nothing is left to do.
yay_next() {
  local id="" a today_arg="" all nx=""
  for a in "$@"; do
    case "$a" in --today=*) today_arg="$a" ;; -*) yay_die "usage: yayh next [ID] [--today=YYYY-MM-DD]" ;; *) id="$a" ;; esac
  done
  if [ -n "$id" ]; then nx="$(_yay_next_for "$id" $today_arg)"; fi
  if [ -z "$nx" ]; then
    all="$(yay_status $today_arg)"
    nx="$(printf '%s\n' "$all" | awk -F '\t' -v i="$id" 'NF && $2 != i { print $4; exit }')"
  fi
  [ -n "$nx" ] || return 3
  printf '%s\n' "$nx"
}

# _yay_next_for <ID> [--today=] -> the command for that piece of work, or nothing.
_yay_next_for() {
  local id="$1"; shift
  local arts row k st plan
  case "$id" in
    R-[0-9]*)
      row="$(yay_roadmap_queue "$id" "$@" 2>/dev/null | sed -n 1p)" || return 0
      [ -n "$row" ] || return 0
      _yay_st_stage_next "$(printf '%s' "$row" | cut -f2)" "$(printf '%s' "$row" | cut -f3)" "$id"
      return 0 ;;
    UX-[0-9]*)
      arts="$(_yay_st_arts)"
      plan="$(printf '%s\n' "$arts" | awk -F '\t' -v u="$id" '$1 == "plan" && $5 == u && $3 != "dropped" { print $2 "\t" $3; exit }')"
      if [ -n "$plan" ]; then _yay_st_plan_next "${plan%%	*}" "${plan#*	}"; else printf '/yay:plan --from=%s\n' "$id"; fi
      return 0 ;;
    P-[0-9]*|BS-[0-9]*|B-[0-9]*) ;;
    *) yay_die "next: expected R-<n>, P-<n>, BS-<n>, B-<n> or UX-<n>, got '$id'" ;;
  esac
  arts="$(_yay_st_arts)"
  row="$(printf '%s\n' "$arts" | awk -F '\t' -v i="$id" '$2 == i { print; exit }')"
  [ -n "$row" ] || yay_die "no $id in docs/ (any worktree)"
  k="$(printf '%s' "$row" | cut -f1)"; st="$(printf '%s' "$row" | cut -f3)"
  if [ "$k" = plan ]; then _yay_st_plan_next "$id" "$st"; return 0; fi
  # a brainstorm or bug: follow the newest live plan made from it
  plan="$(printf '%s\n' "$arts" | awk -F '\t' -v i="$id" '$1 == "plan" && $5 == i && $3 != "dropped" { out = $2 "\t" $3 } END { print out }')"
  if [ -n "$plan" ]; then _yay_st_plan_next "${plan%%	*}" "${plan#*	}"; return 0; fi
  case "$k:$st" in
    bs:open|bs:decided) printf '/yay:plan --from=%s\n' "$id" ;;
    bug:open) printf '/yay:debug %s\n' "$id" ;;
    bug:root-caused) printf '/yay:fix %s\n' "$id" ;;
  esac
}
