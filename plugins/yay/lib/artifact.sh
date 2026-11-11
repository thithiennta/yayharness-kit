# shellcheck shell=bash
# Workflow artifacts: brainstorms, plans, bugs, backlog. See reference/artifacts.md.

_art_prefix() {
  case "$1" in
    brainstorm) echo BS ;; plan) echo P ;; bug) echo B ;; backlog) echo BL ;;
    *) yay_die "unknown artifact type '$1' (brainstorm, plan, bug, backlog)" ;;
  esac
}

# Relative path for a new artifact of <type> with <slug>.
_art_path() {
  case "$1" in
    brainstorm) printf 'docs/brainstorms/%s-%s.md\n' "$(yay_today)" "$2" ;;
    plan)       printf 'docs/plans/%s.md\n' "$2" ;;
    bug)        printf 'docs/bugs/%s-%s.md\n' "$(yay_today)" "$2" ;;
    backlog)    printf 'docs/backlog/%s.md\n' "$2" ;;
  esac
}

# yay_render_vars <template-file> k=v... : substitute {{k}} first, then config keys.
yay_render_vars() {
  local tpl="$1"; shift
  local tmp kv k v; tmp="$(mktemp)"; cp "$tpl" "$tmp"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    awk -v k="{{$k}}" -v v="$v" 'BEGIN{gsub(/\\/,"\\\\",v)} { while ((i = index($0, k)) > 0) $0 = substr($0, 1, i-1) v substr($0, i+length(k)); print }' "$tmp" > "$tmp.n" && mv "$tmp.n" "$tmp"
  done
  yay_render "$tmp"; rm -f "$tmp"
}

# yay_artifact_new <type> "<title>" [key=value...] -> path of the new file.
# Known keys: from, roadmap, type (plan branch type), severity, editions;
# for backlog: kind (idea|decision|deferred), affects, default.
yay_artifact_new() {
  local type="$1" title="$2"; shift 2 || yay_die "usage: yayh artifact new <type> \"<title>\" [key=value...]"
  [ -n "$title" ] || yay_die "a title is required"
  case "$title" in -*) yay_die "title '$title' looks like an option; give the title first: yayh artifact new $type \"<title>\" [key=value...]";; esac
  case "$title" in *$'\n'*) yay_die "title must be one line";; esac
  local prefix id slug rel root from="" roadmap="" ptype="feat" severity="medium" editions kv
  local bl_kind=idea affects="" default=""
  prefix="$(_art_prefix "$type")"
  editions="$(yay_config_get editions 2>/dev/null | paste -sd, - | sed 's/,/, /g')"
  for kv in "$@"; do
    case "$kv" in
      from=*) from="${kv#from=}" ;; roadmap=*) roadmap="${kv#roadmap=}" ;;
      type=*) ptype="${kv#type=}" ;; severity=*) severity="${kv#severity=}" ;;
      editions=*) editions="${kv#editions=}" ;;
      kind=*) bl_kind="${kv#kind=}" ;; affects=*) affects="${kv#affects=}" ;; default=*) default="${kv#default=}" ;;
      *) yay_die "unknown key '${kv%%=*}' (from, roadmap, type, severity, editions, kind, affects, default)" ;;
    esac
  done
  case "$ptype" in feat|fix|chore|refactor|perf|docs|test) ;; *) yay_die "plan type must be feat, fix, chore, refactor, perf, docs or test";; esac
  case "$severity" in critical|high|medium|low) ;; *) yay_die "severity must be critical, high, medium or low";; esac
  case "$bl_kind" in idea|decision|deferred) ;; *) yay_die "backlog kind must be idea, decision or deferred";; esac
  case "$default$affects" in *$'\n'*) yay_die "default and affects must be one line";; esac
  case "$default" in *' #'*) yay_die "default can't contain ' #' (front-matter reads it as a comment)";; esac
  [ "$type" = backlog ] || [ "$bl_kind$affects$default" = idea ] || yay_die "kind, affects and default are for backlog notes only"
  [ "$bl_kind" != decision ] || [ -n "$default" ] || yay_die "a decision note needs default=\"<what the work does until it's decided>\""
  affects="$(_bl_list "$affects" | paste -sd, - | sed 's/,/, /g')"
  root="$(yay_repo_root)"
  slug="$(yay_slugify "$title")"
  [ -n "$slug" ] || yay_die "title gives an empty slug"
  rel="$(_art_path "$type" "$slug")"
  [ -e "$root/$rel" ] && yay_die "$rel already exists; pick a different title or open that file"
  mkdir -p "$(dirname "$root/$rel")"
  yay_id_lock
  trap yay_id_unlock EXIT
  id="$(yay_id_next "$prefix")"
  yay_render_vars "$YAY_TEMPLATES/artifacts/$type.md" \
    "id=$id" "title=$title" "slug=$slug" "from=$from" "roadmap=$roadmap" "ptype=$ptype" \
    "severity=$severity" "artifact_editions=$editions" "bl_kind=$bl_kind" \
    "bl_status=$([ "$bl_kind" = idea ] && echo idea || echo open)" "affects=$affects" "default=$default" > "$root/$rel"
  yay_id_unlock; trap - EXIT
  printf '%s\n' "$rel"
}

