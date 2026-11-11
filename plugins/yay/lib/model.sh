# shellcheck shell=bash
# Model and effort routing per step. See reference/models.md.

YAY_MODEL_STEPS="scout web-research feasibility revise resolve review hypothesis portfolio-research cowork prepare implement synthesis task"
YAY_MODEL_ORDER="veryfast fast balanced deep"   # a size bump moves along this order
YAY_MODEL_SIZED="prepare implement review task" # steps that act on a sized roadmap item
YAY_MODEL_MODELS="sonnet opus"
YAY_MODEL_EFFORTS="low medium high xhigh max"
YAY_MODEL_FALLBACK="balanced"                   # Opus medium: whatever can't be determined runs here

_yay_model_warn() { printf 'yayh: %s; using %s\n' "$*" "$YAY_MODEL_FALLBACK" >&2; }

_yay_model_words() { printf '%s\n' $1; }

# Top-level keys of a compact JSON object (nested objects are skipped).
_yay_model_keys() {
  local v="$1"
  v="${v#\{}"; v="${v%\}}"
  printf '%s' "$v" | sed 's/{[^{}]*}/0/g' | grep -oE '"[^"]+":' | tr -d '":'
}

# Built-in tier per step (reference/models.md). task stays inline unless a plan tags it.
_yay_model_default_step() {
  case "$1" in
    scout|web-research|feasibility) echo veryfast ;;
    revise|resolve) echo fast ;;
    synthesis) echo deep ;;
    task) echo inherit ;;
    *) echo "$YAY_MODEL_FALLBACK" ;;
  esac
}

# The step's tier: a tier name, "inherit", or "custom" (inline {model, effort}).
_yay_model_step_tier() {
  if yay_config_get "models.steps.$1.model" >/dev/null 2>&1 || yay_config_get "models.steps.$1.effort" >/dev/null 2>&1; then
    echo custom; return
  fi
  yay_config_get "models.steps.$1" "$(_yay_model_default_step "$1")"
}

_yay_model_tier_known() {
  yay_in_list "$1" "$(_yay_model_words "$YAY_MODEL_ORDER")" && return 0
  yay_config_get "models.tiers.$1.model" >/dev/null 2>&1 || yay_config_get "models.tiers.$1.effort" >/dev/null 2>&1
}

# _yay_model_bump <tier> <size> -> the tier moved by models.sizeBump.<size>, clamped.
_yay_model_bump() {
  local tier="$1" size="$2" by i=0 idx=-1 t n
  [ -n "$size" ] || { echo "$tier"; return; }
  yay_in_list "$tier" "$(_yay_model_words "$YAY_MODEL_ORDER")" || { echo "$tier"; return; }
  by="$(yay_config_get "models.sizeBump.$size" 0)"
  case "$by" in ''|*[!0-9-]*) by=0 ;; esac
  for t in $YAY_MODEL_ORDER; do [ "$t" = "$tier" ] && idx=$i; i=$((i+1)); done
  n=$i; idx=$((idx + by))
  [ "$idx" -ge 0 ] || idx=0
  [ "$idx" -lt "$n" ] || idx=$((n-1))
  i=0; for t in $YAY_MODEL_ORDER; do [ "$i" -eq "$idx" ] && { echo "$t"; return; }; i=$((i+1)); done
}

# Prints "<model>\t<effort>" for a tier ("custom" reads the step's inline object).
# A field the tier leaves out comes from the fallback tier.
_yay_model_fields() {
  local tier="$1" step="$2" base m e
  if [ "$tier" = custom ]; then base="models.steps.$step"; else base="models.tiers.$tier"; fi
  m="$(yay_config_get "$base.model" 2>/dev/null || yay_config_get "models.tiers.$YAY_MODEL_FALLBACK.model")"
  e="$(yay_config_get "$base.effort" 2>/dev/null || yay_config_get "models.tiers.$YAY_MODEL_FALLBACK.effort")"
  printf '%s\t%s\n' "$m" "$e"
}

_yay_model_json() { # <model> <effort> -> {"model":…,"effort":…} with only the set fields
  local out=""
  [ -z "$1" ] || out="\"model\":\"$1\""
  [ -z "$2" ] || out="$out${out:+,}\"effort\":\"$2\""
  printf '{%s}\n' "$out"
}

