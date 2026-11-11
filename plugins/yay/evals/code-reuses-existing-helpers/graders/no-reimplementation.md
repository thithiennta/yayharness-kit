---
type: regex
pattern: '(number_format|wc_price|get_option|function\s+\w*(format|price)\w*\s*\()'
match: not_contains
target: { source: file, path: includes/Checkout.php }
weight: 2
---