# yay_artifact_resolve <ID|path|slug> -> repo-relative path (exit 3 if none/ambiguous).
yay_artifact_resolve() {
  local q="$1" root hits n
  root="$(yay_repo_root)"
  if [ -f "$root/$q" ]; then printf '%s\n' "$q"; return 0; fi
  if [ -f "$q" ]; then printf '%s\n' "${q#"$root"/}"; return 0; fi
  if printf '%s' "$q" | grep -Eq '^(BS|BL|P|B|R)-[0-9]+$'; then
    hits="$(yay_id_find "$q" 2>/dev/null | sed "s|^$root/||")" || hits=""
  else
    hits="$(cd "$root" && find docs -type f -name "*$(yay_slugify "$q")*.md" 2>/dev/null)" || hits=""
  fi
  n="$(printf '%s' "$hits" | grep -c . || true)"
  if [ "$n" = 1 ]; then printf '%s\n' "$hits"; return 0; fi
  if [ "$n" -gt 1 ]; then printf 'yayh: "%s" matches several artifacts:\n%s\n' "$q" "$hits" >&2; return 3; fi
  return 3
}

# yay_artifact_list [type] [--status=s] -> TSV: id status title path
yay_artifact_list() {
  local type="" status="" a root dirs d f id st ti
  for a in "$@"; do case "$a" in --status=*) status="${a#--status=}";; *) type="$a";; esac; done
  root="$(yay_repo_root)"
  case "$type" in
    "") dirs="brainstorms plans bugs backlog" ;; brainstorm) dirs=brainstorms ;; plan) dirs=plans ;;
    bug) dirs=bugs ;; backlog) dirs=backlog ;; *) yay_die "unknown type $type" ;;
  esac
  for d in $dirs; do
    for f in "$root/docs/$d"/*.md; do
      [ -f "$f" ] || continue
      id="$(yay_fm_get "$f" id 2>/dev/null || true)"; [ -n "$id" ] || continue
      st="$(yay_fm_get "$f" status 2>/dev/null || true)"
      [ -z "$status" ] || [ "$st" = "$status" ] || continue
      ti="$(yay_fm_get "$f" title 2>/dev/null || true)"
      printf '%s\t%s\t%s\t%s\n' "$id" "$st" "$ti" "${f#"$root"/}"
    done
  done
}

# ---------- plans ----------

# yay_plan_tasks <plan> -> TSV: T<n> done|open text
yay_plan_tasks() {
  local f; f="$(yay_repo_root)/$(yay_artifact_resolve "$1")" || yay_die "no plan '$1'"
  awk '/^## /{intasks=($0 ~ /^## Tasks/)} intasks && match($0, /^- \[[ xX]\] T[0-9]+/) {
    done=(substr($0,4,1) != " "); rest=substr($0,7); split(rest, a, " "); t=a[1]; sub(/^T[0-9]+[[:space:]]*/, "", rest)
    printf "%s\t%s\t%s\n", t, (done?"done":"open"), rest }' "$f"
}

# yay_plan_tick <plan> <T<n>> [--undo]
yay_plan_tick() {
  local plan="$1" task="$2" undo="${3:-}" rel f tmp from to
  rel="$(yay_artifact_resolve "$plan")" || yay_die "no plan '$plan'"
  f="$(yay_repo_root)/$rel"
  printf '%s' "$task" | grep -Eq '^T[0-9]+$' || yay_die "task must look like T3"
  if [ "$undo" = --undo ]; then from='x'; to=' '; else from=' '; to='x'; fi
  grep -Eq "^- \[[ xX]\] $task([^0-9]|\$)" "$f" || yay_die "$rel has no task $task"
  tmp="$(mktemp)"
  awk -v t="$task" -v to="$to" '
    !d && $0 ~ ("^- \\[[ xX]\\] " t "([^0-9]|$)") { $0 = "- [" to "]" substr($0, 6); d=1 }
    { print }' "$f" > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
  printf '%s\t%s\n' "$task" "$([ "$to" = x ] && echo done || echo open)"
}

