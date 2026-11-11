---
type: regex
pattern: '\t\t\t// Slugs and labels default to empty and hold merchant overrides only: the fallbacks\n\t\t\t// live in MyAccountEndpoints, so the default label stays translatable instead of\n\t\t\t// being frozen into the saved option.\n\t\t\t.my_account.'
target: { source: file, path: includes/Settings.php }
weight: 2
---
