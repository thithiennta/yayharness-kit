---
type: regex
pattern: 'Seen in screenshot[\s\S]*\]\(\.\./assets/P-1/[^)]+\.png\)|\]\(\.\./assets/P-1/[^)]+\.png\)[\s\S]*Seen in screenshot'
target: { source: file, path: docs/plans/gift-message-preview.md }
---