# yay_plan_check <plan> -> "error: …" / "warn: …" lines; exit 1 on any error.
yay_plan_check() {
  local rel f root errs=0 st k n
  root="$(yay_repo_root)"
  rel="$(yay_artifact_resolve "$1")" || yay_die "no plan '$1'"
  f="$root/$rel"
  _pe() { echo "error: $*"; errs=$((errs+1)); }
  _pw() { echo "warn: $*"; }
  for k in id title status created; do yay_fm_get "$f" "$k" >/dev/null 2>&1 || _pe "front-matter is missing '$k'"; done
  st="$(yay_fm_get "$f" status 2>/dev/null || true)"
  case "$st" in draft|ready|in-progress|done|dropped) ;; *) _pe "status '$st' is not draft|ready|in-progress|done|dropped";; esac
  grep -q '^## Goal' "$f" || _pe "no '## Goal' section"
  grep -q '^## Tasks' "$f" || _pe "no '## Tasks' section"
  local tasks; tasks="$(yay_plan_tasks "$rel")"
  n="$(printf '%s' "$tasks" | grep -c . || true)"
  [ "$n" -gt 0 ] || _pe "no tasks: write them as '- [ ] T1 …' under ## Tasks"
  local i=1 t
  while IFS="$(printf '\t')" read -r t _ _; do
    [ -n "$t" ] || continue
    [ "$t" = "T$i" ] || _pw "task $t is out of order (expected T$i)"
    i=$((i+1))
  done <<EOF
$tasks
EOF
  # Every task names files (backticked) unless it says (no files).
  awk '/^## /{intasks=($0 ~ /^## Tasks/)} intasks && /^- \[[ xX]\] T[0-9]+/ { if ($0 !~ /`/ && $0 !~ /\(no files\)/) { match($0, /T[0-9]+/); print substr($0, RSTART, RLENGTH) } }' "$f" \
    | while read -r t; do [ -n "$t" ] && echo "warn: task $t names no files (backtick the paths, or write '(no files)')"; done
  # Every task says what existing code it reuses (or why it adds new code).
  awk '
    function done_task() { if (t != "") { if (!reuse) print t "\tmissing"; else if (none && !why) print t "\tnowhy" } }
    /^## / { if (intasks) done_task(); intasks = ($0 ~ /^## Tasks/); t = ""; next }
    intasks && /^- \[[ xX]\] T[0-9]+/ { done_task(); match($0, /T[0-9]+/); t = substr($0, RSTART, RLENGTH); reuse = 0; none = 0; why = 0; next }
    intasks && t != "" && /^[[:space:]]+[-*]?[[:space:]]*Reuse:/ { reuse = 1; if ($0 ~ /Reuse:[[:space:]]*none/) { none = 1; why = ($0 ~ /because/) } }
    END { if (intasks) done_task() }' "$f" \
    | while IFS="$(printf '\t')" read -r t why; do
        case "$why" in
          missing) echo "warn: task $t has no 'Reuse:' line (the existing code it calls, 'none, new X() because …', or 'n/a')" ;;
          nowhy) echo "warn: task $t adds new code ('Reuse: none') without saying why the existing code doesn't fit ('because …')" ;;
        esac
      done
  # Notes left for this plan (lib/backlog.sh): settle them or keep their default on purpose.
  case "$st" in draft|ready|in-progress)
    yay_backlog_open --for="$(yay_fm_get "$f" id 2>/dev/null || echo -)" 2>/dev/null | while IFS="$(printf '\t')" read -r k kind _ _ def ti _; do
      case "$kind" in
        decision) echo "warn: open decision $k ($ti) affects this plan; it follows the default \"$def\" until settled (yayh backlog settle $k decided …)" ;;
        deferred) echo "warn: deferred work $k ($ti) affects this plan: take it as a task (yayh backlog settle $k planned <P-n>) or leave it for later" ;;
      esac
    done ;;
  esac
  grep -Eq '^\*\*Tests:\*\*[[:space:]]*[^[:space:]]' "$f" || _pe "no '**Tests:** <tests or none>' line"
  # Each test names the layer it runs at (reference/testing.md): [unit], [integration], [js] or [manual].
  sed -nE 's/^\*\*Tests:\*\*[[:space:]]*//p' "$f" | sed -n 1p | tr ';' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | while IFS= read -r t; do
        case "$t" in ''|none|none:*|'none '*|'['unit']'*|'['integration']'*|'['js']'*|'['manual']'*) ;;
          *) echo "warn: test '$(printf '%s' "$t" | cut -c1-50)' has no layer: start it with [unit], [integration], [js] or [manual] (reference/testing.md)" ;;
        esac
      done
  # Repos with e2e set up decide per plan which flows get a browser spec.
  if yay_config_get commands.e2e >/dev/null 2>&1 && ! grep -Eq '^\*\*E2E:\*\*[[:space:]]*[^[:space:]]' "$f"; then
    _pw "no '**E2E:** <browser-only flows, or none>' line (this repo has e2e set up)"
  fi
  if ! awk '/^## Verify/{on=1; next} /^## /{on=0} on && /[^[:space:]]/ && !/^<!--/ && !/^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]*$/{found=1} END{exit !found}' "$f"; then
    _pe "'## Verify' is missing or empty: write exact manual checks"
  fi
  [ "$errs" -eq 0 ]
}

