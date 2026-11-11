---
type: regex
pattern: '= 1\.(2\.1|3\.0)'
match: not_contains
target: { source: file, path: readme.txt }
weight: 2
---
