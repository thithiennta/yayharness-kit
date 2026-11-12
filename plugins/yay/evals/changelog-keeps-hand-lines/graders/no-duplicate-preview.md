---
type: regex
pattern: '= 1\.3\.0[^\n]*\n[^=]*(preview|gift card)[^=]*(preview|gift card)'
flags: i
match: not_contains
target: { source: file, path: readme.txt }
---