# ---------- carrying artifacts into a worktree ----------

# yay_artifact_carry <worktree> <path>... : move untracked artifact files from
# the main checkout into the same path in the worktree.
yay_artifact_carry() {
  local wt="$1"; shift
  local root p
  root="$(yay_repo_root)"
  [ -d "$wt" ] || yay_die "no worktree at $wt"
  for p in "$@"; do
    p="${p#"$root"/}"
    [ -f "$root/$p" ] || yay_die "no such file: $p"
    if git -C "$root" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      if git -C "$root" diff --quiet -- "$p"; then printf 'tracked\t%s\n' "$p"; continue; fi
      yay_die "$p is tracked and modified in the main checkout; commit it on its own branch or move the change by hand"
    fi
    if [ -e "$wt/$p" ] && ! cmp -s "$root/$p" "$wt/$p"; then yay_die "$wt/$p already exists and differs"; fi
    mkdir -p "$(dirname "$wt/$p")"
    cp "$root/$p" "$wt/$p" && rm -f "$root/$p"
    printf 'carried\t%s\n' "$p"
  done
}

# ---------- id conflicts with the base branch ----------

# yay_id_conflicts [base] -> TSV: conflict<TAB>ID<TAB>our-file<TAB>base-file ; exit 1 if any.
yay_id_conflicts() {
  local base="${1:-}" root ours f id theirs rc=0
  [ -n "$base" ] || base="$(yay_base_branch)"
  root="$(yay_repo_root)"
  ours="$( { git -C "$root" diff --name-only --diff-filter=A "$base"...HEAD -- docs/ 2>/dev/null; git -C "$root" ls-files --others --exclude-standard -- docs/; } | grep '\.md$' | sort -u || true)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(yay_fm_get "$root/$f" id 2>/dev/null || true)"; [ -n "$id" ] || continue
    theirs="$(git -C "$root" grep -l -E "^(id: |### )${id}( |\$)" "$base" -- docs/ 2>/dev/null | sed "s|^$base:||" | grep -vx "$f" | sed -n 1p || true)"
    if [ -n "$theirs" ]; then printf 'conflict\t%s\t%s\t%s\n' "$id" "$f" "$theirs"; rc=1; fi
  done <<EOF
$ours
EOF
  return $rc
}

# ---------- running configured commands ----------

# yay_run <command-name> [k=v...] : run commands.<name> from the repo root.
yay_run() {
  local name="$1"; shift
  local cmd root
  cmd="$(yay_config_get "commands.$name" 2>/dev/null)" || yay_die "no commands.$name in .yay/config.json (this step doesn't apply here)"
  cmd="$(yay_fill "$cmd" "slug=$(yay_config_get plugin.slug)" "$@")"
  case "$cmd" in *'{'*'}'*) yay_die "commands.$name still has a placeholder after filling: $cmd (pass k=v)";; esac
  # YAY_RUN_APPEND: already shell-quoted extra arguments (yayh e2e run passes Playwright's).
  [ -z "${YAY_RUN_APPEND:-}" ] || cmd="$cmd $YAY_RUN_APPEND"
  root="$(yay_repo_root)"
  # Honour .nvmrc / .node-version through nvm when the active Node differs.
  local pre="" want nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  want="$(cat "$root/.nvmrc" 2>/dev/null || cat "$root/.node-version" 2>/dev/null || true)"
  want="$(printf '%s' "$want" | tr -d 'v[:space:]')"
  if [ -n "$want" ] && [ -s "$nvm_sh" ]; then
    case "$(node -v 2>/dev/null | tr -d v)" in
      "$want"|"$want".*) ;;
      *) pre=". \"$nvm_sh\" >/dev/null 2>&1 && nvm use \"$want\" >/dev/null && " ;;
    esac
  fi
  printf 'yayh run %s: %s%s\n' "$name" "${pre:+(nvm use $want) }" "$cmd" >&2
  (cd "$root" && bash -c "$pre$cmd")
}

# ---------- debug instrumentation ----------

# yay_debug_markers -> path:line:text for every yay:debug comment marker in
# tracked and untracked (non-ignored) non-markdown files.
yay_debug_markers() {
  local root; root="$(yay_repo_root)"
  ( cd "$root" && { git ls-files; git ls-files --others --exclude-standard; } \
      | grep -vE '\.(md|mdx)$' \
      | while IFS= read -r f; do [ -f "$f" ] && printf '%s\0' "$f"; done \
      | xargs -0 grep -nE '(//|#|/\*|<!--)[[:space:]]*yay:debug' 2>/dev/null ) || true
}