# The roadmap size (S|M|L) of a plan's roadmap item, or nothing.
_yay_model_plan_size() {
  local rel r
  rel="$(yay_artifact_resolve "$1" 2>/dev/null)" || return 0
  r="$(yay_fm_get "$(yay_repo_root)/$rel" roadmap 2>/dev/null)" || return 0
  case "$r" in R-[0-9]*) (yay_roadmap_get "$r" size 2>/dev/null) || true ;; esac
}

# The [tier: <name>] tag of one plan task, or nothing.
_yay_model_task_tag() {
  yay_plan_tasks "$1" 2>/dev/null | awk -F'\t' -v t="$2" '$1 == t { print $3 }' \
    | sed -nE 's/.*\[tier:[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*\].*/\1/p' | sed -n 1p
}

# yay_model_resolve <step> [--size=S|M|L] [--tier=<tier>] [--plan=<P-n>] [--task=<T-n>]
# -> {"model":"opus","effort":"medium"}, or {} when the step inherits the session's model
# (only when set to inherit, or task by default).
yay_model_resolve() {
  local step="" size="" tag="" plan="" task="" a tier fields
  for a in "$@"; do
    case "$a" in
      --size=*) size="${a#--size=}" ;;
      --tier=*) tag="${a#--tier=}" ;;
      --plan=*) plan="${a#--plan=}" ;;
      --task=*) task="${a#--task=}" ;;
      -*) yay_die "unknown option $a" ;;
      *) [ -z "$step" ] || yay_die "usage: yayh model resolve <step> [--size=S|M|L] [--tier=<tier>] [--plan=P-n] [--task=Tn]"; step="$a" ;;
    esac
  done
  [ -n "$step" ] || yay_die "usage: yayh model resolve <step> [--size=S|M|L] [--tier=<tier>] [--plan=P-n] [--task=Tn]"
  # Anything that can't be determined runs on the fallback tier (Opus medium), with a warning.
  if ! yay_in_list "$step" "$(_yay_model_words "$YAY_MODEL_STEPS")"; then
    _yay_model_warn "unknown step '$step'"
    fields="$(_yay_model_fields "$YAY_MODEL_FALLBACK" -)"; _yay_model_json "${fields%%	*}" "${fields#*	}"; return 0
  fi
  [ -n "$size" ] || [ -z "$plan" ] || size="$(_yay_model_plan_size "$plan")"
  case "$size" in ''|S|M|L) ;; *) printf "yayh: size '%s' isn't S, M or L; no size bump\n" "$size" >&2; size="" ;; esac
  if [ -z "$tag" ] && [ -n "$plan" ] && [ -n "$task" ]; then tag="$(_yay_model_task_tag "$plan" "$task")"; fi
  if [ -n "$tag" ]; then
    # A task tag is the plan author's deliberate choice: no size bump.
    tier="$tag"
    _yay_model_tier_known "$tier" || { _yay_model_warn "unknown tier '$tag'"; tier="$YAY_MODEL_FALLBACK"; }
  else
    tier="$(_yay_model_step_tier "$step")"
    [ "$tier" = inherit ] && { echo '{}'; return 0; }
    [ "$tier" = custom ] || _yay_model_tier_known "$tier" || { _yay_model_warn "models.steps.$step names unknown tier '$tier'"; tier="$YAY_MODEL_FALLBACK"; }
    if yay_in_list "$step" "$(_yay_model_words "$YAY_MODEL_SIZED")"; then tier="$(_yay_model_bump "$tier" "$size")"; fi
  fi
  fields="$(_yay_model_fields "$tier" "$step")"
  _yay_model_json "${fields%%	*}" "${fields#*	}"
}

