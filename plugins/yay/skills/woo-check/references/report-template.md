# Report template: the WooCommerce check

`report.md` is the full technical record of one run on one edition's zip. The plain summary for the lead (`/yay:report check`) is written from it, so keep it complete and exact; it doesn't need to be friendly.

Rules:
- **Areas in a fixed order:** SEC, MAL, STAN, CMP, VAL. The two that block the release come first.
- **Every finding:** ID, `file:line` in the source the author edits (traced back from the zip path: a built asset maps to its source, Pro paths keep their source path), what's wrong in one line, the fix. For SEC, give the code fix itself (the `$wpdb->prepare()` call, the escaped echo).
- **Group repeats.** More than 8 findings with the same ID and code: show 8, then "… and N more" and the full list in the appendix.
- **Only non-baseline findings** go under the areas. Baseline rows are counted, not listed, except rows that went away.
- **Call an area Success only when it ran.** A SKIP area says so under Not checked.
- Read every FAIL before writing it. Drop a finding you checked and found false, and say how many you dropped under Not checked.

---

```markdown
# <Plugin Name> <version>: WooCommerce check (<edition>)

**Verdict:** <Failed: blocks release (SEC, MAL) | Failed: doesn't block release | Warning | Success>
Checked: `<zip name>` (built with the repo's package command | as given with --zip) · tools: PHPCS <v>, PHPStan <v> level <n>, gitleaks <v> · <date>

| Area | Status | New FAIL | New WARN | Baseline | Not checked |
|---|---|---|---|---|---|
| SEC | <status> | <n> | <n> | <n> | <ids or –> |
| MAL | … |
| STAN | … |
| CMP | … |
| VAL | … |

## SEC: security

### SEC2 `WordPress.DB.PreparedSQL.InterpolatedNotPrepared` (2)
- `includes/class-rates.php:88`: `$_GET['id']` concatenated into `$wpdb->query()`.
  Fix: `$wpdb->query( $wpdb->prepare( "DELETE FROM {$table} WHERE id = %d", absint( $_GET['id'] ) ) );`
- …

## MAL: malware
…

## STAN: PHPStan (level <n>)
…

## CMP: PHP compatibility (<min>+)
…

## VAL: WooCommerce declarations
…

## Not checked
- <ID>: <why: tool missing, no package-lock.json, offline…>
- <n> findings dropped after reading the line: <one line each, or "none">

## Baseline
<n> rows in `.yay/woo-check-baseline.tsv`: SEC <n>, MAL <n>, STAN <n>, CMP <n>, VAL <n>.
Gone since the baseline (fixed, or the code moved): <rows, or "none">. Run `/yay:woo-check --update-baseline` to drop them.
<No baseline yet: this run counts every finding. Commit one with `/yay:woo-check --update-baseline`.>

## Appendix
<the full lists that were cut to 8 above>
```
