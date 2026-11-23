---
type: regex
pattern: 'stateDiagram-v2(?=[\s\S]*-->\s*[A-Za-z_]*[Rr]efund)(?=[\s\S]*-->\s*[A-Za-z_]*([Rr]eject|[Dd]eclin))(?=[\s\S]*-->\s*\[\*\])'
target: { source: file, path: docs/designs/gift-returns.md }
---
