---
type: llm
weight: 2
---

The repeated correction (reading get_option( 'giftly_settings' ) instead of Support\Settings::get()) is turned into a check, not only a sentence: a command check such as a grep for get_option( 'giftly_settings' ) outside includes/Support/Settings.php in a Checks section of docs/knowledge/conventions.md, and/or a deferred backlog note with an exact lint rule or test. A sentence in conventions.md alongside the check is fine; a sentence alone fails. The one-off env lesson is not promoted.
