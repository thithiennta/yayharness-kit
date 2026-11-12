---
type: regex
pattern: '= 1\.3\.0[^\n]*\n[^=]*(200|character|last char)'
flags: i
target: { source: file, path: readme.txt }
weight: 2
---
