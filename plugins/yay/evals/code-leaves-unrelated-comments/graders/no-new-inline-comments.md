---
type: regex
pattern: '^\s*(//|#)'
flags: m
match: "count:1"
target: { source: file, path: includes/Notices.php }
weight: 2
---
