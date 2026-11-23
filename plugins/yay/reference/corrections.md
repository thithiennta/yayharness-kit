# yay corrections: turn a repeated correction into a check

Read by `/yay:knowledge-update` (step 3b) when a `correction` or `review` lesson repeats. A line in `CLAUDE.md` or `conventions.md` is read sometimes and followed sometimes. A check fails every time, and its message tells the agent the fix. So go down this ladder and stop at the first rung that can express the correction.

## The ladder
1. **Make it impossible.** The wrong move only exists because two ways are available: a public helper and a raw call, an old class and its replacement. Remove or hide the wrong one (make it private, delete the old path). That's a code change, so it's a deferred note with the exact change.
2. **A lint rule** in the repo's existing config. The message names the right move.
3. **A test** at the cheapest layer that proves it (`${CLAUDE_PLUGIN_ROOT}/reference/testing.md`).
4. **A command check:** something a grep or a WP-CLI call proves. Add it to a `## Checks` section in `docs/knowledge/conventions.md` (create it when missing) as ``- `<command>` → <expected>``, so plans can copy it into Verify.
5. **Prose**, only for what none of the above can express (judgement, wording, product taste): the project block's hard rules or `conventions.md`, as a verifiable fact with its evidence.

Rungs 1–3 change product code or config, so `/yay:knowledge-update` doesn't make them. It writes a deferred note with the exact rule or test, ready to ship through a normal PR: `yayh artifact new backlog "Check: <the correction>" kind=deferred` with the snippet in its body. Rungs 4–5 it writes itself.

## Recipes

**A function that has a helper** (`get_option( 'x_settings' )` instead of `Settings::get()`, `wc_price()` re-implemented), in `phpcs.xml` / `.phpcs.xml.dist`:
```xml
<rule ref="Generic.PHP.ForbiddenFunctions">
  <properties>
    <property name="forbiddenFunctions" type="array">
      <element key="date" value="wp_date"/>
    </property>
  </properties>
</rule>
```
PHPCS can only point at a replacement function. For a function that's fine elsewhere (`get_option` with one option name), use a test or a command check instead.

**A JS import or pattern**, in the ESLint config:
```json
"no-restricted-imports": ["error", { "paths": [{ "name": "lodash", "message": "Use @wordpress/compose or plain JS." }] }],
"no-restricted-syntax": ["error", { "selector": "CallExpression[callee.name='useEffect']", "message": "Derive the value instead; see conventions.md." }]
```

**Behaviour** (a price rounded the wrong way, a hook registered twice): a unit or integration test tagged with the lesson's `from:` id, as in `/yay:test`.

**A grep** (a raw option read in product code, a missing text domain):
``- `! grep -rn "get_option( 'x_settings'" includes/ --include=*.php` → exit 0``

## Rules
- The message is for the agent: say what to do instead, not only what's wrong.
- Scope it to product code (exclude `tests/`, `vendor/`, build output).
- Existing violations: the deferred note lists them (`file:line`). The rule ships with them fixed, or with the rule limited to new code, never as a wall of new lint errors.
