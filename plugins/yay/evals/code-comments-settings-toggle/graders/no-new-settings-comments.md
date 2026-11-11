---
type: regex
pattern: '^\s*(//|#)'
flags: m
match: "count:3"
target: { source: file, path: includes/Settings.php }
weight: 2
---
