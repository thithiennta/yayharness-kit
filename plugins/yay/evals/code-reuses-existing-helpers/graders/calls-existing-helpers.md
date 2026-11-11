---
type: regex
pattern: '(Format::price\s*\(|Report::fee_html\s*\()'
target: { source: file, path: includes/Checkout.php }
weight: 2
---
