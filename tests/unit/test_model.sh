# model routing (lib/model.sh), per JSON engine

_mrepo() { # a repo whose config routes some steps
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay"
  cat > "$r/.yay/config.json" <<'EOF'
{
  "schemaVersion": 1,
  "models": {
    "steps": {
      "scout": "veryfast", "revise": "fast", "review": "balanced", "prepare": "balanced",
      "synthesis": "deep", "cowork": { "model": "sonnet", "effort": "high" }
    }
  }
}
EOF
  printf '%s\n' "$r"
}

_r() { "$YAYH" model resolve "$@"; }

test_built_in_step_defaults() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r scout)"
  assert_eq '{"model":"opus","effort":"low"}' "$(_r resolve)"
  assert_eq '{"model":"opus","effort":"medium"}' "$(_r review)"
  assert_eq '{"model":"opus","effort":"high"}' "$(_r implement --size=L)"
  assert_eq '{"model":"opus","effort":"high"}' "$(_r synthesis)"
  assert_eq "{}" "$(_r task)"                                           # inline unless tagged
  mkdir -p "$YAY_REPO/.yay"; printf '{"models":{"steps":{"review":"inherit"}}}\n' > "$YAY_REPO/.yay/local.json"
  assert_eq "{}" "$(_r review)"                                         # explicit inherit is honoured
}

test_undetermined_falls_back_to_opus_medium() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  local om='{"model":"opus","effort":"medium"}'
  assert_eq "$om" "$(_r mystery 2>/dev/null)"
  assert_contains "$(_r mystery 2>&1 >/dev/null)" "unknown step 'mystery'; using balanced"
  assert_eq "$om" "$(_r task --tier=turbo 2>/dev/null)"
  assert_eq "$om" "$(_r review --size=XL 2>/dev/null)"                 # bad size: no bump
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p))
c["models"]["steps"]["hypothesis"]="nope"
c["models"]["steps"]["revise"]={"effort":"low"}
c["models"]["tiers"]={"half":{"model":"sonnet"}}
json.dump(c,open(p,"w"))
PY
  assert_eq "$om" "$(_r hypothesis 2>/dev/null)"                       # unknown tier in config
  assert_eq '{"model":"opus","effort":"low"}' "$(_r revise)"            # inline without a model
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r task --tier=half)"  # tier without an effort
  assert_contains "$("$YAYH" model table)" "hypothesis	balanced	opus	medium"
  assert_contains "$("$YAYH" model table --json)" '"fallback":"balanced"'
}

test_tier_lookup_and_inline_object() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r scout)"
  assert_eq '{"model":"opus","effort":"low"}' "$(_r revise)"
  assert_eq '{"model":"opus","effort":"medium"}' "$(_r review)"
  assert_eq '{"model":"opus","effort":"high"}' "$(_r synthesis)"
  assert_eq '{"model":"sonnet","effort":"high"}' "$(_r cowork)"
}

test_size_bump_only_for_sized_steps_and_clamped() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  assert_eq '{"model":"opus","effort":"high"}' "$(_r prepare --size=L)"
  assert_eq '{"model":"opus","effort":"medium"}' "$(_r prepare --size=M)"
  assert_eq '{"model":"opus","effort":"low"}' "$(_r review --size=S)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r scout --size=L)"   # not a sized step
  assert_eq '{"model":"opus","effort":"high"}' "$(_r synthesis --size=S)"   # not a sized step
  assert_eq '{"model":"sonnet","effort":"high"}' "$(_r cowork --size=L)"    # inline: never bumped
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["models"]["sizeBump"]={"S":-5,"L":5}
json.dump(c,open(p,"w"))
PY
  assert_eq '{"model":"opus","effort":"high"}' "$(_r prepare --size=L)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r prepare --size=S)"
}

test_tier_tag_wins_and_is_not_bumped() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r task --tier=veryfast)"
  assert_eq '{"model":"opus","effort":"high"}' "$(_r task --tier=deep --size=S)"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r review --tier=veryfast --size=L)"
}

test_custom_tiers_and_partial_overrides() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p))
c["models"]["tiers"]={"cheap":{"model":"sonnet","effort":"low"},"fast":{"effort":"medium"}}
c["models"]["steps"]["resolve"]="cheap"
json.dump(c,open(p,"w"))
PY
  assert_eq '{"model":"sonnet","effort":"low"}' "$(_r resolve)"
  assert_eq '{"model":"opus","effort":"medium"}' "$(_r revise)"   # fast keeps its built-in model
  assert_eq '{"model":"sonnet","effort":"low"}' "$(_r task --tier=cheap)"
}

