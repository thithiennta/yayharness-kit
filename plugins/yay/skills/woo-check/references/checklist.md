# WooCommerce check: one ID per rule

Every finding `/yay:woo-check` reports, every row of `findings.tsv`, every baseline row and every fix commit (`fix(security): SEC1 escape admin notice output`) uses the IDs below. They cover what WooCommerce's QIT runs before a Marketplace release that can run on this machine without a WooCommerce.com account: security, PHPStan, PHP compatibility, malware and validation. The site checks (activation with Woo flows, core checkout and REST, REST fuzzing, version matrix) come in a later step.

**Checked by** says where the result comes from:
- `phpcs:<sniff>`: PHPCS with the generated ruleset, run on the unpacked zip
- `phpstan`: PHPStan with the WordPress and WooCommerce stubs
- `audit`: `composer audit` / `npm audit` on the repo's lock files
- `gitleaks`: gitleaks on the unpacked zip
- `woocheck:<check>`: `scripts/woocheck.py`, which prints the ID on each row

**Severity** is the row's result: `FAIL` counts towards Failed, `WARN` towards Warning. An area is **Failed** with any FAIL row, **Warning** with any WARN row, **Success** otherwise; `BASE` rows (in the baseline) and `SKIP` rows don't count. Only a Failed **SEC** or **MAL** stops `/yay:release --woo-check`.

**Library code** is `vendor/`, `node_modules/` and every folder in the repo's `generatedPaths` (such as `vendor-prefixed/`): PHPCS and PHPStan don't report on it, and MAL1 there is a WARN.

**Allowed in place:** `phpcs:ignore <sniff>` for PHPCS, `gitleaks:allow` for gitleaks, and `woo-check:allow <ID>` (on the line or the one above) for `woocheck.py`. Each one is visible to a reviewer next to the code, which is why SEC5 and MAL2 can be allowed this way but never baselined.

## Index

| ID | Rule | Checked by | Severity | Never baselined |
|---|---|---|---|---|
| SEC1 | Output is escaped, input is sanitized and nonce-checked (`WordPress.Security.*`) | `phpcs:WordPress.Security` | ERROR → FAIL, WARNING → WARN | |
| SEC2 | Database calls are prepared and cached where WPCS asks (`WordPress.DB.*`) | `phpcs:WordPress.DB` | ERROR → FAIL, WARNING → WARN | |
| SEC3 | No Composer dependency that ships with a known vulnerability | `audit` (`composer audit --no-dev`) | high/critical → FAIL, others WARN | |
| SEC4 | No npm dependency that ships with a known vulnerability | `audit` (`npm audit --omit=dev`, or `pnpm audit --prod` with a `pnpm-lock.yaml`) | high/critical → FAIL, others WARN | |
| SEC5 | No secret (API key, token, private key) in the zip | `gitleaks` (default rules; sha1/sha256 digests are allowed, `tools/gitleaks.toml`) | FAIL | yes |
| STAN1 | PHPStan finds no error at the configured level (`wooCheck.phpstanLevel`, default 2) | `phpstan` | FAIL | |
| CMP1 | The code runs on every PHP from `Requires PHP` up | `phpcs:PHPCompatibilityWP` | ERROR → FAIL, WARNING → WARN | |
| MAL1 | No dangerous function: `eval`, `assert` on a string, `create_function`, `system`, `exec`, `shell_exec`, `passthru`, `proc_open`, `popen`, backticks | `woocheck:dangerous_function` | FAIL in own code, WARN in `vendor/` and `node_modules/` | |
| MAL2 | No obfuscated code: `eval`/`assert` of a decoded string, `base64_decode`/`gzinflate`/`gzuncompress`/`str_rot13` chains, `preg_replace` with `/e`, base64 strings of 200+ characters in PHP | `woocheck:obfuscation` | FAIL | yes |
| MAL3 | No hidden file or folder, and no PHP under another extension (`.jpg`, `.png`, `.txt`, `.ico`…) | `woocheck:hidden_file`, `disguised_php` | WARN | |
| MAL4 | No non-printable characters in PHP source (zero-width, bidi overrides, control bytes) | `woocheck:non_printable` | WARN | |
| VAL1 | The main file has `WC requires at least` and `WC tested up to` | `woocheck:wc_headers` | FAIL | |
| VAL2 | Those headers agree with `requires.wc` and `tested.wc` in `.yay/config.json` | `woocheck:wc_headers_config` | WARN | |
| VAL3 | HPOS compatibility is declared (`FeaturesUtil::declare_compatibility( 'custom_order_tables', … )` in `before_woocommerce_init`) | `woocheck:declare_hpos` | missing → FAIL, declared `false` → WARN | |
| VAL4 | Block checkout compatibility is declared (`cart_checkout_blocks`) | `woocheck:declare_blocks` | WARN (missing or `false`) | |
| VAL5 | `WC tested up to` isn't older than the newest WooCommerce release | `woocheck:wc_tested_latest` | WARN; SKIP offline | |

## Fixes and when a finding is fine

- **SEC1.** Escape late with the right function for the context (`esc_html`, `esc_attr`, `esc_url`, `wp_kses_post` for trusted HTML), sanitize early (`sanitize_text_field( wp_unslash( $_POST['x'] ) )`), and check a nonce plus `current_user_can()` in every handler that changes data.
  - ✅ When this is fine: the plugin's own escaping wrapper (`yay_esc_*`) that PHPCS doesn't know. Allow it with `phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped by yay_esc_html()`, or baseline it.
- **SEC2.** `$wpdb->prepare()` with placeholders for every value; `%i` for identifiers on WP 6.2+.
  - ✅ When this is fine: a query built from constants only, or one prepared in a helper PHPCS can't follow. Say which in the `phpcs:ignore` comment.
- **SEC3 / SEC4.** Update to the patched version (`composer update <pkg>`, `npm update <pkg>`). With no patched version, the fix is a question for the developer: replace the package or accept the risk.
  - ✅ When this is fine: the vulnerable code path isn't reachable from the plugin. Say so in the PR; it stays in the report until the dependency moves.
- **SEC5.** Remove the secret from the zip, rotate it, and load it from an option or constant. A test key that is public by design gets `gitleaks:allow`.
- **STAN1.** Fix the type or the call. A false positive from WordPress dynamics (hooks, globals) gets a `@phpstan-ignore` with the reason, or the baseline.
- **CMP1.** Rewrite the construct for the minimum PHP, or raise `Requires PHP` (and `requires.php`) if that's the decision.
- **MAL1.** Remove it, or move the call behind a capability check and a fixed command. CLI-only code (`WP_CLI` commands) may need `exec`: allow it with `woo-check:allow MAL1` and a reason.
- **MAL2.** Remove it. If a library ships it, replace the library. Data that really is base64 (an embedded font, an icon) goes in its own asset file, or gets `woo-check:allow MAL2` with what it is.
- **MAL3.** Remove hidden files from the build (`.distignore`, the package script). Rename a PHP file with another extension, or remove it.
- **MAL4.** Retype the line; non-printable characters in code are almost always a paste accident or an attack.
- **VAL1.** Add both headers to the main file's header block.
- **VAL2.** Make the header and the config agree; `/yay:release` updates `tested.wc` and the header together.
- **VAL3 / VAL4.** Test the plugin with HPOS on (WooCommerce → Settings → Advanced → Features) and with the Checkout block, then declare it. Declaring compatibility is a question for the developer, never a fix the skill makes on its own.
- **VAL5.** Test with the newest WooCommerce and bump `WC tested up to`.
