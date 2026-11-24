---
type: regex
pattern: '\]\(\.\./assets/(P-1|R-2)/[^)]+\.png\)'
target: trace
---
The plan links the kept screenshot (`](../assets/P-1/…png)`, or its item's `R-2` folder). It reads the trace, since the agent picks the plan's file name.
