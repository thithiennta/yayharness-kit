# config reader, per JSON engine

_cfg_repo() {
  local r; r="$(mk_repo)"
  mkdir -p "$r/.yay"
  cat > "$r/.yay/config.json" <<'EOF'
{
  "schemaVersion": 1,
  "plugin": { "name": "Fixture", "slug": "fixture-plugin", "mainFile": "fixture-plugin.php", "wporgSlug": null },
  "editions": ["free", "pro"],
  "git": { "baseBranch": "dev", "scopes": ["core", "admin"] },
  "commands": { "build": "./scripts/run.sh build", "package": "./scripts/run.sh release {version} --plan={edition}" },
  "versionFiles": [ { "file": "fixture-plugin.php", "pattern": "Version: *(.+)" } ],
  "flags": { "on": true, "off": false }
}
EOF
  printf '%s\n' "$r"
}

test_scalar_and_nested() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_eq "dev" "$("$YAYH" config get git.baseBranch)"
  assert_eq "fixture-plugin" "$("$YAYH" config get plugin.slug)"
}

test_array_one_per_line() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_eq "free
pro" "$("$YAYH" config get editions)"
}

test_array_of_objects_prints_json_lines() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_contains "$("$YAYH" config get versionFiles)" '"file":"fixture-plugin.php"'
}

test_booleans_false_is_a_value_not_missing() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_eq "true" "$("$YAYH" config get flags.on)"
  assert_eq "false" "$("$YAYH" config get flags.off)"
}

test_null_and_missing_fail_without_fallback() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_exit 1 "$YAYH" config get plugin.wporgSlug
  assert_exit 1 "$YAYH" config get commands.test
  assert_eq "fallback" "$("$YAYH" config get commands.test fallback)"
}

test_defaults_apply() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  assert_eq "v{version}" "$("$YAYH" config get git.tagFormat)"
  assert_contains "$("$YAYH" config get git.branchTypes)" "hotfix"
  assert_eq "readme.txt" "$("$YAYH" config get changelog.readme)"
}

test_fill_placeholders() {
  export YAY_REPO; YAY_REPO="$(_cfg_repo)"
  local t; t="$("$YAYH" config get commands.package)"
  assert_eq "./scripts/run.sh release 1.4.0 --plan=pro" "$("$YAYH" config fill "$t" version=1.4.0 edition=pro)"
  assert_eq "a/b&c-1.0" "$("$YAYH" config fill "{x}-{version}" "x=a/b&c" version=1.0)"
}

test_no_config_file() {
  export YAY_REPO; YAY_REPO="$(mk_repo)"
  assert_exit 1 "$YAYH" config get git.baseBranch
}
