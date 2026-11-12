# designs: artifact new design, resolve/list, design check, plan design: field, notes reach the plan

_drepo() { local d; d="$(fixture_repo bare merged)" || return 1; printf '%s\n' "$d"; }

_fill() { # design file: a complete, simple design
  awk '
    /^## Job$/ { print; print "Store admins turn express buttons on without leaving checkout settings."; next }
    /^## Where it lives$/ { print; print "WooCommerce > Settings > Payments, a new Express buttons section."; next }
    /^## Flow$/ { print; print "1. Open the section and tick Enable."; skip = 1; next }
    /^## Screens$/ { print; print "### Settings section"; print "```"; print "[x] Enable express buttons"; print "[ Save changes ]"; print "```"; print "- Enable: WC settings checkbox, default off."; next }
    /^## States$/ { print; print "- Empty: n/a, the section always shows."; print "- Saving: the WC save spinner."; print "- Success: WC settings saved notice."; print "- Error: WC error notice with the reason."; skip = 1; next }
    /^## Copy$/ { print; print "- Enable express buttons"; next }
    /^## Accessibility$/ { print; print "- The checkbox has a label."; next }
    /^## Acceptance$/ { print; print "- Tick Enable, save: the buttons show on checkout."; skip = 1; next }
    /^## / { skip = 0 }
    skip && /^([-*]|[0-9]+\.)/ { next }
    { print }' "$1" > "$1.n" && mv "$1.n" "$1"
}

test_new_design_has_id_path_and_frontmatter() {
  export YAY_REPO; YAY_REPO="$(_drepo)"
  local d; d="$("$YAYH" artifact new design "Express checkout buttons" from=BS-3)"
  assert_eq "docs/designs/express-checkout-buttons.md" "$d"
  assert_eq "UX-1" "$("$YAYH" fm get "$YAY_REPO/$d" id)"
  assert_eq "draft" "$("$YAYH" fm get "$YAY_REPO/$d" status)"
  assert_eq "BS-3" "$("$YAYH" fm get "$YAY_REPO/$d" from)"
  assert_fails grep -q '{{' "$YAY_REPO/$d"
  assert_eq "$d" "$("$YAYH" artifact resolve UX-1)"
  assert_eq "UX-1" "$("$YAYH" artifact list design | cut -f1)"
  assert_eq "UX-2" "$("$YAYH" id next UX)"
}

test_check_fails_on_the_empty_template() {
  export YAY_REPO; YAY_REPO="$(_drepo)"
  "$YAYH" artifact new design "Express checkout buttons" >/dev/null
  local out; out="$("$YAYH" design check UX-1 2>&1)"; local rc=$?
  assert_eq 1 "$rc"
  assert_contains "$out" "error: '## Job' is empty"
  assert_contains "$out" "error: '## States' is empty"
  assert_contains "$out" "error: '## Acceptance' is empty"
}

test_check_passes_a_filled_design_and_warns_on_gaps() {
  export YAY_REPO; YAY_REPO="$(_drepo)"
  local d; d="$YAY_REPO/$("$YAYH" artifact new design "Express checkout buttons")"
  _fill "$d"
  local out; out="$("$YAYH" design check UX-1 2>&1)"
  assert_ok "$YAYH" design check UX-1
  assert_eq "" "$out"
  # no wireframe, no error state
  sed -i.bak '/^```$/d; /Error:/d' "$d"; rm -f "$d.bak"
  out="$("$YAYH" design check UX-1 2>&1)"
  assert_contains "$out" "warn: '## Screens' has no wireframe"
  assert_contains "$out" "warn: '## States' says nothing about errors"
  "$YAYH" fm set "$d" status shipped
  assert_fails "$YAYH" design check UX-1
}

test_plan_has_design_field_and_design_notes_reach_it() {
  export YAY_REPO; YAY_REPO="$(_drepo)"
  local p; p="$YAY_REPO/$("$YAYH" artifact new plan "Express checkout" roadmap=R-3)"
  assert_eq "" "$("$YAYH" fm get "$p" design)"
  "$YAYH" artifact new design "Express checkout buttons" >/dev/null
  "$YAYH" fm set "$p" design UX-1
  "$YAYH" artifact new backlog "Button order" kind=decision from=UX-1 default="Apple Pay first" >/dev/null
  assert_eq "BL-1" "$("$YAYH" backlog open --for=P-1 | cut -f1)"
  assert_eq "BL-1" "$("$YAYH" backlog open --for=UX-1 | cut -f1)"
}
