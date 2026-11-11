---
type: llm
weight: 3
---

The reply adds tests for GiftMessage::clean() at the unit layer (plain PHP, no WordPress or browser), covering trimming and the cap at the boundary (199, 200 and 201 characters). It notices that a message of exactly 200 characters is cut to 199 although the docblock says 200 is allowed, and reports it as a product bug (suggesting /yay:debug or a fix) instead of writing an assertion that expects 199. It doesn't edit product code.
