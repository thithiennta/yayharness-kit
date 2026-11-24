---
type: llm
---
The reply identifies the root cause in `includes/GiftMessage.php`: `clean()` compares with `>=` and truncates to `MAX - 1`, so a message of exactly 200 characters is cut to 199. It cites the file and line and doesn't apply a fix.
