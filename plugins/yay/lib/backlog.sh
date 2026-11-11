# shellcheck shell=bash
# Backlog notes (BL-<n>, kind decision|deferred): what a plan or build couldn't
# settle at the time, so the next step that touches the same work picks it up.
# Ideas (kind idea, the default) keep their own flow through /yay:roadmap.
# See reference/artifacts.md (Backlog).

# _bl_list "[a, b]" -> one item per line, trimmed.
_bl_list() { printf '%s' "$1" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | { grep . || true; }; }

# _bl_files -> backlog files in this checkout, then in other worktrees whose id
# this checkout doesn't have: notes written on a branch count before it merges.
_bl_files() {
  local wt f id seen=" "
  while IFS= read -r wt; do
    for f in "$wt"/docs/backlog/*.md; do
      [ -f "$f" ] || continue
      id="$(yay_fm_get "$f" id 2>/dev/null || true)"; [ -n "$id" ] || continue
      case "$seen" in *" $id "*) continue ;; esac
      seen="$seen$id "
      printf '%s\n' "$f"
    done
  done <<EOF
$(yay_worktree_roots)
EOF
}

# _bl_related <ID> -> ids whose notes apply to <ID>: itself; for a plan, its roadmap
# item, source and design; for a roadmap item, brainstorm or design, the plans made from it.
_bl_related() {
  local id="$1" root f v
  root="$(yay_repo_root)"
  printf '%s\n' "$id"
  case "$id" in
    P-[0-9]*)
      f="$(yay_artifact_resolve "$id" 2>/dev/null)" || return 0
      for v in roadmap from design; do yay_fm_get "$root/$f" "$v" 2>/dev/null | grep -E '^[A-Z]+-[0-9]+$' || true; done ;;
    *)
      for f in "$root"/docs/plans/*.md; do
        [ -f "$f" ] || continue
        if [ "$(yay_fm_get "$f" roadmap 2>/dev/null)" = "$id" ] || [ "$(yay_fm_get "$f" from 2>/dev/null)" = "$id" ] || [ "$(yay_fm_get "$f" design 2>/dev/null)" = "$id" ]; then
          yay_fm_get "$f" id 2>/dev/null || true
        fi
      done ;;
  esac
}

# yay_backlog_open [--for=<ID>] [--kind=decision|deferred]
#   -> TSV of open notes: id kind from affects default title path
yay_backlog_open() {
  local a for="" kind="" rel="" root f k ids x hit
  for a in "$@"; do
    case "$a" in
      --for=*) for="${a#--for=}" ;; --kind=*) kind="${a#--kind=}" ;;
      *) yay_die "usage: yayh backlog open [--for=<ID>] [--kind=decision|deferred]" ;;
    esac
  done
  case "$kind" in ""|decision|deferred) ;; *) yay_die "kind must be decision or deferred" ;; esac
  root="$(yay_repo_root)"
  [ -z "$for" ] || rel="$(_bl_related "$for")"
  _bl_files | while IFS= read -r f; do
    k="$(yay_fm_get "$f" kind 2>/dev/null || echo idea)"
    case "$k" in decision|deferred) ;; *) continue ;; esac
    [ -z "$kind" ] || [ "$k" = "$kind" ] || continue
    [ "$(yay_fm_get "$f" status 2>/dev/null)" = open ] || continue
    ids="$( { yay_fm_get "$f" from 2>/dev/null || true; echo; _bl_list "$(yay_fm_get "$f" affects 2>/dev/null || true)"; } | { grep . || true; })"
    if [ -n "$for" ]; then
      hit=""
      ids=" $(printf '%s' "$ids" | tr '\n' ' ') "
      while IFS= read -r x; do case "$ids" in *" $x "*) [ -n "$x" ] && hit=1 ;; esac; done <<EOF
$rel
EOF
      [ -n "$hit" ] || continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(yay_fm_get "$f" id)" "$k" \
      "$(yay_fm_get "$f" from 2>/dev/null | grep . || echo -)" \
      "$(_bl_list "$(yay_fm_get "$f" affects 2>/dev/null || true)" | paste -sd, - | grep . || echo -)" \
      "$(yay_fm_get "$f" default 2>/dev/null | grep . || echo -)" \
      "$(yay_fm_get "$f" title 2>/dev/null || true)" "$(_bl_rel "$f")"
  done | sort -t- -k2,2n
}

# _bl_rel <abs file> -> path relative to its own checkout.
_bl_rel() { printf '%s\n' "docs/backlog/${1##*/docs/backlog/}"; }

# yay_backlog_settle <BL-n> decided "<answer>" | planned <P-n> | done "<commit or PR>" | dropped "<why>"
yay_backlog_settle() {
  local id="${1:-}" how="${2:-}" arg="${3:-}" root rel f k
  printf '%s' "$id" | grep -Eq '^BL-[0-9]+$' || yay_die "usage: yayh backlog settle <BL-n> decided \"<answer>\" | planned <P-n> | done \"<commit or PR>\" | dropped \"<why>\""
  root="$(yay_repo_root)"
  rel="$(yay_artifact_resolve "$id" 2>/dev/null)" || {
    f="$(_bl_files | while IFS= read -r x; do [ "$(yay_fm_get "$x" id)" = "$id" ] && { echo "$x"; break; }; done)"
    [ -n "$f" ] && yay_die "$id lives in another worktree ($f); settle it on that branch, or after it merges"
    yay_die "no backlog note $id"
  }
  f="$root/$rel"
  k="$(yay_fm_get "$f" kind 2>/dev/null || echo idea)"
  [ -n "$arg" ] || yay_die "settle $how needs a value"
  case "$arg" in *$'\n'*) yay_die "keep it to one line";; esac
  case "$how" in
    decided)
      [ "$k" = decision ] || yay_die "$id is not a decision note (kind: $k); use planned, done or dropped"
      yay_fm_set "$f" status decided; yay_fm_set "$f" decision "$arg" ;;
    planned)
      printf '%s' "$arg" | grep -Eq '^P-[0-9]+$' || yay_die "planned needs the plan id that takes it: planned P-6"
      yay_fm_set "$f" status "planned:$arg" ;;
    done)       # the work landed without a plan (a /yay:fix, a tiny change): name the commit or PR
      [ "$k" != decision ] || yay_die "$id is a decision note; use decided"
      yay_fm_set "$f" status done; yay_fm_set "$f" decision "$arg" ;;
    dropped) yay_fm_set "$f" status dropped; yay_fm_set "$f" decision "$arg" ;;
    *) yay_die "settle how: decided, planned, done or dropped" ;;
  esac
  yay_fm_set "$f" settled "$(yay_today)"
  printf '%s\t%s\t%s\n' "$id" "$(yay_fm_get "$f" status)" "$rel"
}