# yay_model_table [--json] -> step, tier, model, effort (TSV), or the routing
# table a workflow script needs to resolve steps itself (see reference/models.md).
yay_model_table() {
  local json="" s t f m e steps="" tiers="" by=""
  [ "${1:-}" != --json ] || json=1
  if [ -z "$json" ]; then
    for s in $YAY_MODEL_STEPS; do
      t="$(_yay_model_step_tier "$s")"
      case "$t" in inherit|custom) ;; *) _yay_model_tier_known "$t" || t="$YAY_MODEL_FALLBACK" ;; esac
      if [ "$t" = inherit ]; then printf '%s\tinherit\t-\t-\n' "$s"; continue; fi
      f="$(_yay_model_fields "$t" "$s")"; m="${f%%	*}"; e="${f#*	}"
      printf '%s\t%s\t%s\t%s\n' "$s" "$t" "${m:--}" "${e:--}"
    done
    return 0
  fi
  for s in $YAY_MODEL_STEPS; do
    t="$(_yay_model_step_tier "$s")"
    case "$t" in inherit|custom) ;; *) _yay_model_tier_known "$t" || t="$YAY_MODEL_FALLBACK" ;; esac
    if [ "$t" = inherit ]; then steps="$steps${steps:+,}\"$s\":{\"tier\":\"inherit\"}"; continue; fi
    f="$(_yay_model_fields "$t" "$s")"; m="${f%%	*}"; e="${f#*	}"
    steps="$steps${steps:+,}\"$s\":{\"tier\":\"$t\"$([ -z "$m" ] || printf ',"model":"%s"' "$m")$([ -z "$e" ] || printf ',"effort":"%s"' "$e")}"
  done
  for t in $YAY_MODEL_ORDER; do
    f="$(_yay_model_fields "$t" -)"
    tiers="$tiers${tiers:+,}\"$t\":$(_yay_model_json "${f%%	*}" "${f#*	}")"
  done
  for s in S M L; do by="$by${by:+,}\"$s\":$(yay_config_get "models.sizeBump.$s" 0)"; done
  printf '{"steps":{%s},"tiers":{%s},"fallback":"%s","order":[%s],"sized":[%s],"sizeBump":{%s}}\n' \
    "$steps" "$tiers" "$YAY_MODEL_FALLBACK" \
    "$(printf '"%s",' $YAY_MODEL_ORDER | sed 's/,$//')" \
    "$(printf '"%s",' $YAY_MODEL_SIZED | sed 's/,$//')" "$by"
}

# yay_model_validate -> "models: …" lines on stderr; exit 1 on any.
yay_model_validate() {
  local errs=0 v k f m e t file
  for file in "$(yay_config_file)" "$(yay_config_local_file)"; do
    v="$(yay_json_get "$file" models.steps 2>/dev/null)" || continue
    for k in $(_yay_model_keys "$v"); do
      yay_in_list "$k" "$(_yay_model_words "$YAY_MODEL_STEPS")" || { echo "models: unknown step '$k' in $(basename "$file") (one of: $YAY_MODEL_STEPS)" >&2; errs=$((errs+1)); }
    done
  done
  _check() { # <where> <model> <effort>
    [ -z "$2" ] || yay_in_list "$2" "$(_yay_model_words "$YAY_MODEL_MODELS")" || { echo "models: $1 has model '$2' (one of: $YAY_MODEL_MODELS)" >&2; errs=$((errs+1)); }
    [ -z "$3" ] || yay_in_list "$3" "$(_yay_model_words "$YAY_MODEL_EFFORTS")" || { echo "models: $1 has effort '$3' (one of: $YAY_MODEL_EFFORTS)" >&2; errs=$((errs+1)); }
  }
  local tiers="$YAY_MODEL_ORDER"
  for file in "$(yay_config_file)" "$(yay_config_local_file)"; do
    v="$(yay_json_get "$file" models.tiers 2>/dev/null)" || continue
    for k in $(_yay_model_keys "$v"); do yay_in_list "$k" "$(_yay_model_words "$tiers")" || tiers="$tiers $k"; done
  done
  for t in $tiers; do
    f="$(_yay_model_fields "$t" -)"; _check "tier '$t'" "${f%%	*}" "${f#*	}"
  done
  for k in $YAY_MODEL_STEPS; do
    t="$(_yay_model_step_tier "$k")"
    case "$t" in
      inherit) ;;
      custom) f="$(_yay_model_fields custom "$k")"; _check "step '$k'" "${f%%	*}" "${f#*	}" ;;
      *) _yay_model_tier_known "$t" || { echo "models: step '$k' names unknown tier '$t'" >&2; errs=$((errs+1)); } ;;
    esac
  done
  for k in S M L; do
    v="$(yay_config_get "models.sizeBump.$k" 0)"
    printf '%s' "$v" | grep -Eq '^-?[0-9]+$' || { echo "models: sizeBump.$k must be a whole number (got '$v')" >&2; errs=$((errs+1)); }
  done
  [ "$errs" -eq 0 ]
}
