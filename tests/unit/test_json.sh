# per-engine
# The JSON helpers with one backend per engine (get, pretty, merge, set). Every
# other file runs on the first engine only, so this file and the config and
# manifest readers are what prove each backend.

_json_lib() {
  YAY_LIB_DIR="$KIT/lib"; YAY_KIT_ROOT="$KIT"
  . "$KIT/lib/common.sh"; . "$KIT/lib/harness.sh"; . "$KIT/lib/release.sh"
}

_json_fixture() {
  cat > "$1" <<'EOF'
{"a": {"b": "x y", "n": 3, "t": true, "f": false, "z": null},
 "list": ["one", "two"], "objs": [{"k": "v"}], "url": "https://e.x/a/b"}
EOF
}

test_get_scalars_arrays_objects_and_missing() {
  _json_lib; _json_fixture j.json
  assert_eq "x y" "$(yay_json_get j.json a.b)"
  assert_eq "3" "$(yay_json_get j.json a.n)"
  assert_eq "true" "$(yay_json_get j.json a.t)"
  assert_eq "false" "$(yay_json_get j.json a.f)"
  assert_eq "one
two" "$(yay_json_get j.json list)"
  assert_eq '{"k":"v"}' "$(yay_json_get j.json objs)"
  assert_eq "https://e.x/a/b" "$(yay_json_get j.json url)"
  assert_exit 3 yay_json_get j.json a.z
  assert_exit 3 yay_json_get j.json a.nope
  assert_exit 3 yay_json_get missing.json a.b
  printf 'not json' > bad.json
  assert_exit 3 yay_json_get bad.json a
}

test_pretty_keeps_values_and_breaks_lines() {
  _json_lib
  printf '{"a":{"b":[1,2]},"s":"https://e.x/p"}' | yay_json_pretty > p.json
  assert_eq "1
2" "$(yay_json_get p.json a.b)"
  assert_eq "https://e.x/p" "$(yay_json_get p.json s)"
  [ "$(wc -l < p.json)" -gt 1 ] && _pass || _fail "pretty output is one line: $(cat p.json)"
}

test_merge_objects_deep_arrays_union_scalars_right_wins() {
  _json_lib
  printf '%s' '{"o":{"keep":"l","both":"l"},"arr":["a","b"],"s":"l","only":"l"}' > l.json
  printf '%s' '{"o":{"both":"r","new":"r"},"arr":["b","c"],"s":"r"}' > r.json
  yay_json_merge l.json r.json > m.json
  assert_eq "l" "$(yay_json_get m.json o.keep)"
  assert_eq "r" "$(yay_json_get m.json o.both)"
  assert_eq "r" "$(yay_json_get m.json o.new)"
  assert_eq "a
b
c" "$(yay_json_get m.json arr)"
  assert_eq "r" "$(yay_json_get m.json s)"
  assert_eq "l" "$(yay_json_get m.json only)"
}

test_set_creates_paths_and_keeps_the_rest() {
  _json_lib; _json_fixture j.json
  yay_json_set j.json tested.wp "6.7"
  yay_json_set j.json a.b "changed"
  assert_eq "6.7" "$(yay_json_get j.json tested.wp)"
  assert_eq "changed" "$(yay_json_get j.json a.b)"
  assert_eq "3" "$(yay_json_get j.json a.n)"
  assert_eq "one
two" "$(yay_json_get j.json list)"
}