test_local_json_wins() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  printf '{"models":{"steps":{"review":"veryfast"}}}\n' > "$YAY_REPO/.yay/local.json"
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r review)"
  assert_eq '{"model":"opus","effort":"low"}' "$(_r revise)"      # the rest still from config.json
}

test_usage_errors_fail() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  assert_fails _r
  assert_fails _r review --bogus
  assert_fails _r review scout
}

test_table_tsv_and_json() {
  export YAY_REPO; YAY_REPO="$(_mrepo)"
  local t; t="$("$YAYH" model table)"
  assert_contains "$t" "scout	veryfast	sonnet	medium"
  assert_contains "$t" "task	inherit	-	-"
  assert_contains "$t" "hypothesis	balanced	opus	medium"                # unset: built-in default
  assert_contains "$t" "cowork	custom	sonnet	high"
  local j; j="$("$YAYH" model table --json)"
  assert_contains "$j" '"review":{"tier":"balanced","model":"opus","effort":"medium"}'
  assert_contains "$j" '"task":{"tier":"inherit"}'
  assert_contains "$j" '"deep":{"model":"opus","effort":"high"}'
  assert_contains "$j" '"order":["veryfast","fast","balanced","deep"]'
  assert_contains "$j" '"sizeBump":{"S":-1,"M":0,"L":1}'
  printf '%s' "$j" | python3 -I -c 'import json,sys; json.load(sys.stdin)' && _pass || _fail "table --json is not valid JSON"
}

test_plan_and_task_lookup() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["models"]={"steps":{"review":"balanced"}}
json.dump(c,open(p,"w"))
PY
  mkdir -p "$YAY_REPO/docs"
  cat > "$YAY_REPO/docs/roadmap.md" <<'EOF'
---
horizon: 2026-12-07
sprint_length: 2w
updated: 2026-11-01
---
# Roadmap: Fixture

## Sprint 1 (2026-11-10 → 2026-11-23)

### R-1 Big thing
- status: planned
- size: L
EOF
  local p; p="$("$YAYH" artifact new plan "Routed plan" roadmap=R-1)"
  python3 -I - "$YAY_REPO/$p" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("- [ ] T1 <what> — `path/to/file.php`", "- [ ] T1 Rename the option — `includes/Plugin.php` [tier: veryfast]\n- [ ] T2 Rework the totals — `includes/Cart.php`")
open(p,'w').write(s)
PY
  assert_eq '{"model":"opus","effort":"high"}' "$(_r review --plan=P-1)"            # R-1 is L
  assert_eq '{"model":"opus","effort":"medium"}' "$(_r review --plan=P-1 --size=M)" # explicit size wins
  assert_eq '{"model":"sonnet","effort":"medium"}' "$(_r task --plan=P-1 --task=T1)"
  assert_eq '{}' "$(_r task --plan=P-1 --task=T2)"                                  # untagged: inline
}

test_plan_check_warns_on_unknown_tier_tag() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  local p; p="$("$YAYH" artifact new plan "Tagged plan")"
  python3 -I - "$YAY_REPO/$p" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("- [ ] T1 <what> — `path/to/file.php`", "- [ ] T1 Rename — `a.php` [tier: veryfast]\n- [ ] T2 Rework — `b.php` [tier: turbo]")
open(p,'w').write(s)
PY
  local out; out="$("$YAYH" plan check P-1 2>&1 || true)"
  assert_contains "$out" "warn: task T2 has unknown tier 'turbo'; it will run as balanced"
  case "$out" in *"task T1 has unknown tier"*) _fail "T1's tier is valid" ;; *) _pass ;; esac
}

test_config_validate_checks_models() {
  export YAY_REPO; YAY_REPO="$(fixture_repo bare merged)"
  assert_ok "$YAYH" config validate
  python3 -I - "$YAY_REPO/.yay/config.json" <<'PY'
import json,sys
p=sys.argv[1]; c=json.load(open(p))
c["models"]={"tiers":{"fast":{"model":"haiku","effort":"turbo"}},"steps":{"reviewer":"fast","scout":"nope"},"sizeBump":{"L":"big"}}
json.dump(c,open(p,"w"))
PY
  local out; out="$("$YAYH" config validate 2>&1 || true)"
  assert_fails "$YAYH" config validate
  assert_contains "$out" "unknown step 'reviewer'"
  assert_contains "$out" "tier 'fast' has model 'haiku'"
  assert_contains "$out" "tier 'fast' has effort 'turbo'"
  assert_contains "$out" "step 'scout' names unknown tier 'nope'"
  assert_contains "$out" "sizeBump.L must be a whole number"
}
